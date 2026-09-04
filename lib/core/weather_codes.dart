/// Utility helper to map OpenWeather weather codes -> our asset/animation name.
class WeatherCodes {
  WeatherCodes._();

  /// Returns true for severe weather that should trigger rain/thunder animations.
  static bool isRainy(int code) {
    if (code < 0) return false; // bdapps internal sentinel
    if (code >= 200 && code < 600) return true; // Thunder + drizzle + rain + snow
    return false;
  }

  static bool isCloudy(int code) =>
      code == 801 || code == 802 || code == 803 || code == 804;

  static bool isClear(int code) => code == 800;

  /// A friendly text label for an OWM weather code.
  static String label(int code) {
    if (code >= 200 && code < 300) return 'Thunderstorm';
    if (code >= 300 && code < 400) return 'Drizzle';
    if (code >= 500 && code < 600) return 'Rain';
    if (code >= 600 && code < 700) return 'Snow';
    if (code >= 700 && code < 800) return 'Mist';
    if (code == 800) return 'Clear';
    if (code == 801) return 'Few Clouds';
    if (code == 802) return 'Scattered Clouds';
    if (code == 803 || code == 804) return 'Overcast';
    return 'Weather';
  }
}
