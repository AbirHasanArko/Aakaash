// lib/services/notification_worker.dart
//
// Background worker entry-point for periodic calamity checks plus the
// shared fetch/filter logic the foreground UI reuses for its
// "test now" buttons.
//
// WorkManager invokes `notificationCallbackDispatcher` in a SEPARATE
// isolate. We can't see Provider/SharedPreferences/NotificationService
// from the parent's state — every dependency we need has to be
// reconstructed here.
//
// To keep this isolate small, we talk to OpenWeather / GDACS through
// raw HTTP rather than re-instantiating the Flutter app's service
// classes (those pull in widgets + provider, which the background
// isolate doesn't have).

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../core/app_constants.dart';
import '../models/calamity_model.dart';
import 'location_service.dart';
import 'notification_service.dart';

// ─────────────── WorkManager top-level dispatcher ───────────────
//
// Must be a top-level function with the @pragma('vm:entry-point')
// annotation so the AOT compiler keeps it in the snapshot and
// WorkManager can invoke it from a background isolate.
@pragma('vm:entry-point')
void notificationCallbackDispatcher() {
  AakaashWorkmanagerBridge.execute();
}

/// Bridge between WorkManager's top-level callback and our shared
/// background-check implementation. Named `AakaashWorkmanagerBridge`
/// (not `WorkmanagerHandler`) so it doesn't shadow the
/// `WorkmanagerHandler` type exported by `package:workmanager`.
class AakaashWorkmanagerBridge {
  AakaashWorkmanagerBridge._();

  /// Called by [notificationCallbackDispatcher].
  static void execute() {
    Workmanager().executeTask((task, inputData) async {
      if (task == kCalamityTaskName) {
        await _runCalamityCheck();
      } else if (task == kEarthquakeTaskName) {
        await _runEarthquakeCheck();
      }
      return true;
    });
  }
}

// ───────────────────────── background check ─────────────────────────

Future<void> _runCalamityCheck() async {
  final p = await SharedPreferences.getInstance();

  // Strict subscription gate — never notify non-subscribers.
  if (!(p.getBool('notif_enabled') ?? false)) return;
  if (p.getString('notif_subscriber_status') != 'registered') return;
  if (!(p.getBool('notif_calamity_on') ?? true)) return;

  // Resolve location — last known fix + radius.
  final loc = await LocationService().getLastKnown();
  if (loc == null) {
    if (kDebugMode) {
      debugPrint('[notification_worker] no last-known location; skip');
    }
    return;
  }
  final radiusKm = p.getDouble('notif_radius_km') ?? 300.0;

  final client = http.Client();
  try {
    final fresh = await NotificationCalamityFetcher.fetchAndFilter(
      client: client,
      lat: loc.lat,
      lon: loc.lon,
      radiusKm: radiusKm,
    );

    // Record a successful run regardless of whether any new events fired.
    await p.setInt(
      'notif_last_run_ms',
      DateTime.now().millisecondsSinceEpoch,
    );

    if (fresh.isEmpty) return;

    // Dedup against the last-seen id-set (so the same event doesn't
    // re-fire every 6 h forever).
    final lastSeenRaw = p.getString('notif_last_calamity_ids') ?? '';
    final lastSeen = lastSeenRaw.isEmpty
        ? <String>{}
        : (json.decode(lastSeenRaw) as List).cast<String>().toSet();
    final newIds = <String>[];
    for (final c in fresh) {
      if (lastSeen.contains(c.id)) continue;
      await NotificationService.instance.showCalamity(c);
      newIds.add(c.id);
    }
    if (newIds.isNotEmpty) {
      final merged = [...newIds, ...lastSeen].take(64).toList();
      await p.setString('notif_last_calamity_ids', json.encode(merged));
    }
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('[notification_worker] failed: $e\n$st');
    }
  } finally {
    client.close();
  }
}

// ───────────────────────── earthquake check ────────────────────────
//
// Country-wide sentinel. Wakes every ~15 min, hits USGS for the
// Bangladesh bbox + a 1° border buffer, and pushes a sound-on push
// for every quake that we haven't seen before. No radius gate —
// EQ alerts are sent even if the user is far from the epicentre,
// because earthquakes are a national-level concern.

Future<void> _runEarthquakeCheck() async {
  final p = await SharedPreferences.getInstance();

  // Same subscription gate as the calamity worker.
  if (!(p.getBool('notif_enabled') ?? false)) return;
  if (p.getString('notif_subscriber_status') != 'registered') return;
  if (!(p.getBool('notif_earthquake_on') ?? true)) return;

  final client = http.Client();
  try {
    final fresh = await NotificationEarthquakeFetcher.fetch(client: client);
    if (fresh.isEmpty) return;

    final lastSeenRaw = p.getString('notif_last_eq_ids') ?? '';
    final lastSeen = lastSeenRaw.isEmpty
        ? <String>{}
        : (json.decode(lastSeenRaw) as List).cast<String>().toSet();

    final newIds = <String>[];
    for (final c in fresh) {
      if (lastSeen.contains(c.id)) continue;
      await NotificationService.instance.showEarthquake(c);
      newIds.add(c.id);
    }
    if (newIds.isNotEmpty) {
      final merged = [...newIds, ...lastSeen].take(128).toList();
      await p.setString('notif_last_eq_ids', json.encode(merged));
    }
    await p.setInt(
      'notif_last_eq_run_ms',
      DateTime.now().millisecondsSinceEpoch,
    );
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('[notification_worker] earthquake failed: $e\n$st');
    }
  } finally {
    client.close();
  }
}

// ─────────────── shared fetch + filter (foreground + bg) ───────────────

/// Fetches calamities near (lat, lon) and returns only those that are
/// active and inside the radius. Reused by the background worker
/// above; can also be invoked from the UI for a "test now" path.
class NotificationCalamityFetcher {
  NotificationCalamityFetcher._();

  static Future<List<Calamity>> fetchAndFilter({
    required http.Client client,
    required double lat,
    required double lon,
    required double radiusKm,
  }) async {
    final all = await _fetchCalamities(client, lat, lon);
    return all
        .where((c) => c.isActive && c.distanceKmFrom(lat, lon) <= radiusKm)
        .toList();
  }

  /// Mirror of [CalamityService.fetchCalamities] without the flood-risk
  /// tile layer (which would require firing 12 OpenWeather calls in
  /// the background isolate — too expensive for a notification check).
  static Future<List<Calamity>> _fetchCalamities(
    http.Client client,
    double lat,
    double lon,
  ) async {
    final headers = {
      'User-Agent': 'Aakaash/1.0 (https://github.com/AbirHasanArko)',
      'Accept': 'application/json',
    };
    final out = <Calamity>[];

    // USGS earthquakes (M3.5+ within Bangladesh bbox + Bay of Bengal).
    try {
      final uri = Uri.parse(
        'https://earthquake.usgs.gov/fdsnws/event/1/query'
        '?format=geojson&minmagnitude=3.5'
        '&minlatitude=18&maxlatitude=28'
        '&minlongitude=86&maxlongitude=94'
        '&orderby=time&limit=50',
      );
      final res = await client.get(uri, headers: headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final body = json.decode(res.body) as Map<String, dynamic>;
        final features = (body['features'] as List?) ?? const [];
        for (final f in features) {
          try {
            final props = (f as Map<String, dynamic>)['properties']
                as Map<String, dynamic>;
            final coords = ((f['geometry'] as Map<String, dynamic>)['coordinates']
                    as List)
                .cast<num>();
            final mag = (props['mag'] as num?)?.toDouble();
            final observed = DateTime.fromMillisecondsSinceEpoch(
              ((props['time'] as num?)?.toInt()) ?? 0,
            );
            out.add(Calamity(
              id: 'usgs:${props['id'] ?? coords.hashCode}',
              title:
                  'M${mag?.toStringAsFixed(1) ?? '?'} — ${props['place'] ?? ''}',
              type: CalamityType.earthquake,
              severity: mag == null
                  ? CalamitySeverity.info
                  : mag >= 6.0
                      ? CalamitySeverity.extreme
                      : mag >= 5.0
                          ? CalamitySeverity.danger
                          : CalamitySeverity.warning,
              latitude: coords[1].toDouble(),
              longitude: coords[0].toDouble(),
              locationName: (props['place'] as String?) ?? 'BD',
              description: (props['title'] as String?) ?? '',
              observedAt: observed,
              magnitude: mag,
              sourceName: 'USGS',
            ));
          } catch (_) {/* skip malformed row */}
        }
      }
    } catch (_) {/* USGS offline / blocked */}

    // GDACS events (cyclones / floods tagged to Bangladesh).
    try {
      final uri = Uri.parse(
        'https://www.gdacs.org/gdacsapi/api/events/geteventlist/SEARCH'
        '?from=${_nDaysAgo(7)}&to=2099-12-31'
        '&country=Bangladesh&limit=50',
      );
      final res = await client.get(uri, headers: headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final body = json.decode(res.body) as Map<String, dynamic>;
        final features = (body['features'] as List?) ?? const [];
        for (final f in features) {
          try {
            final props = (f as Map<String, dynamic>)['properties']
                as Map<String, dynamic>;
            final geom = (f['geometry'] as Map?)?.cast<String, dynamic>();
            final coords = (geom?['coordinates'] as List?)?.cast<num>();
            if (coords == null || coords.length < 2) continue;
            final lon2 = coords[0].toDouble();
            final lat2 = coords[1].toDouble();
            if (lat2 < 18 || lat2 > 28 || lon2 < 86 || lon2 > 94) continue;
            final alert = (props['alertlevel'] as String?) ?? 'Green';
            final severity = alert.toLowerCase().contains('red')
                ? CalamitySeverity.extreme
                : alert.toLowerCase().contains('orange')
                    ? CalamitySeverity.danger
                    : alert.toLowerCase().contains('yellow')
                        ? CalamitySeverity.warning
                        : CalamitySeverity.info;
            final type = _gdacsType((props['eventtype'] as String?) ?? '');
            final fromDate = (props['fromdate'] as String?) ?? '';
            final observed = DateTime.tryParse(fromDate) ?? DateTime.now();
            out.add(Calamity(
              id: 'gdacs:${props['eventid'] ?? fromDate.hashCode}',
              title: (props['name'] as String?) ?? 'GDACS event',
              type: type,
              severity: severity,
              latitude: lat2,
              longitude: lon2,
              locationName: 'Bangladesh',
              description: (props['description'] as String?) ?? '',
              observedAt: observed,
              sourceName: 'GDACS',
            ));
          } catch (_) {/* skip */}
        }
      }
    } catch (_) {/* GDACS offline / blocked */}

    return _dedupe(out);
  }

  static String _nDaysAgo(int n) {
    final d = DateTime.now().toUtc().subtract(Duration(days: n));
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  static CalamityType _gdacsType(String t) {
    final s = t.toLowerCase();
    if (s.contains('eq')) return CalamityType.earthquake;
    if (s.contains('fl')) return CalamityType.flood;
    if (s.contains('tc')) return CalamityType.cyclone;
    return CalamityType.other;
  }

  static List<Calamity> _dedupe(List<Calamity> input) {
    final seen = <String>{};
    final out = <Calamity>[];
    for (final c in input) {
      final k = '${c.type.name}|${c.title}|'
          '${c.latitude.toStringAsFixed(2)}|'
          '${c.longitude.toStringAsFixed(2)}';
      if (seen.add(k)) out.add(c);
    }
    return out;
  }
}

// ──────────────────────── earthquake fetcher ────────────────────────
//
// Fetches earthquakes inside the Bangladesh bounding box plus a 1°
// border buffer (covers Myanmar, NE India, Bay of Bengal). No user-
// radius gate — earthquakes are a national alert. Filters out anything
// older than 24 h via [Calamity.isActive].

class NotificationEarthquakeFetcher {
  NotificationEarthquakeFetcher._();

  /// Bangladesh bounding box plus 1° of border buffer.
  static const double _minLat = 19.5;
  static const double _maxLat = 27.5;
  static const double _minLon = 85.0;
  static const double _maxLon = 95.0;

  /// Minimum USGS magnitude to surface. The same threshold the
  /// calamity worker uses, so we don't double-alert on tiny tremors.
  static const double _minMag = 3.5;

  static Future<List<Calamity>> fetch({
    required http.Client client,
  }) async {
    final headers = {
      'User-Agent': 'Aakaash/1.0 (https://github.com/AbirHasanArko)',
      'Accept': 'application/json',
    };
    final out = <Calamity>[];
    try {
      final uri = Uri.parse(
        'https://earthquake.usgs.gov/fdsnws/event/1/query'
        '?format=geojson&minmagnitude=$_minMag'
        '&minlatitude=$_minLat&maxlatitude=$_maxLat'
        '&minlongitude=$_minLon&maxlongitude=$_maxLon'
        '&orderby=time&limit=50',
      );
      final res = await client.get(uri, headers: headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final body = json.decode(res.body) as Map<String, dynamic>;
        final features = (body['features'] as List?) ?? const [];
        for (final f in features) {
          try {
            final props = (f as Map<String, dynamic>)['properties']
                as Map<String, dynamic>;
            final coords = ((f['geometry'] as Map<String, dynamic>)['coordinates']
                    as List)
                .cast<num>();
            final mag = (props['mag'] as num?)?.toDouble();
            final observed = DateTime.fromMillisecondsSinceEpoch(
              ((props['time'] as num?)?.toInt()) ?? 0,
            );
            final place = (props['place'] as String?) ?? '';
            final insideBd = _isInsideBangladesh(
                coords[1].toDouble(), coords[0].toDouble());
            out.add(Calamity(
              id: 'usgs:${props['id'] ?? coords.hashCode}',
              title:
                  'M${mag?.toStringAsFixed(1) ?? '?'} — ${place.isEmpty ? 'Bangladesh region' : place}',
              type: CalamityType.earthquake,
              severity: mag == null
                  ? CalamitySeverity.info
                  : mag >= 6.0
                      ? CalamitySeverity.extreme
                      : mag >= 5.0
                          ? CalamitySeverity.danger
                          : CalamitySeverity.warning,
              latitude: coords[1].toDouble(),
              longitude: coords[0].toDouble(),
              locationName: place.isEmpty
                  ? (insideBd ? 'Bangladesh' : 'Near Bangladesh border')
                  : place,
              description: (props['title'] as String?) ?? '',
              observedAt: observed,
              magnitude: mag,
              sourceName: 'USGS',
              sourceUrl: (props['detail'] as String?),
            ));
          } catch (_) {/* skip malformed row */}
        }
      }
    } catch (_) {/* USGS offline / blocked */}
    return out.where((c) => c.isActive).toList();
  }

  static bool _isInsideBangladesh(double lat, double lon) =>
      lat >= 20.5 && lat <= 26.5 && lon >= 88.0 && lon <= 92.5;
}

// Silence "unused" warnings for the imported constants we don't read
// directly here but want available so a future patch can drop back
// to OWM data without re-importing.
// ignore: unused_element
const _kOwmBase = AppConstants.owmBase;