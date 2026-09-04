// lib/services/notification_service.dart
//
// Thin wrapper around `flutter_local_notifications` + `workmanager`
// for Aakaash's two banner channels:
//
//   • Aakaash Daily Weather — zonedSchedule(), fires at the user's
//     chosen local time every day.
//
//   • Aakaash Calamity Alert — periodic background worker (every 6h)
//     that fetches the latest USGS/GDACS data around the user's
//     last-known location and posts a notification for each active
//     event within the configured radius.
//
// All scheduling is gated behind an active BDApps subscription. The
// provider handles enable/disable; this service is purely the engine.

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:workmanager/workmanager.dart';

import '../models/calamity_model.dart';
import 'notification_worker.dart';

/// Channel IDs — stable strings used both as channel id and Android
/// notification channel grouping key.
class NotificationChannels {
  static const String dailyWeather = 'aakaash_daily_weather';
  static const String calamity = 'aakaash_calamity';
  static const String earthquake = 'aakaash_earthquake';
}

/// Notification IDs (int). `flutter_local_notifications` requires ints.
class NotificationIds {
  static const int dailyWeatherBase = 1001; // single daily slot
  static const int calamityBase = 2000;
  // Hard cap so we don't run out of IDs for repeat events.
  static const int calamityMax = calamityBase + 500;
  static const int earthquakeBase = 3000;
  static const int earthquakeMax = earthquakeBase + 500;
}

/// WorkManager task name for periodic calamity checks.
const String kCalamityTaskName = 'com.aakaash.aakaash.calamity_check';

/// WorkManager task name for the country-wide earthquake sentinel.
/// Runs at workmanager's minimum 15-min cadence so we can wake up
/// fast when a new quake is detected.
const String kEarthquakeTaskName = 'com.aakaash.aakaash.earthquake_check';

/// Where a tap on a notification should route the user.
enum NotificationRoute { home, calamity, earthquake }

/// DTO handed to the tap handler — the main shell routes by `.route`.
class NotificationRoutePayload {
  final NotificationRoute route;
  final String? calamityId;
  const NotificationRoutePayload({
    required this.route,
    this.calamityId,
  });
}

/// Engine-only service. State lives in [NotificationProvider]; this
/// class just talks to the OS.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  void Function(NotificationRoutePayload payload)? _tapHandler;

  /// Called from the app shell after the navigator key is mounted.
  void setTapHandler(void Function(NotificationRoutePayload) h) {
    _tapHandler = h;
  }

  // ────────────────────────── lifecycle ──────────────────────────

  /// Idempotent. Sets up timezone DB, channels, and the OS tap
  /// callback. Must be awaited before runApp so the first frame can
  /// query notification permission.
  Future<void> initialize() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    // Android's DateTime.now().timeZoneName returns OS short-names like
    // "BDT" or "+06" that the `timezone` package cannot look up — this
    // silently falls through to UTC, shifting the daily alarm by the
    // full UTC offset (6 h for Bangladesh). Instead we try the IANA
    // name first, then fall back to "Asia/Dhaka" (this is a BD-only
    // app), and only use UTC as a last resort.
    try {
      tz.setLocalLocation(tz.getLocation(DateTime.now().timeZoneName));
    } catch (_) {
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }
    }

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onTap,
    );
    _initialized = true;
  }

  void _onTap(NotificationResponse resp) {
    final h = _tapHandler;
    if (h == null) return;
    final payload = resp.payload ?? '';
    if (payload.startsWith('earthquake:')) {
      h(NotificationRoutePayload(
        route: NotificationRoute.earthquake,
        calamityId: payload.substring('earthquake:'.length),
      ));
    } else if (payload.startsWith('calamity:')) {
      h(NotificationRoutePayload(
        route: NotificationRoute.calamity,
        calamityId: payload.substring('calamity:'.length),
      ));
    } else {
      // Default — daily summary or test — drop the user at home.
      h(const NotificationRoutePayload(route: NotificationRoute.home));
    }
  }

  // ──────────────────────── permission ───────────────────────────

  /// Currently granted at the OS level. Used by the settings UI's
  /// "blocked" hint.
  Future<bool> areNotificationsEnabled() async {
    if (!Platform.isAndroid) return true;
    return await Permission.notification.isGranted;
  }

  /// Ask the OS for runtime permission (Android 13+ POST_NOTIFICATIONS).
  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.notification.request();
    return status.isGranted || status.isLimited;
  }

  // ──────────────────────── daily weather ────────────────────────

  Future<void> cancelDailyWeather() async {
    await _plugin.cancel(NotificationIds.dailyWeatherBase);
  }

  /// Returns the pending daily alarm, or null if none is registered.
  Future<PendingNotificationRequest?> pendingDailyAlarm() async {
    final all = await _plugin.pendingNotificationRequests();
    try {
      return all.firstWhere(
          (r) => r.id == NotificationIds.dailyWeatherBase);
    } catch (_) {
      return null;
    }
  }


  /// Returns true if the app can schedule exact alarms.
  /// On Android < 12 always true. On 12+ requires the user to grant
  /// Alarms & reminders in system settings.
  Future<bool> canScheduleExactAlarms() async {
    if (!Platform.isAndroid) return true;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    return await android?.canScheduleExactNotifications() ?? true;
  }

  /// Opens the system Alarms & reminders settings page so the user
  /// can grant SCHEDULE_EXACT_ALARM. No-op on iOS or Android < 12.
  Future<void> requestExactAlarmPermission() async {
    if (!Platform.isAndroid) return;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestExactAlarmsPermission();
  }

  /// Schedule a daily weather notification at the local time encoded
  /// by [time]. Repeats every day via `matchDateTimeComponents: time`.
  ///
  /// Uses [exactAllowWhileIdle] when SCHEDULE_EXACT_ALARM is granted;
  /// silently falls back to [inexactAllowWhileIdle] otherwise so the
  /// notification still arrives (potentially a few minutes late).
  Future<void> scheduleDailyWeather({
    required TimeOfDay time,
    required String title,
    required String body,
    required String payload,
  }) async {
    await initialize();
    // On Android 12+, exact scheduling requires a runtime-granted
    // permission. Fall back to inexact if not yet granted so the
    // alarm is still registered (and we can prompt later).
    final useExact = await canScheduleExactAlarms();
    final scheduleMode = useExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    await _plugin.zonedSchedule(
      NotificationIds.dailyWeatherBase,
      title,
      body,
      _nextInstanceOf(time.hour, time.minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationChannels.dailyWeather,
          'Daily weather forecast',
          channelDescription:
              'A daily summary of the weather forecast at your current location.',
          importance: Importance.high,
          priority: Priority.high,
          ticker: 'Aakaash daily forecast',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
  }

  /// Immediate one-shot test notification on the daily channel. Posts
  /// even when scheduling is gated off — used by the "Test now" UI.
  Future<void> showDailyTest(String title, String body) async {
    await initialize();
    await _plugin.show(
      NotificationIds.dailyWeatherBase,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationChannels.dailyWeather,
          'Daily weather forecast',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: 'home',
    );
  }

  // ────────────────────────── calamity ───────────────────────────

  /// Post a single calamity alert. The notification id is derived from
  /// the event id so re-showing the same event replaces (not stacks)
  /// the previous banner.
  Future<void> showCalamity(Calamity c) async {
    await initialize();
    final id = NotificationIds.calamityBase +
        (c.id.hashCode & 0x7fffffff) %
            (NotificationIds.calamityMax - NotificationIds.calamityBase);
    await _plugin.show(
      id,
      '${c.type.label} · ${c.severity.label}',
      _summarise(c),
      NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationChannels.calamity,
          'Natural calamity alerts',
          channelDescription:
              'Active natural calamities near your current location.',
          importance: _importanceFor(c.severity),
          priority: _priorityFor(c.severity),
          color: c.severity.color,
          ticker: '${c.type.label} alert',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: 'calamity:${c.id}',
    );
  }

  // ───────────────────────── earthquake ─────────────────────────
  //
  // Instant alerts for new M3.5+ earthquakes anywhere inside
  // Bangladesh or near its border (Myanmar / India / Bay of Bengal).
  // The dedicated channel plays the system default notification
  // sound at full volume and vibrates, so a new quake is impossible
  // to miss.

  /// Post a single instant earthquake alert. Sound is on by channel
  /// default; vibration pattern is short-sharp so it feels urgent.
  Future<void> showEarthquake(Calamity c) async {
    await initialize();
    final id = NotificationIds.earthquakeBase +
        (c.id.hashCode & 0x7fffffff) %
            (NotificationIds.earthquakeMax -
                NotificationIds.earthquakeBase);
    await _plugin.show(
      id,
      'Earthquake · ${c.locationName}',
      _summariseEarthquake(c),
      NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationChannels.earthquake,
          'Earthquake alerts',
          channelDescription:
              'Instant alerts when an earthquake is detected anywhere '
              'in or near Bangladesh.',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 250, 200, 250]),
          ticker: 'Earthquake alert',
          category: AndroidNotificationCategory.alarm,
        ),
        iOS: DarwinNotificationDetails(
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      payload: 'earthquake:${c.id}',
    );
  }

  // ──────────────────────── background worker ────────────────────

  /// Start (or update) the periodic calamity background worker.
  /// WorkManager's minimum periodic interval is 15 min; 6h matches the
  /// cadence that makes sense for GDACS / USGS.
  Future<void> startCalamityWorker() async {
    try {
      await Workmanager().initialize(
        notificationCallbackDispatcher,
        isInDebugMode: kDebugMode,
      );
      await Workmanager().registerPeriodicTask(
        kCalamityTaskName,
        kCalamityTaskName,
        frequency: const Duration(hours: 6),
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: true,
        ),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 15),
      );
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('NotificationService.startCalamityWorker: $e');
      }
    }
  }

  Future<void> stopCalamityWorker() async {
    try {
      await Workmanager().cancelByUniqueName(kCalamityTaskName);
    } catch (_) {
      // ignore — WorkManager may not have been initialised yet.
    }
  }

  /// Country-wide instant earthquake sentinel. WorkManager's minimum
  /// periodic interval is 15 min so we wake up to within ~15 min of a
  /// new event (no other Android periodic cadence is supported).
  Future<void> startEarthquakeWorker() async {
    try {
      await Workmanager().initialize(
        notificationCallbackDispatcher,
        isInDebugMode: kDebugMode,
      );
      await Workmanager().registerPeriodicTask(
        kEarthquakeTaskName,
        kEarthquakeTaskName,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 5),
      );
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('NotificationService.startEarthquakeWorker: $e');
      }
    }
  }

  Future<void> stopEarthquakeWorker() async {
    try {
      await Workmanager().cancelByUniqueName(kEarthquakeTaskName);
    } catch (_) {
      // ignore — WorkManager may not have been initialised yet.
    }
  }

  // ─────────────────────────── helpers ───────────────────────────

  static tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static Importance _importanceFor(CalamitySeverity s) {
    switch (s) {
      case CalamitySeverity.info:
        return Importance.low;
      case CalamitySeverity.warning:
        return Importance.defaultImportance;
      case CalamitySeverity.danger:
        return Importance.high;
      case CalamitySeverity.extreme:
        return Importance.max;
    }
  }

  static Priority _priorityFor(CalamitySeverity s) {
    switch (s) {
      case CalamitySeverity.info:
        return Priority.low;
      case CalamitySeverity.warning:
        return Priority.defaultPriority;
      case CalamitySeverity.danger:
        return Priority.high;
      case CalamitySeverity.extreme:
        return Priority.max;
    }
  }

  static String _summarise(Calamity c) {
    final loc = c.locationName.isEmpty ? 'Bangladesh' : c.locationName;
    final risk = c.riskScore != null
        ? ' · Risk ${(c.riskScore! * 100).toStringAsFixed(0)}%'
        : '';
    final mag = c.magnitude != null
        ? ' · ${c.type == CalamityType.earthquake ? 'M${c.magnitude!.toStringAsFixed(1)}' : c.magnitude!.toStringAsFixed(0)}'
        : '';
    return '$loc$risk$mag · ${c.sourceName}';
  }

  static String _summariseEarthquake(Calamity c) {
    final mag = c.magnitude != null
        ? 'M${c.magnitude!.toStringAsFixed(1)} '
        : '';
    final loc = c.locationName.isEmpty ? 'Bangladesh' : c.locationName;
    return '$mag· $loc · tap for details';
  }
}