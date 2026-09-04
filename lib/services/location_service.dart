import 'dart:async';
import 'dart:math' as math;

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/bangladesh_cities.dart';
import '../models/weather_models.dart';

class LocationServiceException implements Exception {
  final String message;
  final bool permissionDenied;
  const LocationServiceException(this.message, {this.permissionDenied = false});
  @override
  String toString() => message;
}

/// A cached (lat, lon) + freshness timestamp. Used by the background
/// notification worker so we can resolve "current location" without
/// re-prompting for permission or acquiring a fresh GPS fix.
class LastKnownLocation {
  final double lat;
  final double lon;
  final DateTime updatedAt;
  const LastKnownLocation({
    required this.lat,
    required this.lon,
    required this.updatedAt,
  });

  /// Reject caches older than 24 h — beyond that the user may have
  /// moved significantly and we shouldn't pretend we know where they
  /// are. (Background work doesn't have access to foreground permission
  /// state anyway, so a stale cache is the best we can do.)
  bool get isFresh =>
      DateTime.now().difference(updatedAt) < const Duration(hours: 24);
}

/// Locates the user and resolves to a Bangladesh city label when possible.
class LocationService {
  /// Request permission then return the current position, or throw.
  Future<Position> getCurrentPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw const LocationServiceException(
        'Location services are turned off. '
        'Enable GPS from quick settings and try again.',
      );
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      throw const LocationServiceException(
        'Location permission was permanently denied. '
        'Open Settings → Apps → Aakaash → Permissions and enable Location.',
        permissionDenied: true,
      );
    }
    if (perm == LocationPermission.denied) {
      throw const LocationServiceException(
        'Location permission is required to fetch your local weather.',
        permissionDenied: true,
      );
    }

    // Try a fresh fix with a 20s budget. On Android, the very first
    // GPS cold-start can take 10–15s indoors or with weak signal;
    // 12s was too tight and produced "Future not completed" timeouts.
    //
    // Important: force `forceAndroidLocationManager: true` so we bypass
    // Google Play Services fused-provider caching. Otherwise Geolocator
    // happily returns a stale fused-location that may be days old and
    // we end up "locating" the user to the city we were already on.
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 20),
        forceAndroidLocationManager: true,
      );
      // Persist the successful fix so background notifications can use it.
      await persist(pos.latitude, pos.longitude);
      return pos;
    } on TimeoutException {
      // GPS genuinely couldn't get a fresh fix. Don't silently fall back
      // to a possibly-stale last known position — surface the failure so
      // the caller can show a "couldn't detect" snack instead of re-rendering
      // the previous city.
      throw const LocationServiceException(
        "Couldn't get a fresh GPS fix in time. "
        'Step outside or enable Google Location Accuracy, then try again.',
      );
    }
  }

  // -- Persistence for background notifications -----------------------

  static const _kLatKey = 'last_known_lat';
  static const _kLonKey = 'last_known_lon';
  static const _kAtKey = 'last_known_at_ms';

  /// Persist a (lat, lon) fix so the background notification worker
  /// can resolve "current location" without acquiring a fresh fix
  /// (which would require user-granted foreground permission).
  Future<void> persist(double lat, double lon) async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_kLatKey, lat);
    await p.setDouble(_kLonKey, lon);
    await p.setInt(_kAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Load the last persisted (lat, lon). Returns null if no fix has
  /// ever been recorded or if the cache is stale (see [LastKnownLocation.isFresh]).
  Future<LastKnownLocation?> getLastKnown() async {
    final p = await SharedPreferences.getInstance();
    final lat = p.getDouble(_kLatKey);
    final lon = p.getDouble(_kLonKey);
    final atMs = p.getInt(_kAtKey);
    if (lat == null || lon == null || atMs == null) return null;
    final loc = LastKnownLocation(
      lat: lat,
      lon: lon,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(atMs),
    );
    return loc.isFresh ? loc : null;
  }

  /// Resolve position into the nearest Bangladesh label (City, district).
  Future<City?> nearestBangladeshCity({
    required double lat,
    required double lon,
  }) async {
    double bestKm = double.infinity;
    City? best;
    for (final c in kBangladeshCities) {
      final km = _haversineKm(lat, lon, c.lat, c.lon);
      if (km < bestKm) {
        bestKm = km;
        best = c;
      }
    }
    return best;
  }

  /// Reverse-geocode via the system, falling back to nearest Bangladesh city.
  Future<String> describePosition({
    required double lat,
    required double lon,
  }) async {
    try {
      final placemarks =
          await placemarkFromCoordinates(lat, lon).timeout(const Duration(seconds: 6));
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = <String>[
          if ((p.locality ?? '').isNotEmpty) p.locality!,
          if ((p.subAdministrativeArea ?? '').isNotEmpty) p.subAdministrativeArea!,
        ];
        return parts.join(', ');
      }
    } catch (_) {
      // Ignore — fall back to nearest Bangladesh city.
    }
    final nearest = await nearestBangladeshCity(lat: lat, lon: lon);
    return nearest?.fullLabel ?? 'Your Location';
  }

  /// Opens Android app-settings page so the user can grant permission.
  Future<void> openSettings() => Geolocator.openAppSettings();

  static double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.pow(math.sin(dLat / 2), 2).toDouble() +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.pow(math.sin(dLon / 2), 2).toDouble();
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double _deg2rad(double deg) => deg * (math.pi / 180.0);
}
