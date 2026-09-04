// lib/models/calamity_model.dart
//
// Data model for natural calamity events in and around Bangladesh.
// Sourced from open APIs (GDACS, USGS Earthquake, NASA FIRMS) and
// derived from OpenWeather forecast rain by CalamityService, then
// rendered on the CalamityScreen.
//
// Latitudes and longitudes follow the ISO 6709 convention used by
// every disaster API this app consumes (decimal degrees, north / east
// positive). Bangladesh's bounding box is approximately 20.5°N–26.5°N,
// 88.0°E–92.5°E.

import 'dart:math' as math;

import 'package:flutter/material.dart';

enum CalamityType {
  flood,
  cyclone,
  earthquake,
  storm,
  landslide,
  wildfire,
  other;

  String get label {
    switch (this) {
      case CalamityType.flood:
        return 'Flood';
      case CalamityType.cyclone:
        return 'Cyclone';
      case CalamityType.earthquake:
        return 'Earthquake';
      case CalamityType.storm:
        return 'Storm';
      case CalamityType.landslide:
        return 'Landslide';
      case CalamityType.wildfire:
        return 'Wildfire';
      case CalamityType.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case CalamityType.flood:
        return Icons.waves_rounded;
      case CalamityType.cyclone:
        return Icons.cyclone_rounded;
      case CalamityType.earthquake:
        return Icons.vibration_rounded;
      case CalamityType.storm:
        return Icons.thunderstorm_rounded;
      case CalamityType.landslide:
        return Icons.landscape_rounded;
      case CalamityType.wildfire:
        return Icons.local_fire_department_rounded;
      case CalamityType.other:
        return Icons.warning_amber_rounded;
    }
  }

  Color get accent {
    switch (this) {
      case CalamityType.flood:
        return const Color(0xFF3D8BDC);
      case CalamityType.cyclone:
        return const Color(0xFF8B5CF6);
      case CalamityType.earthquake:
        return const Color(0xFFB45309);
      case CalamityType.storm:
        return const Color(0xFF6366F1);
      case CalamityType.landslide:
        return const Color(0xFF92400E);
      case CalamityType.wildfire:
        return const Color(0xFFEF4444);
      case CalamityType.other:
        return const Color(0xFF6B7280);
    }
  }
}

enum CalamitySeverity {
  info, // Green – awareness only
  warning, // Amber – be prepared
  danger, // Orange – take action
  extreme; // Red   – life-threatening

  String get label {
    switch (this) {
      case CalamitySeverity.info:
        return 'Info';
      case CalamitySeverity.warning:
        return 'Warning';
      case CalamitySeverity.danger:
        return 'Danger';
      case CalamitySeverity.extreme:
        return 'Extreme';
    }
  }

  Color get color {
    switch (this) {
      case CalamitySeverity.info:
        return const Color(0xFF10B981);
      case CalamitySeverity.warning:
        return const Color(0xFFF59E0B);
      case CalamitySeverity.danger:
        return const Color(0xFFEF4444);
      case CalamitySeverity.extreme:
        return const Color(0xFFB91C1C);
    }
  }

  /// Build a severity bucket from a 0..1 risk score using the same
  /// thresholds as the heatmap.
  static CalamitySeverity fromRiskScore(double s) {
    if (s >= 0.75) return CalamitySeverity.extreme;
    if (s >= 0.5) return CalamitySeverity.danger;
    if (s >= 0.25) return CalamitySeverity.warning;
    return CalamitySeverity.info;
  }
}

/// A single natural-calamity event as rendered by the UI.
class Calamity {
  final String id;
  final String title;
  final CalamityType type;
  final CalamitySeverity severity;
  final double latitude;
  final double longitude;
  final String locationName;
  final String description;
  final DateTime observedAt;
  final double? magnitude; // e.g. M5.4 for earthquakes, wind km/h for cyclones
  final String sourceName;
  final String? sourceUrl;

  /// Optional district (matched from the BD GeoJSON by point-in-polygon).
  final String? district;

  /// Optional division (matched from the BD GeoJSON).
  final String? division;

  /// Optional numeric score 0..1 — used for flood-risk districts to
  /// encode how strong the risk is on the heatmap.
  final double? riskScore;

  /// Optional lead time, e.g. "next 72 h" for flood-risk districts.
  final String? timeline;

  const Calamity({
    required this.id,
    required this.title,
    required this.type,
    required this.severity,
    required this.latitude,
    required this.longitude,
    required this.locationName,
    required this.description,
    required this.observedAt,
    required this.sourceName,
    this.magnitude,
    this.sourceUrl,
    this.district,
    this.division,
    this.riskScore,
    this.timeline,
  });

  bool get isWithinBangladesh =>
      latitude >= 20.5 &&
      latitude <= 26.5 &&
      longitude >= 88.0 &&
      longitude <= 92.5;

  /// True when this event is current or in the near future (the rule
  /// depends on the source). Past events are filtered out before being
  /// pushed as notifications.
  ///
  /// Rule per type:
  ///   * earthquake / wildfire — observedAt within last 24 h
  ///   * cyclone — observedAt within last 48 h (long enough to cover
  ///     the typical Bay-of-Bengal cyclone lifetime without spamming)
  ///   * flood — either a forecast tile (timeline "next 72 h" / "next
  ///     7 days") with riskScore >= 0.25, or a live GDACS report
  ///     within the last 48 h
  ///   * storm / landslide / other — observedAt within last 48 h
  bool get isActive {
    final now = DateTime.now();
    switch (type) {
      case CalamityType.earthquake:
      case CalamityType.wildfire:
        return now.difference(observedAt) <= const Duration(hours: 24);
      case CalamityType.cyclone:
        return now.difference(observedAt) <= const Duration(hours: 48);
      case CalamityType.flood:
        final t = (timeline ?? '').toLowerCase();
        if (t.contains('next 72 h') || t.contains('next 7 days')) {
          return (riskScore ?? 0) >= 0.25;
        }
        return now.difference(observedAt) <= const Duration(hours: 48);
      case CalamityType.storm:
      case CalamityType.landslide:
      case CalamityType.other:
        return now.difference(observedAt) <= const Duration(hours: 48);
    }
  }

  /// Great-circle distance in km from (lat, lon) to this event.
  /// Uses the haversine formula; sufficient for proximity-bucketing
  /// at the 50–500 km scale.
  double distanceKmFrom(double lat, double lon) {
    const r = 6371.0;
    final dLat = _deg2rad(latitude - lat);
    final dLon = _deg2rad(longitude - lon);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat)) *
            math.cos(_deg2rad(latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double _deg2rad(double d) => d * (math.pi / 180.0);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type.name,
        'severity': severity.name,
        'latitude': latitude,
        'longitude': longitude,
        'locationName': locationName,
        'description': description,
        'observedAt': observedAt.toIso8601String(),
        'magnitude': magnitude,
        'sourceName': sourceName,
        'sourceUrl': sourceUrl,
        'district': district,
        'division': division,
        'riskScore': riskScore,
        'timeline': timeline,
      };

  factory Calamity.fromJson(Map<String, dynamic> j) => Calamity(
        id: j['id'] as String,
        title: j['title'] as String,
        type: CalamityType.values.firstWhere(
          (e) => e.name == (j['type'] as String? ?? 'other'),
          orElse: () => CalamityType.other,
        ),
        severity: CalamitySeverity.values.firstWhere(
          (e) => e.name == (j['severity'] as String? ?? 'info'),
          orElse: () => CalamitySeverity.info,
        ),
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        locationName: j['locationName'] as String? ?? 'Bangladesh',
        description: j['description'] as String? ?? '',
        observedAt:
            DateTime.tryParse(j['observedAt'] as String? ?? '') ?? DateTime.now(),
        magnitude: (j['magnitude'] as num?)?.toDouble(),
        sourceName: j['sourceName'] as String? ?? 'Unknown',
        sourceUrl: j['sourceUrl'] as String?,
        district: j['district'] as String?,
        division: j['division'] as String?,
        riskScore: (j['riskScore'] as num?)?.toDouble(),
        timeline: j['timeline'] as String?,
      );
}