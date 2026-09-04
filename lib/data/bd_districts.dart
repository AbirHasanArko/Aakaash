// lib/data/bd_districts.dart
//
// Loader for the bundled Bangladesh district GeoJSON (assets/map/bd_districts.json).
// Each district is exposed as a [District] with a list of polygon rings (outer + holes),
// a precomputed centroid, and a bounding box. The model is used by the
// calamity map to paint the country in real district boundaries and by the
// service to map a (lat, lon) report back to its district.
//
// The polygons are stored in raw [[[[lon, lat], ...]]] GeoJSON order. The
// painter projects them to screen-space using a uniform lat/lon scale
// matching the visual bounds of Bangladesh.

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart' show Offset, Size;

/// Closed ring of (lon, lat) pairs.
typedef DistrictRing = List<List<double>>;

/// A single district polygon (outer ring + optional holes).
typedef DistrictPolygon = List<DistrictRing>;

class District {
  final String name;
  final String division;
  final String districtPcode;
  final String divisionPcode;

  /// Polygons in GeoJSON MultiPolygon form: [polygon[ring[point]]].
  /// Outer ring is the first in each polygon.
  final List<DistrictPolygon> polygons;

  /// Centroid (lat, lon) computed from the largest outer ring.
  final double centroidLat;
  final double centroidLon;

  /// Bounding box (lonMin, latMin, lonMax, latMax).
  final double lonMin;
  final double latMin;
  final double lonMax;
  final double latMax;

  const District({
    required this.name,
    required this.division,
    required this.districtPcode,
    required this.divisionPcode,
    required this.polygons,
    required this.centroidLat,
    required this.centroidLon,
    required this.lonMin,
    required this.latMin,
    required this.lonMax,
    required this.latMax,
  });

  /// True if the [lon, lat] point falls inside any of this district's polygons.
  bool containsPoint(double lon, double lat) {
    for (final poly in polygons) {
      if (poly.isEmpty) continue;
      if (pointInPolygon(lon, lat, poly[0])) return true;
    }
    return false;
  }
}

/// Even-odd ray-cast point-in-polygon test. `ring` is a closed ring of
/// (lon, lat) pairs. Returns true when [lon, lat] lies inside the ring.
bool pointInPolygon(double lon, double lat, DistrictRing ring) {
  bool inside = false;
  int j = ring.length - 1;
  for (int i = 0; i < ring.length; i++) {
    final xi = ring[i][0];
    final yi = ring[i][1];
    final xj = ring[j][0];
    final yj = ring[j][1];
    final intersect = ((yi > lat) != (yj > lat)) &&
        (lon < (xj - xi) * (lat - yi) / ((yj - yi) == 0 ? 1e-12 : (yj - yi)) + xi);
    if (intersect) inside = !inside;
    j = i;
  }
  return inside;
}

/// Lazy-loaded list of all 64 Bangladesh districts.
class BangladeshDistricts {
  static const _assetPath = 'assets/map/bd_districts.json';

  static List<District>? _cache;

  /// Load and parse the bundled GeoJSON. Caches the result.
  static Future<List<District>> load({bool force = false}) async {
    if (!force && _cache != null) return _cache!;
    final raw = await rootBundle.loadString(_assetPath);
    final data = json.decode(raw) as Map<String, dynamic>;
    final features = (data['features'] as List).cast<Map<String, dynamic>>();
    final list = <District>[];
    for (final f in features) {
      final props = (f['properties'] as Map?)?.cast<String, dynamic>() ?? {};
      final geom = (f['geometry'] as Map).cast<String, dynamic>();
      final type = geom['type'] as String;
      final coords = geom['coordinates'];

      final List<DistrictPolygon> polygons;
      if (type == 'MultiPolygon') {
        polygons = (coords as List).map((poly) {
          return (poly as List).map((ring) {
            return (ring as List)
                .map<List<double>>((p) => [
                      (p[0] as num).toDouble(),
                      (p[1] as num).toDouble(),
                    ])
                .toList();
          }).toList();
        }).toList();
      } else if (type == 'Polygon') {
        polygons = [
          (coords as List).map((ring) {
            return (ring as List)
                .map<List<double>>((p) => [
                      (p[0] as num).toDouble(),
                      (p[1] as num).toDouble(),
                    ])
                .toList();
          }).toList(),
        ];
      } else {
        continue;
      }

      // Compute centroid + bbox from the largest outer ring.
      DistrictRing largestRing = polygons.first.first;
      double largestArea = -1;
      for (final poly in polygons) {
        if (poly.isEmpty) continue;
        final area = _ringArea(poly.first);
        if (area > largestArea) {
          largestArea = area;
          largestRing = poly.first;
        }
      }
      final centroid = _ringCentroid(largestRing);
      final bbox = _ringBbox(largestRing);

      list.add(District(
        name: (props['district'] as String?) ?? 'Unknown',
        division: (props['division'] as String?) ?? 'Unknown',
        districtPcode: (props['district_pcode'] as String?) ?? '',
        divisionPcode: (props['division_pcode'] as String?) ?? '',
        polygons: polygons,
        centroidLat: centroid.$1,
        centroidLon: centroid.$2,
        lonMin: bbox.$1,
        latMin: bbox.$2,
        lonMax: bbox.$3,
        latMax: bbox.$4,
      ));
    }
    _cache = list;
    return list;
  }

  /// Find the district whose polygon contains the given point.
  /// Points outside the country return null.
  static District? findDistrict(
    List<District> districts,
    double lat,
    double lon,
  ) {
    for (final d in districts) {
      if (d.containsPoint(lon, lat)) return d;
    }
    return null;
  }

  // ──────────────────────────── geometry helpers ────────────────────────────

  /// Shoelace area for a closed ring of (lon, lat). Returns a signed area;
  /// the absolute value is the geometric area.
  static double _ringArea(DistrictRing ring) {
    if (ring.length < 3) return 0;
    double s = 0;
    for (int i = 0; i < ring.length - 1; i++) {
      final a = ring[i];
      final b = ring[i + 1];
      s += (a[0] * b[1]) - (b[0] * a[1]);
    }
    return s.abs() / 2.0;
  }

  /// Centroid of a closed ring (lon, lat). Returns (lat, lon).
  static (double, double) _ringCentroid(DistrictRing ring) {
    if (ring.length < 3) return (0, 0);
    double cx = 0, cy = 0;
    double a = 0;
    for (int i = 0; i < ring.length - 1; i++) {
      final p1 = ring[i];
      final p2 = ring[i + 1];
      final cross = (p1[0] * p2[1]) - (p2[0] * p1[1]);
      cx += (p1[0] + p2[0]) * cross;
      cy += (p1[1] + p2[1]) * cross;
      a += cross;
    }
    if (a.abs() < 1e-12) {
      // Degenerate ring — fall back to average.
      double sx = 0, sy = 0;
      for (final p in ring) {
        sx += p[0];
        sy += p[1];
      }
      final n = ring.length;
      return (sy / n, sx / n);
    }
    final centroidLon = cx / (3 * a);
    final centroidLat = cy / (3 * a);
    return (centroidLat, centroidLon);
  }

  /// Bounding box of a closed ring. Returns (lonMin, latMin, lonMax, latMax).
  static (double, double, double, double) _ringBbox(DistrictRing ring) {
    double lonMin = double.infinity;
    double lonMax = -double.infinity;
    double latMin = double.infinity;
    double latMax = -double.infinity;
    for (final p in ring) {
      final lon = p[0];
      final lat = p[1];
      if (lon < lonMin) lonMin = lon;
      if (lon > lonMax) lonMax = lon;
      if (lat < latMin) latMin = lat;
      if (lat > latMax) latMax = lat;
    }
    return (lonMin, latMin, lonMax, latMax);
  }

  /// Use the top-level `pointInPolygon` helper on a single ring, or
  /// `District.containsPoint` for a full district check.
}


/// Projection helpers shared between the map painter and the pin overlay.
class MapProjection {
  /// Geographic bounding box that fits Bangladesh with a small margin.
  static const double lonMin = 87.8;
  static const double lonMax = 92.7;
  static const double latMin = 20.4;
  static const double latMax = 26.7;

  static const double _lonSpan = lonMax - lonMin;
  static const double _latSpan = latMax - latMin;

  /// Public read-only spans so the map painter can compute per-pixel
  /// simplification tolerances in normalized space.
  static double get lonSpan => _lonSpan;
  static double get latSpan => _latSpan;

  /// Convert (lon, lat) to fractional position [0,1] in the bounded box.
  static (double, double) project(double lon, double lat) {
    final nx = ((lon - lonMin) / _lonSpan).clamp(0.0, 1.0);
    final ny = 1.0 - ((lat - latMin) / _latSpan).clamp(0.0, 1.0);
    return (nx, ny);
  }

  /// Convert fractional position to screen offset for a given canvas size.
  static Offset pointFor(double lon, double lat, Size size) {
    final (nx, ny) = project(lon, lat);
    return Offset(nx * size.width, ny * size.height);
  }

  /// True if any polygon vertex of a district lies outside the geographic
  /// bounds (used to estimate how much of the country fits in the painter).
  static bool isInsideBounds(double lon, double lat) {
    return lon >= lonMin && lon <= lonMax && lat >= latMin && lat <= latMax;
  }

  /// Distance in degrees between two (lat, lon) points (good enough for
  /// "nearest city" pinning).
  static double distanceDegrees(double lat1, double lon1, double lat2, double lon2) {
    final dx = lon1 - lon2;
    final dy = lat1 - lat2;
    return math.sqrt(dx * dx + dy * dy);
  }
}
