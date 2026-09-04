// lib/providers/calamity_provider.dart
//
// State container for the CalamityScreen.
//
// Responsibilities:
//   * On first load, fetch live natural-calamity events from the three
//     verified open APIs (USGS, GDACS, NASA FIRMS) via CalamityService.
//   * Match each event's (lat, lon) to its Bangladesh district + division
//     using the bundled GeoJSON loader.
//   * In parallel, score the next 72 h of rainfall at each major BD city
//     and emit a per-district flood-risk tile.
//   * Surface a single, deduped stream to the UI with filter chips.
import 'package:flutter/foundation.dart';
import '../data/bangladesh_cities.dart';
import '../data/bd_districts.dart';
import '../models/calamity_model.dart';
import '../services/calamity_service.dart';

enum CalamityStatus { idle, loading, ready, error }

class CalamityProvider extends ChangeNotifier {
  CalamityProvider({CalamityService? service})
      : _service = service ?? CalamityService();

  final CalamityService _service;

  CalamityStatus _status = CalamityStatus.idle;
  CalamityStatus get status => _status;

  List<Calamity> _all = [];
  List<Calamity> get all => List.unmodifiable(_all);

  CalamityType? _filter;
  CalamityType? get filter => _filter;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  DateTime? _lastUpdated;
  DateTime? get lastUpdated => _lastUpdated;

  int get count => _all.length;
  int get countFlood =>
      _all.where((c) => c.type == CalamityType.flood).length;
  int get countCyclone =>
      _all.where((c) => c.type == CalamityType.cyclone).length;
  int get countEarthquake =>
      _all.where((c) => c.type == CalamityType.earthquake).length;

  /// Filtered list shown by the screen.
  List<Calamity> get visible {
    if (_filter == null) return all;
    return all.where((c) => c.type == _filter).toList(growable: false);
  }

  /// Count by severity (handy for the legend).
  int countBySeverity(CalamitySeverity s) =>
      _all.where((c) => c.severity == s).length;

  /// Highest-risk districts (for the heatmap legend). Returns pairs of
  /// (district name, risk score) sorted desc by score.
  List<({String district, double risk})> get topRiskDistricts {
    final byDistrict = <String, double>{};
    for (final c in _all) {
      if (c.type == CalamityType.flood &&
          c.district != null &&
          c.riskScore != null) {
        final prev = byDistrict[c.district!] ?? 0;
        if (c.riskScore! > prev) {
          byDistrict[c.district!] = c.riskScore!;
        }
      }
    }
    final entries = byDistrict.entries
        .map((e) => (district: e.key, risk: e.value))
        .toList(growable: false);
    entries.sort((a, b) => b.risk.compareTo(a.risk));
    return entries;
  }

  Future<void> load({bool force = false}) async {
    if (_status == CalamityStatus.loading) return;
    if (!force && _status == CalamityStatus.ready && _all.isNotEmpty) return;
    _status = CalamityStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final districts = await BangladeshDistricts.load();

      final rawLive = await _safeFetch(_service.fetchCalamities);
      final rawFlood = await _safeFetch(_fetchFloodRiskTiles);

      final merged = <Calamity>[...rawLive, ...rawFlood];
      _all = _attachDistrict(merged, districts);
      _lastUpdated = DateTime.now();
      _status = CalamityStatus.ready;
    } catch (e) {
      _errorMessage = e.toString();
      _status = CalamityStatus.error;
    }
    notifyListeners();
  }

  Future<void> refresh() => load(force: true);

  void setFilter(CalamityType? type) {
    if (_filter == type) return;
    _filter = type;
    notifyListeners();
  }

  // ─────────────────────────── internal helpers ───────────────────────────

  Future<List<Calamity>> _safeFetch(Future<List<Calamity>> Function() fetch) async {
    try {
      return await fetch();
    } catch (e) {
      _errorMessage = '${_errorMessage ?? ''}\n$e'.trim();
      return const <Calamity>[];
    }
  }

  Future<List<Calamity>> _fetchFloodRiskTiles() async {
    final sample = [...kBangladeshCities]
      ..sort((a, b) => b.population.compareTo(a.population));
    final top = sample.take(12).map((c) {
      return (
        name: c.name,
        lat: c.lat,
        lon: c.lon,
        district: c.district,
        division: c.division,
      );
    }).toList(growable: false);

    return _service.fetchFloodRiskFromForecast(top);
  }

  List<Calamity> _attachDistrict(
    List<Calamity> events,
    List<District> districts,
  ) {
    return events.map((c) {
      if (c.district != null && c.district!.isNotEmpty) return c;
      final match = BangladeshDistricts.findDistrict(
        districts,
        c.latitude,
        c.longitude,
      );
      if (match == null) return c;
      return Calamity(
        id: c.id,
        title: c.title,
        type: c.type,
        severity: c.severity,
        latitude: c.latitude,
        longitude: c.longitude,
        locationName: c.locationName,
        description: c.description,
        observedAt: c.observedAt,
        magnitude: c.magnitude,
        sourceName: c.sourceName,
        sourceUrl: c.sourceUrl,
        district: match.name,
        division: match.division,
        riskScore: c.riskScore,
        timeline: c.timeline,
      );
    }).toList(growable: false);
  }
}