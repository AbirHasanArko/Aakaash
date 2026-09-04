import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_constants.dart';
import '../models/weather_models.dart';

class WeatherApiException implements Exception {
  final String message;
  WeatherApiException(this.message);
  @override
  String toString() => 'WeatherApiException: $message';
}

/// Wraps the OpenWeather REST API. The free tier supports:
///   - /data/2.5/weather
///   - /data/2.5/forecast  (3-hourly, 5-day)
///   - /data/3.0/onecall   (5-day daily + 8 hourly + minutely + alerts)
class OpenWeatherService {
  OpenWeatherService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<double?> _getUvIndex(double lat, double lon) async {
    try {
      final uri = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=uv_index');
      final res = await _client.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final j = json.decode(res.body);
        return (j['current']?['uv_index'] as num?)?.toDouble();
      }
    } catch (_) {}
    return null;
  }

  /// Current weather by lat/lon.
  Future<CurrentWeather> currentByLatLon(double lat, double lon) async {
    final uri = Uri.parse(
      '${AppConstants.owmBase}/weather'
      '?lat=$lat&lon=$lon'
      '&units=metric&lang=en&appid=${AppConstants.owmApiKey}',
    );
    final j = await _getJson(uri);
    final uvi = await _getUvIndex(lat, lon);
    return CurrentWeather.fromOwm(j, injectedUvi: uvi);
  }

  /// Current weather by city id (preferred for BD cities — OWM accuracy).
  Future<CurrentWeather> currentByCity(String city) async {
    final uri = Uri.parse(
      '${AppConstants.owmBase}/weather'
      '?q=${Uri.encodeComponent(city)},BD'
      '&units=metric&lang=en&appid=${AppConstants.owmApiKey}',
    );
    final j = await _getJson(uri);
    double? uvi;
    if (j['coord'] != null) {
      final lat = (j['coord']['lat'] as num?)?.toDouble();
      final lon = (j['coord']['lon'] as num?)?.toDouble();
      if (lat != null && lon != null) {
        uvi = await _getUvIndex(lat, lon);
      }
    }
    return CurrentWeather.fromOwm(j, injectedUvi: uvi);
  }

  /// 5-day daily forecast (free tier via One Call 3.0).
  /// Returns an empty list if the user's plan does not allow One Call.
  Future<OneCallBundle> oneCall(double lat, double lon) async {
    final uri = Uri.parse(
      '${AppConstants.owmBase}/onecall'
      '?lat=$lat&lon=$lon'
      '&exclude=minutely,alerts'
      '&units=metric&lang=en&appid=${AppConstants.owmApiKey}',
    );
    try {
      final j = await _getJson(uri);
      final dailyList = (j['daily'] as List?) ?? const [];
      final hourlyList = (j['hourly'] as List?) ?? const [];

      return OneCallBundle(
        current: CurrentWeather.fromOwm(
          // OWM One Call returns a "current" object shaped like /weather
          {
            'name': '',
            ...(j['current'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
            'weather': (j['current']?['weather'] as List?) ?? const [],
            'main': j['current']?['main'] ?? j['current'],
            'wind': j['current']?['wind'],
            'rain': j['current']?['rain'],
            'snow': j['current']?['snow'],
            'sys': null,
            'timezone': j['timezone_offset'],
            'dt': j['current']?['dt'],
          },
        ),
        hourly: hourlyList
            .cast<Map<String, dynamic>>()
            .take(24)
            .map(HourlyForecast.fromOwm)
            .toList(growable: false),
        daily: dailyList
            .cast<Map<String, dynamic>>()
            .take(10)
            .map(DailyForecast.fromOwm)
            .toList(growable: false),
      );
    } on WeatherApiException {
      // Fall back to the free 5-day/3-hourly endpoint if One Call is restricted
      // on the user's plan.
      final fallback = await forecastByLatLon(lat, lon);
      return OneCallBundle(
        current: fallback.$1,
        hourly: fallback.$2,
        daily: fallback.$3,
      );
    }
  }

  /// 5-day/3-hourly forecast free fallback.
  Future<(CurrentWeather, List<HourlyForecast>, List<DailyForecast>)>
      forecastByLatLon(double lat, double lon) async {
    final uri = Uri.parse(
      '${AppConstants.owmBase}/forecast'
      '?lat=$lat&lon=$lon'
      '&units=metric&lang=en&appid=${AppConstants.owmApiKey}',
    );
    final j = await _getJson(uri);
    final list = (j['list'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final hourly = list.map(HourlyForecast.fromOwm).toList(growable: false);

    final byDay = <DateTime, List<HourlyForecast>>{};
    for (final h in hourly) {
      final dayKey = DateTime.utc(h.time.year, h.time.month, h.time.day);
      byDay.putIfAbsent(dayKey, () => []).add(h);
    }
    final daily = byDay.entries.take(5).map((entry) {
      final temps = entry.value.map((e) => e.temp).toList();
      return DailyForecast(
        date: entry.key,
        tempMin: temps.reduce((a, b) => a < b ? a : b),
        tempMax: temps.reduce((a, b) => a > b ? a : b),
        tempDay: temps.first,
        tempNight: temps.last,
        weatherCode: entry.value.first.weatherCode,
        weatherDescription: entry.value.first.weatherDescription,
        pop: entry.value.map((e) => e.pop).reduce((a, b) => a > b ? a : b),
        windSpeed: 0,
        humidity: 0,
        rain: 0,
      );
    }).toList(growable: false);

    final current = await currentByLatLon(lat, lon);
    return (current, hourly, daily);
  }

  /// Lookup city with the OWM geocoding endpoint — used when a query
  /// doesn't match any local entry in `kBangladeshCities`.
  Future<List<GeocodingResult>> geocode(String query, {int limit = 5}) async {
    if (query.trim().isEmpty) return const [];
    final uri = Uri.parse(
      '${AppConstants.owmGeoBase}/direct'
      '?q=${Uri.encodeComponent(query)},BD&limit=$limit'
      '&appid=${AppConstants.owmApiKey}',
    );
    final j = await _getJson(uri);
    final list = (j as List).cast<Map<String, dynamic>>();
    return list.map(GeocodingResult.fromOwm).toList(growable: false);
  }

  /// Reverse lookup: lat/lon -> nearest named place (Bangladesh if available).
  Future<List<GeocodingResult>> reverse(double lat, double lon, {int limit = 1}) async {
    final uri = Uri.parse(
      '${AppConstants.owmGeoBase}/reverse'
      '?lat=$lat&lon=$lon&limit=$limit'
      '&appid=${AppConstants.owmApiKey}',
    );
    final j = await _getJson(uri);
    final list = (j as List).cast<Map<String, dynamic>>();
    return list.map(GeocodingResult.fromOwm).toList(growable: false);
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final res = await _client
        .get(uri)
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw WeatherApiException(
          'OpenWeather rejected the request (HTTP ${res.statusCode}). '
          'Verify your API key includes the endpoint you\u2019re calling.');
    }
    if (res.statusCode >= 400) {
      throw WeatherApiException(
          'OpenWeather returned HTTP ${res.statusCode}: ${res.body}');
    }
    final data = json.decode(res.body);
    if (data is Map<String, dynamic>) return data;
    throw WeatherApiException('Unexpected response shape: ${data.runtimeType}');
  }
}

class OneCallBundle {
  final CurrentWeather current;
  final List<HourlyForecast> hourly;
  final List<DailyForecast> daily;
  const OneCallBundle({
    required this.current,
    required this.hourly,
    required this.daily,
  });
}

class GeocodingResult {
  final String name;
  final String? state;
  final String? country;
  final double lat;
  final double lon;
  const GeocodingResult({
    required this.name,
    this.state,
    this.country,
    required this.lat,
    required this.lon,
  });

  factory GeocodingResult.fromOwm(Map<String, dynamic> j) => GeocodingResult(
    name: j['name'] as String? ?? '',
    state: j['state'] as String?,
    country: j['country'] as String?,
    lat: (j['lat'] as num).toDouble(),
    lon: (j['lon'] as num).toDouble(),
  );
}
