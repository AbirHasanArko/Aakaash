import 'package:flutter/foundation.dart';

import 'package:home_widget/home_widget.dart';

import '../data/bangladesh_cities.dart';
import '../models/weather_models.dart';
import '../services/ai_service.dart';
import '../services/openweather_service.dart';

enum WeatherStatus { idle, loading, ready, error }

class WeatherProvider extends ChangeNotifier {
  WeatherProvider(this._service);
  final OpenWeatherService _service;

  WeatherStatus status = WeatherStatus.idle;
  String? errorMessage;

  /// Active city being displayed.
  City? city;

  /// Last fetched bundle (current + hourly + 5-day).
  OneCallBundle? bundle;

  /// Last update timestamp (UTC).
  DateTime? lastUpdated;

  /// True if the data was fetched using the user's GPS coordinates.
  bool usingCurrentLocation = false;

  /// True if the user has an active AppsPro subscription.
  bool isSubscribed = false;

  /// AI-generated weather briefing (null while loading or on error).
  AiBriefing? aiBriefing;
  bool aiBriefingLoading = false;

  Future<void> loadForCity(City c) async {
    status = WeatherStatus.loading;
    errorMessage = null;
    city = c;
    usingCurrentLocation = false;
    notifyListeners();
    try {
      final b = await _service.oneCall(c.lat, c.lon);
      bundle = b;
      status = WeatherStatus.ready;
      lastUpdated = DateTime.now().toUtc();
      notifyListeners();
      _loadAiBriefing();
      _updateHomeWidget();
    } catch (e) {
      status = WeatherStatus.error;
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadForLatLon(double lat, double lon) async {
    status = WeatherStatus.loading;
    errorMessage = null;
    usingCurrentLocation = true;
    // Show a transient placeholder while we detect, so the UI doesn't
    // keep displaying the previously-selected city as if nothing changed.
    city = const City(
      name: 'Detecting location…',
      district: 'GPS',
      division: 'BD',
      lat: 0,
      lon: 0,
    );
    notifyListeners();
    try {
      // Reverse-geocode to fill the city label.
      final geocoded = await _service.reverse(lat, lon);
      if (geocoded.isNotEmpty) {
        city = City(
          name: geocoded.first.name,
          district: geocoded.first.state ?? 'Detected',
          division: geocoded.first.country ?? 'BD',
          lat: lat,
          lon: lon,
        );
      } else {
        // Reverse-geocode came back empty — fall back to the nearest
        // Bangladesh city in the local dataset so the user always sees
        // a real city name (Dhaka, Sylhet, Khulna, etc.) rather than the
        // gps placeholder.
        final nearest = _nearestBangladeshCity(lat, lon);
        city = nearest ??
            City(
              name: 'Current Location',
              district: 'Detected',
              division: 'BD',
              lat: lat,
              lon: lon,
            );
      }
      final b = await _service.oneCall(lat, lon);
      bundle = b;
      status = WeatherStatus.ready;
      lastUpdated = DateTime.now().toUtc();
      notifyListeners();
      _loadAiBriefing();
      _updateHomeWidget();
    } catch (e) {
      // Network/OWM failure — still resolve the city label locally so the
      // header doesn't trap the user on "Detecting location… • GPS • BD".
      final nearest = _nearestBangladeshCity(lat, lon);
      if (nearest != null) {
        city = nearest;
      }
      status = WeatherStatus.error;
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  City? _nearestBangladeshCity(double lat, double lon) {
    double bestKm = double.infinity;
    City? best;
    for (final c in kBangladeshCities) {
      final dLat = (c.lat - lat);
      final dLon = (c.lon - lon);
      final km = dLat * dLat + dLon * dLon; // squared distance — fine for min
      if (km < bestKm) {
        bestKm = km;
        best = c;
      }
    }
    return best;
  }

  Future<void> refresh() async {
    if (city != null) {
      await loadForCity(city!);
    }
  }

  /// Quick search shortcut using the BD dataset.
  Future<void> searchAndLoad(String query) async {
    final results = searchCities(query);
    if (results.isEmpty) {
      // Try OWM geocoding.
      try {
        final geo = await _service.geocode(query);
        if (geo.isEmpty) {
          status = WeatherStatus.error;
          errorMessage = 'No Bangladesh city found for "$query"';
          notifyListeners();
          return;
        }
        final first = geo.first;
        await loadForLatLon(first.lat, first.lon);
      } catch (e) {
        status = WeatherStatus.error;
        errorMessage = e.toString();
        notifyListeners();
      }
      return;
    }
    await loadForCity(results.first);
  }

  /// Called when the subscription state changes. If the user just subscribed
  /// and we already have weather data, we can retroactively load the AI briefing.
  void updateSubscription(bool subscribed) {
    if (isSubscribed == subscribed) return;
    isSubscribed = subscribed;
    if (isSubscribed && bundle != null && aiBriefing == null && !aiBriefingLoading) {
      _loadAiBriefing();
    }
  }

  /// Fire-and-forget AI briefing generation after weather loads.
  Future<void> _loadAiBriefing() async {
    if (bundle == null || !isSubscribed) return;
    aiBriefing = null;
    aiBriefingLoading = true;
    notifyListeners();
    try {
      aiBriefing = await AiService.instance.generateBriefing(
        city!.name,
        bundle!.current,
        bundle!.hourly,
      );
    } catch (_) {
      aiBriefing = null;
    }
    aiBriefingLoading = false;
    notifyListeners();
  }

  /// Sync the current city and weather data to the Android home screen widget.
  Future<void> _updateHomeWidget() async {
    if (city == null || bundle == null) return;
    
    await HomeWidget.saveWidgetData<String>('city', city!.name);
    await HomeWidget.saveWidgetData<String>('desc', bundle!.current.weatherDescription);
    await HomeWidget.saveWidgetData<String>('temp', bundle!.current.temperature.round().toString());
    await HomeWidget.updateWidget(name: 'WeatherWidgetProvider');
  }
}
