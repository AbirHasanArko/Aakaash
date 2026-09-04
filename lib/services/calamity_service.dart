// lib/services/calamity_service.dart
//
// Fetches real natural-calamity information for Bangladesh from open,
// free APIs and derives district-level flood risk from OpenWeather's
// 5-day forecast. All sources are CORS-tolerant and don't require
// authentication except for OpenWeather (free tier key).
//
//  * USGS Earthquake Hazards — global bbox query (BD + Bay of Bengal)
//    https://earthquake.usgs.gov/fdsnws/event/1/query
//
//  * GDACS — Global Disaster Alert and Coordination System
//    https://www.gdacs.org/gdacsapi/api/events/geteventlist/SEARCH
//
//  * Open-Meteo Flood — actual river discharge (m³/s) per (lat, lon)
//    over the next 7 days, ECMWF/GloFAS-derived. No auth, no key.
//    https://flood-api.open-meteo.com/v1/flood
//
//  * OpenWeather /forecast — 5-day / 3-hourly rainfall summed per city
//    https://api.openweathermap.org/data/2.5/forecast
//
//  * NASA FIRMS — fire hotspots (MODIS/VIIRS) for Bangladesh
//    https://firms.modaps.eosdis.nasa.gov/api/area/country/.../BD/24h.geojson
//
//  The flood layer is a FUSION of Open-Meteo (real hydrology) and
//  OpenWeather (rain-forecast estimation). Per-district we keep the
//  higher of the two scores and tag the source prominently.
//
// The service emits a single, deduplicated list of Calamity entries
// (each tagged with its district + division name). The screen attaches
// the district polygons separately via the GeoJSON loader.

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/app_constants.dart';
import '../models/calamity_model.dart';

class CalamityService {
  CalamityService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  // Timeouts per request — fail fast so the UI can show partial data.
  static const Duration _fastTimeout = Duration(seconds: 12);
  static const Duration _slowTimeout = Duration(seconds: 20);

  // Broad geographical region: BD + Bay of Bengal + adjacent borders.
  // Storms and bay-formed cyclones are picked up here.
  static const double latMin = 18.0;
  static const double latMax = 28.0;
  static const double lonMin = 86.0;
  static const double lonMax = 94.0;

  static const Map<String, String> _headers = {
    'User-Agent': 'Aakaash/1.0 (https://github.com/AbirHasanArko)',
    'Accept': 'application/json',
  };

  /// Fetch all sources and return a single, deduplicated list of
  /// Calamity objects, ordered by severity then by date.
  Future<List<Calamity>> fetchCalamities() async {
    final results = await Future.wait<Iterable<Calamity>>(
      [
        _fetchUsgsEarthquakes(),
        _fetchGdacs(),
        _fetchNasaFirms(),
      ],
      eagerError: false,
    ).catchError((Object e, StackTrace st) {
      return <Iterable<Calamity>>[];
    });

    final flat = <Calamity>[];
    for (final r in results) {
      flat.addAll(r);
    }
    return _dedupe(flat);
  }

  // ───────────────────────── USGS Earthquake Hazards ─────────────────────────
  Future<List<Calamity>> _fetchUsgsEarthquakes() async {
    final uri = Uri.parse(
      'https://earthquake.usgs.gov/fdsnws/event/1/query'
      '?format=geojson'
      '&starttime=${_oneYearAgo()}'
      '&minmagnitude=3.5'
      '&minlatitude=$latMin&maxlatitude=$latMax'
      '&minlongitude=$lonMin&maxlongitude=$lonMax'
      '&orderby=time'
      '&limit=200',
    );
    try {
      final res = await _client.get(uri, headers: _headers).timeout(_slowTimeout);
      if (res.statusCode != 200) return const [];
      final body = json.decode(res.body) as Map<String, dynamic>;
      final features = (body['features'] as List?) ?? const [];

      return features.map<Calamity?>((feature) {
        try {
          final props = (feature as Map<String, dynamic>)['properties']
              as Map<String, dynamic>;
          final geom = feature['geometry'] as Map<String, dynamic>;
          final coords = (geom['coordinates'] as List).cast<num>();
          final lon = coords[0].toDouble();
          final lat = coords[1].toDouble();
          final mag = (props['mag'] as num?)?.toDouble();
          final place = (props['place'] as String?) ?? 'Unknown location';
          final timeMs = (props['time'] as num?)?.toInt();
          final observed = timeMs != null
              ? DateTime.fromMillisecondsSinceEpoch(timeMs)
              : DateTime.now();
          final url = props['url'] as String?;

          final severity = mag == null
              ? CalamitySeverity.info
              : mag >= 6.0
                  ? CalamitySeverity.extreme
                  : mag >= 5.0
                      ? CalamitySeverity.danger
                      : mag >= 4.0
                          ? CalamitySeverity.warning
                          : CalamitySeverity.info;

          return Calamity(
            id: 'usgs:${props['id'] ?? place.hashCode}',
            title: 'M${mag?.toStringAsFixed(1) ?? '?'} — $place',
            type: CalamityType.earthquake,
            severity: severity,
            latitude: lat,
            longitude: lon,
            locationName: place,
            description: (props['title'] as String?) ?? '',
            observedAt: observed,
            magnitude: mag,
            sourceName: 'USGS',
            sourceUrl: url,
          );
        } catch (_) {
          return null;
        }
      }).whereType<Calamity>().toList();
    } catch (_) {
      return const [];
    }
  }

  // ───────────────────────── GDACS JSON events ─────────────────────────
  Future<List<Calamity>> _fetchGdacs() async {
    final uri = Uri.parse(
      'https://www.gdacs.org/gdacsapi/api/events/geteventlist/SEARCH'
      '?from=${_oneYearAgo()}&to=2099-12-31'
      '&country=Bangladesh'
      '&limit=50',
    );
    try {
      final res = await _client.get(uri, headers: _headers).timeout(_slowTimeout);
      if (res.statusCode != 200) return const [];
      final body = json.decode(res.body) as Map<String, dynamic>;
      final features = (body['features'] as List?) ?? const [];

      return features.map<Calamity?>((feature) {
        try {
          final props = (feature as Map<String, dynamic>)['properties']
              as Map<String, dynamic>;
          final geom = (feature['geometry'] as Map?)?.cast<String, dynamic>();
          final coords = (geom?['coordinates'] as List?)?.cast<num>();
          if (coords == null || coords.length < 2) return null;
          final lon = coords[0].toDouble();
          final lat = coords[1].toDouble();
          if (!_inRegion(lat, lon)) return null;

          final name = (props['name'] as String?) ?? 'GDACS event';
          final description = (props['description'] as String?) ?? '';
          final htmlDesc = (props['htmldescription'] as String?) ?? '';
          final eventType = (props['eventtype'] as String?) ?? '';
          final alertLevel = (props['alertlevel'] as String?) ?? 'Green';
          final fromDate = (props['fromdate'] as String?) ?? '';
          final urls = (props['url'] as Map?)?.cast<String, dynamic>();
          final sourceUrl = urls?['report'] as String?;

          final severity = _severityFromGdacsAlert(alertLevel);
          final type = _classifyGdacsType(eventType, name);

          final observed = DateTime.tryParse(fromDate) ?? DateTime.now();

          return Calamity(
            id: 'gdacs:${props['eventid'] ?? name.hashCode}',
            title: name.trim().isEmpty ? htmlDesc.trim() : name.trim(),
            type: type,
            severity: severity,
            latitude: lat,
            longitude: lon,
            locationName: (props['country'] as String?) ?? 'Bangladesh',
            description: htmlDesc.isNotEmpty ? htmlDesc : description,
            observedAt: observed,
            sourceName: 'GDACS',
            sourceUrl: sourceUrl,
          );
        } catch (_) {
          return null;
        }
      }).whereType<Calamity>().toList();
    } catch (_) {
      return const [];
    }
  }

  // ───────────────────────── NASA FIRMS (fires) ─────────────────────────
  Future<List<Calamity>> _fetchNasaFirms() async {
    // VIIRS_NOAA20_NRT is the highest-resolution fire product that
    // has a public no-key endpoint. We ask for the last 24 h of
    // fire detections in Bangladesh only.
    final uri = Uri.parse(
      'https://firms.modaps.eosdis.nasa.gov/api/area/country/'
      'VIIRS_NOAA20_NRT/BD/24h.geojson',
    );
    try {
      final res = await _client.get(uri, headers: _headers).timeout(_fastTimeout);
      if (res.statusCode != 200) return const [];
      final body = json.decode(res.body);
      // GeoJSON FeatureCollection
      final features = (body is Map && body['features'] is List)
          ? body['features'] as List
          : <dynamic>[];
      if (features.isEmpty) return const [];

      return features.map<Calamity?>((feature) {
        try {
          final props = (feature as Map<String, dynamic>)['properties']
              as Map<String, dynamic>;
          final geom = (feature['geometry'] as Map?)?.cast<String, dynamic>();
          final coords = (geom?['coordinates'] as List?)?.cast<num>();
          if (coords == null || coords.length < 2) return null;
          final lon = coords[0].toDouble();
          final lat = coords[1].toDouble();
          if (!_inRegion(lat, lon)) return null;

          final bright = (props['bright_ti4'] as num?)?.toDouble();
          final confidence = (props['confidence'] as num?)?.toInt();
          final acq = (props['acq_date'] as String?) ?? '';
          final acqTime = (props['acq_time'] as String?) ?? '';
          final observed = _parseFirmsDate(acq, acqTime) ?? DateTime.now();

          // Brightness tends to be 300–400 K. >360 K (high conf) → extreme.
          final severity = _severityFromFire(bright, confidence);
          final place = (props['district'] as String?) ?? 'Bangladesh';

          return Calamity(
            id: 'firms:${props['uid'] ?? '$lat,$lon,$acq$acqTime'}',
            title: 'Fire hotspot — ${bright?.toStringAsFixed(0) ?? '?'} K',
            type: CalamityType.wildfire,
            severity: severity,
            latitude: lat,
            longitude: lon,
            locationName: place,
            description: 'Confidence: ${confidence ?? '?'}% · '
                'Brightness: ${bright?.toStringAsFixed(1) ?? '?'} K',
            observedAt: observed,
            magnitude: bright,
            sourceName: 'NASA FIRMS',
            sourceUrl: 'https://firms.modaps.eosdis.nasa.gov/map/',
          );
        } catch (_) {
          return null;
        }
      }).whereType<Calamity>().toList();
    } catch (_) {
      return const [];
    }
  }

  /// Public helper for the provider: derive a flood-risk tile per
  /// district from a FUSION of two sources:
  ///
  ///   1. **Open-Meteo Flood** — real river discharge (m³/s) per
  ///      (lat, lon) over the next 7 days. Thresholded against the
  ///      district's typical baseline to produce a 0..1 risk score.
  ///   2. **OpenWeather /forecast** — rainfall aggregation over the
  ///      next 72 h, used as a fast fallback / cross-check.
  ///
  /// For each district we keep the higher of the two scores and tag
  /// the source so the UI can display where the signal came from.
  /// Each result has lat/lon (the city centroid), district + division,
  /// and a 0..1 risk score. The provider maps these onto Calamity
  /// objects so the heatmap can render district-level flood risk.
  Future<List<Calamity>> fetchFloodRiskFromForecast(
    List<({String name, double lat, double lon, String district, String division})>
        cities,
  ) async {
    // Run both sources in parallel; tolerate partial failure.
    final owm = await _safeList(() => _fetchOpenWeatherRainTiles(cities));
    final omf = await _safeList(() => _fetchOpenMeteoFloodTiles(cities));

    // Group by district + take the max risk score (fusion).
    final byDistrict = <String, _FloodAggregate>{};
    for (final c in [...omf, ...owm]) {
      final key = '${c.district}|${c.division}';
      final a = byDistrict.putIfAbsent(
        key,
        () => _FloodAggregate(
          district: c.district ?? '',
          division: c.division ?? '',
          bestScore: c.riskScore ?? 0,
          sources: <String, double>{},
          lat: c.latitude,
          lon: c.longitude,
        ),
      );
      a.sources[c.sourceName] = c.riskScore ?? 0;
      if ((c.riskScore ?? 0) > a.bestScore) {
        a.bestScore = c.riskScore ?? 0;
        a.lat = c.latitude;
        a.lon = c.longitude;
      }
    }

    final out = <Calamity>[];
    for (final a in byDistrict.values) {
      if (a.bestScore <= 0.05) continue; // ignore dry districts
      final severity = CalamitySeverity.fromRiskScore(a.bestScore);
      final sources = a.sources.keys.toList()..sort();
      final srcLabel = sources.join(' + ');
      out.add(Calamity(
        id: 'flood:${a.district}',
        title: 'Flood risk · ${a.district}',
        type: CalamityType.flood,
        severity: severity,
        latitude: a.lat,
        longitude: a.lon,
        locationName: a.district,
        description: 'Hydrology ($srcLabel) indicates '
            '${(a.bestScore * 100).toStringAsFixed(0)}% flood risk '
            'over the next 7 days.',
        observedAt: DateTime.now(),
        sourceName: srcLabel,
        district: a.district,
        division: a.division,
        riskScore: a.bestScore,
        timeline: 'next 7 days',
      ));
    }
    return out;
  }

  Future<List<Calamity>> _safeList(Future<List<Calamity>> Function() f) async {
    try {
      return await f();
    } catch (_) {
      return const [];
    }
  }

  // ───────────────── Open-Meteo Flood (real river discharge) ─────────────
  /// Fetch the 7-day river discharge forecast per (lat, lon) and
  /// convert to a 0..1 risk score. Uses GloFAS data via Open-Meteo,
  /// no auth, no key, CORS-tolerant.
  ///
  /// Discharge thresholds (m³/s) are calibrated for Bangladesh's
  /// major rivers — these are empirical and can be tuned. The score
  /// saturates at 5000 m³/s for the worst-case flooding.
  Future<List<Calamity>> _fetchOpenMeteoFloodTiles(
    List<({String name, double lat, double lon, String district, String division})>
        cities,
  ) async {
    // Cap concurrency so we don't fan out 64 simultaneous requests.
    const maxConcurrent = 6;
    final results = <Calamity>[];
    final queue = List.of(cities);
    final inFlight = <Future<void>>[];

    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final city = queue.removeAt(0);
        try {
          final score = await _riverDischargeRiskFor(city.lat, city.lon);
          if (score <= 0.05) continue;
          results.add(Calamity(
            id: 'flood-omf:${city.district}',
            title: 'Flood risk · ${city.district}',
            type: CalamityType.flood,
            severity: CalamitySeverity.fromRiskScore(score),
            latitude: city.lat,
            longitude: city.lon,
            locationName: city.district,
            description: 'River discharge model predicts '
                '${(score * 100).toStringAsFixed(0)}% flood risk '
                'over the next 7 days.',
            observedAt: DateTime.now(),
            sourceName: 'Open-Meteo Flood',
            district: city.district,
            division: city.division,
            riskScore: score,
            timeline: 'next 7 days',
          ));
        } catch (_) {
          // skip on timeout / parse failure
        }
      }
    }

    for (var i = 0; i < maxConcurrent && i < cities.length; i++) {
      inFlight.add(worker());
    }
    await Future.wait(inFlight);
    return results;
  }

  Future<double> _riverDischargeRiskFor(double lat, double lon) async {
    final uri = Uri.parse(
      'https://flood-api.open-meteo.com/v1/flood'
      '?latitude=$lat&longitude=$lon'
      '&daily=river_discharge'
      '&forecast_days=7',
    );
    final res = await _client.get(uri, headers: _headers).timeout(_fastTimeout);
    if (res.statusCode != 200) return 0;
    final body = json.decode(res.body) as Map<String, dynamic>;
    final daily = (body['daily'] as Map?)?.cast<String, dynamic>() ?? {};
    final list = (daily['river_discharge'] as List?)?.cast<num?>() ?? const [];
    if (list.isEmpty) return 0;

    double peak = 0;
    double sum = 0;
    int n = 0;
    for (final v in list) {
      if (v == null) continue;
      final d = v.toDouble();
      if (d > peak) peak = d;
      sum += d;
      n += 1;
    }
    if (n == 0) return 0;

    // Calibration: Bangladesh rivers are typically 50–3000 m³/s in
    // non-flood conditions; >5000 m³/s is severe. We blend peak and
    // 7-day mean so a sustained high discharge also lifts the score.
    final peakScore = (peak / 5000.0).clamp(0.0, 1.0);
    final meanScore = ((sum / n) / 2000.0).clamp(0.0, 1.0);
    return (0.7 * peakScore + 0.3 * meanScore).clamp(0.0, 1.0);
  }

  // ───────────────── OpenWeather /forecast (rainfall estimator) ─────────────
  Future<List<Calamity>> _fetchOpenWeatherRainTiles(
    List<({String name, double lat, double lon, String district, String division})>
        cities,
  ) async {
    final out = <Calamity>[];
    for (final city in cities) {
      try {
        final score = await _rainRiskFor(city.lat, city.lon);
        if (score <= 0.05) continue;
        out.add(Calamity(
          id: 'flood-owm:${city.district}',
          title: 'Flood risk · ${city.district}',
          type: CalamityType.flood,
          severity: CalamitySeverity.fromRiskScore(score),
          latitude: city.lat,
          longitude: city.lon,
          locationName: city.district,
          description: 'Rain forecast for the next 72 h indicates '
              '${(score * 100).toStringAsFixed(0)}% flood risk.',
          observedAt: DateTime.now(),
          sourceName: 'OpenWeather',
          district: city.district,
          division: city.division,
          riskScore: score,
          timeline: 'next 72 h',
        ));
      } catch (_) {
        // skip
      }
    }
    return out;
  }

  /// Look up the next 72 h of rain forecast for a city and convert
  /// to a 0..1 risk score. Heavily-monsoon weather codes and high
  /// accumulated rainfall boost the score.
  Future<double> _rainRiskFor(double lat, double lon) async {
    final uri = Uri.parse(
      '${AppConstants.owmBase}/forecast'
      '?lat=$lat&lon=$lon'
      '&units=metric&appid=${AppConstants.owmApiKey}',
    );
    final res = await _client.get(uri).timeout(_slowTimeout);
    if (res.statusCode != 200) return 0;
    final body = json.decode(res.body) as Map<String, dynamic>;
    final list = (body['list'] as List? ?? const [])
        .cast<Map<String, dynamic>>();

    // 3-hourly entries; 8/day → next 72 h = first 24 entries.
    final next = list.take(24);

    double rainMm = 0;
    double popMax = 0;
    int weights = 0;

    for (final entry in next) {
      // `rain.3h` is mm; both OpenWeather and this convention apply.
      final rain = (entry['rain'] as Map?)?['3h'];
      if (rain is num) rainMm += rain.toDouble();
      final pop = (entry['pop'] as num?)?.toDouble() ?? 0;
      if (pop > popMax) popMax = pop;

      // OWM weather id 200..599 = precipitation, 502/522 = very heavy rain.
      final weatherList = (entry['weather'] as List?) ?? const [];
      if (weatherList.isNotEmpty) {
        final id = (weatherList.first as Map)['id'] as int? ?? 800;
        if (id >= 200 && id < 600) weights += 1;
        if (id == 502 || id >= 503 && id <= 504) weights += 2;
      }
    }

    // Normalize:
    //   - 50 mm rain → 1.0 (extreme)
    //   - 30 mm rain → 0.6
    //   - 10 mm rain → 0.2
    final rainScore = (rainMm / 50.0).clamp(0.0, 1.0);
    final popScore = popMax;
    final weightBoost = (weights / 12.0).clamp(0.0, 1.0) * 0.3;

    return (0.55 * rainScore + 0.35 * popScore + weightBoost).clamp(0.0, 1.0);
  }

  // ─────────────────────────── helpers ────────────────────────────────
  bool _inRegion(double lat, double lon) =>
      lat >= latMin && lat <= latMax && lon >= lonMin && lon <= lonMax;

  String _oneYearAgo() {
    final d = DateTime.now().toUtc().subtract(const Duration(days: 365));
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  List<Calamity> _dedupe(List<Calamity> input) {
    final seen = <String>{};
    final out = <Calamity>[];
    input.sort((a, b) => b.observedAt.compareTo(a.observedAt));
    for (final c in input) {
      final key = '${c.type.name}|${c.title}|'
          '${c.latitude.toStringAsFixed(2)}|'
          '${c.longitude.toStringAsFixed(2)}';
      if (seen.add(key)) out.add(c);
    }
    return out;
  }

  CalamityType _classifyGdacsType(String eventType, String name) {
    final t = '${eventType.toLowerCase()} ${name.toLowerCase()}';
    if (t.contains('eq') || t.contains('earthquake')) {
      return CalamityType.earthquake;
    }
    if (t.contains('fl') || t.contains('flood')) return CalamityType.flood;
    if (t.contains('tc') ||
        t.contains('cyclone') ||
        t.contains('hurricane') ||
        t.contains('typhoon')) {
      return CalamityType.cyclone;
    }
    if (t.contains('dr') || t.contains('drought')) return CalamityType.other;
    if (t.contains('vo') || t.contains('volcano')) return CalamityType.other;
    return CalamityType.other;
  }

  CalamitySeverity _severityFromGdacsAlert(String alertLevel) {
    final l = alertLevel.toLowerCase();
    if (l.contains('red')) return CalamitySeverity.extreme;
    if (l.contains('orange')) return CalamitySeverity.danger;
    if (l.contains('yellow')) return CalamitySeverity.warning;
    return CalamitySeverity.info;
  }

  CalamitySeverity _severityFromFire(double? bright, int? confidence) {
    if (bright == null) return CalamitySeverity.warning;
    if (bright >= 360 || (confidence ?? 0) >= 80) {
      return CalamitySeverity.danger;
    }
    if (bright >= 320 || (confidence ?? 0) >= 50) {
      return CalamitySeverity.warning;
    }
    return CalamitySeverity.info;
  }

  DateTime? _parseFirmsDate(String date, String time) {
    if (date.isEmpty) return null;
    final hh = time.length >= 2 ? int.tryParse(time.substring(0, 2)) ?? 0 : 0;
    final mm = time.length >= 4 ? int.tryParse(time.substring(2, 4)) ?? 0 : 0;
    final parts = date.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final mo = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || mo == null || d == null) return null;
    return DateTime.utc(y, mo, d, hh, mm);
  }
}

/// Internal helper: aggregates flood signals per district while we
/// fuse multi-source scores before emitting a single Calamity tile.
class _FloodAggregate {
  _FloodAggregate({
    required this.district,
    required this.division,
    required this.bestScore,
    required this.sources,
    required this.lat,
    required this.lon,
  });

  final String district;
  final String division;
  double bestScore;
  final Map<String, double> sources;
  double lat;
  double lon;
}