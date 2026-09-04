// lib/providers/notification_provider.dart
//
// Owns the user's notification preferences and bridges them with the
// active subscription status. Persisted in SharedPreferences so the
// background worker can read them without spinning up a Provider.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/calamity_model.dart';
import '../services/notification_service.dart';
import 'subscription_provider.dart';

class NotificationSettings {
  final bool dailyOn;
  final TimeOfDay dailyTime;
  final bool calamityOn;
  final double radiusKm;
  final bool earthquakeOn;

  const NotificationSettings({
    required this.dailyOn,
    required this.dailyTime,
    required this.calamityOn,
    required this.radiusKm,
    required this.earthquakeOn,
  });

  static const defaults = NotificationSettings(
    dailyOn: true,
    dailyTime: TimeOfDay(hour: 7, minute: 0),
    calamityOn: true,
    radiusKm: 300.0,
    earthquakeOn: true,
  );

  NotificationSettings copyWith({
    bool? dailyOn,
    TimeOfDay? dailyTime,
    bool? calamityOn,
    double? radiusKm,
    bool? earthquakeOn,
  }) =>
      NotificationSettings(
        dailyOn: dailyOn ?? this.dailyOn,
        dailyTime: dailyTime ?? this.dailyTime,
        calamityOn: calamityOn ?? this.calamityOn,
        radiusKm: radiusKm ?? this.radiusKm,
        earthquakeOn: earthquakeOn ?? this.earthquakeOn,
      );
}

class NotificationProvider extends ChangeNotifier {
  NotificationProvider();

  NotificationSettings _settings = NotificationSettings.defaults;
  NotificationSettings get settings => _settings;

  bool _permissionGranted = false;
  bool get permissionGranted => _permissionGranted;

  /// Most-recent background run timestamp (for the UI's "last checked"
  /// hint). Null until the worker has run at least once.
  DateTime? _lastRun;
  DateTime? get lastRun => _lastRun;

  // ─── Persistence keys (also read by notification_worker.dart) ───
  static const _kEnabled = 'notif_enabled'; // master "feature on" flag
  static const _kDailyOn = 'notif_daily_on';
  static const _kDailyHour = 'notif_daily_hour';
  static const _kDailyMin = 'notif_daily_min';
  static const _kCalamityOn = 'notif_calamity_on';
  static const _kRadius = 'notif_radius_km';
  static const _kSubStatus = 'notif_subscriber_status';
  static const _kLastRun = 'notif_last_run_ms';
  static const _kEarthquakeOn = 'notif_earthquake_on';

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _settings = NotificationSettings(
      dailyOn: p.getBool(_kDailyOn) ?? NotificationSettings.defaults.dailyOn,
      dailyTime: TimeOfDay(
        hour: p.getInt(_kDailyHour) ??
            NotificationSettings.defaults.dailyTime.hour,
        minute: p.getInt(_kDailyMin) ??
            NotificationSettings.defaults.dailyTime.minute,
      ),
      calamityOn:
          p.getBool(_kCalamityOn) ?? NotificationSettings.defaults.calamityOn,
      radiusKm:
          p.getDouble(_kRadius) ?? NotificationSettings.defaults.radiusKm,
      earthquakeOn:
          p.getBool(_kEarthquakeOn) ?? NotificationSettings.defaults.earthquakeOn,
    );
    final ms = p.getInt(_kLastRun);
    _lastRun = ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    await _refreshPermission();
    // Re-arm alarms/worker in case the user rebooted their device.
    // The OS may have dropped our scheduled tasks across boot.
    await _reconcileScheduling();
    notifyListeners();
  }

  Future<void> _refreshPermission() async {
    try {
      _permissionGranted =
          await NotificationService.instance.areNotificationsEnabled();
    } catch (_) {
      _permissionGranted = false;
    }
  }

  // ─── Public mutators ──────────────────────────────────────────

  Future<bool> requestPermission() async {
    final granted = await NotificationService.instance.requestPermission();
    _permissionGranted = granted;
    notifyListeners();
    return granted;
  }

  Future<void> setDaily(bool on) async {
    _settings = _settings.copyWith(dailyOn: on);
    await _persist();
    await _reconcileScheduling();
    notifyListeners();
  }

  Future<void> setDailyTime(TimeOfDay t) async {
    _settings = _settings.copyWith(dailyTime: t);
    await _persist();
    await _reconcileScheduling();
    notifyListeners();
  }

  Future<void> setCalamity(bool on) async {
    _settings = _settings.copyWith(calamityOn: on);
    await _persist();
    await _reconcileScheduling();
    notifyListeners();
  }

  Future<void> setRadius(double km) async {
    _settings = _settings.copyWith(radiusKm: km.clamp(50, 500).toDouble());
    await _persist();
    notifyListeners();
  }

  Future<void> setEarthquake(bool on) async {
    _settings = _settings.copyWith(earthquakeOn: on);
    await _persist();
    await _reconcileScheduling();
    notifyListeners();
  }

  /// Called from [SubscriptionProvider] when subscription state
  /// changes. When the user becomes REGISTERED we (re-)enable both
  /// notifications with default settings. When they unsubscribe we
  /// cancel everything but keep their preferences in prefs so a
  /// re-subscribe restores them.
  Future<void> syncWithSubscription(SubscriptionStatus status) async {
    final p = await SharedPreferences.getInstance();
    final isRegistered = status == SubscriptionStatus.registered;
    await p.setString(_kSubStatus, isRegistered ? 'registered' : 'other');
    if (isRegistered) {
      // Only flip on if the user hasn't explicitly disabled either
      // toggle previously. We detect "explicitly disabled" by the
      // presence of the dailyOn/calamityOn keys in prefs.
      final hadDaily = p.containsKey(_kDailyOn);
      final hadCalamity = p.containsKey(_kCalamityOn);
      if (!hadDaily) {
        _settings = _settings.copyWith(
          dailyOn: NotificationSettings.defaults.dailyOn,
        );
        await p.setBool(_kDailyOn, _settings.dailyOn);
      }
      if (!hadCalamity) {
        _settings = _settings.copyWith(
          calamityOn: NotificationSettings.defaults.calamityOn,
        );
        await p.setBool(_kCalamityOn, _settings.calamityOn);
      }
      await p.setBool(_kEnabled, true);
      await _reconcileScheduling();
    } else {
      await p.setBool(_kEnabled, false);
      await NotificationService.instance.cancelDailyWeather();
      await NotificationService.instance.stopCalamityWorker();
      await NotificationService.instance.stopEarthquakeWorker();
      // Refresh persisted subStatus so a background tick that fires
      // after unsubscribe can't sneak a notification in.
      await _reconcileScheduling();
    }
    notifyListeners();
  }

  /// Test-now button: trigger an immediate notification on the daily
  /// channel without waiting for the scheduled alarm.
  Future<void> testDaily() async {
    await NotificationService.instance.showDailyTest(
      'Aakaash · Test',
      'Daily weather notifications are working.',
    );
  }

  /// Re-arm the daily alarm immediately. Called after the user grants
  /// SCHEDULE_EXACT_ALARM permission so the alarm is upgraded to exact
  /// mode without needing an app restart.
  Future<void> rescheduleDaily() async {
    if (_settings.dailyOn) {
      await NotificationService.instance.scheduleDailyWeather(
        time: _settings.dailyTime,
        title: 'Aakaash · Weather today',
        body: 'Tap to see today\'s forecast.',
        payload: 'home',
      );
    }
  }

  /// Test-now button for the calamity channel: posts a small synthetic
  /// tile so the user can verify channel formatting.
  Future<void> testCalamity() async {
    await NotificationService.instance.showCalamity(
      Calamity(
        id: 'test:${DateTime.now().millisecondsSinceEpoch}',
        title: 'Test alert — your channel is working.',
        type: CalamityType.storm,
        severity: CalamitySeverity.warning,
        latitude: 23.81,
        longitude: 90.41,
        locationName: 'Aakaash test',
        description: 'Synthetic event posted by the test-now button.',
        observedAt: DateTime.now(),
        sourceName: 'Aakaash · Test',
      ),
    );
  }

  /// Test-now button for the dedicated earthquake channel. Posts a
  /// synthetic M4.2 event near Dhaka so the user can verify sound +
  /// vibration + importance-max head-up display.
  Future<void> testEarthquake() async {
    await NotificationService.instance.showEarthquake(
      Calamity(
        id: 'test:eq:${DateTime.now().millisecondsSinceEpoch}',
        title: 'M4.2 · 18 km W of Dhaka',
        type: CalamityType.earthquake,
        severity: CalamitySeverity.warning,
        latitude: 23.78,
        longitude: 90.30,
        locationName: 'Near Dhaka, Bangladesh',
        description: 'Test earthquake alert — sound + vibration preview.',
        observedAt: DateTime.now(),
        sourceName: 'Aakaash · Test',
      ),
    );
  }

  // ─── internals ────────────────────────────────────────────────

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kDailyOn, _settings.dailyOn);
    await p.setInt(_kDailyHour, _settings.dailyTime.hour);
    await p.setInt(_kDailyMin, _settings.dailyTime.minute);
    await p.setBool(_kCalamityOn, _settings.calamityOn);
    await p.setDouble(_kRadius, _settings.radiusKm);
    await p.setBool(_kEarthquakeOn, _settings.earthquakeOn);
  }

  /// Re-sync the OS-side alarms + worker with the current settings +
  /// subscription state. Called whenever a setting or subscription
  /// changes.
  Future<void> _reconcileScheduling() async {
    final p = await SharedPreferences.getInstance();
    final subStatus = p.getString(_kSubStatus);
    final isRegistered = subStatus == 'registered';

    if (!isRegistered) {
      await NotificationService.instance.cancelDailyWeather();
      await NotificationService.instance.stopCalamityWorker();
      await NotificationService.instance.stopEarthquakeWorker();
      return;
    }
    if (_settings.dailyOn) {
      await NotificationService.instance.scheduleDailyWeather(
        time: _settings.dailyTime,
        title: 'Aakaash · Weather today',
        body: 'Tap to see today\'s forecast.',
        payload: 'home',
      );
    } else {
      await NotificationService.instance.cancelDailyWeather();
    }
    if (_settings.calamityOn) {
      await NotificationService.instance.startCalamityWorker();
    } else {
      await NotificationService.instance.stopCalamityWorker();
    }
    if (_settings.earthquakeOn) {
      await NotificationService.instance.startEarthquakeWorker();
    } else {
      await NotificationService.instance.stopEarthquakeWorker();
    }
  }
}