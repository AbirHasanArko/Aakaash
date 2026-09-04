/// Simple city model used in typeahead suggestions.
class City {
  final String name;
  final String district;
  final String division;
  final double lat;
  final double lon;
  final int population;

  const City({
    required this.name,
    required this.district,
    required this.division,
    required this.lat,
    required this.lon,
    this.population = 0,
  });

  String get displayLabel => district == name ? name : '$name, $district';

  String get fullLabel =>
      '$name • $district • $division';

  Map<String, dynamic> toJson() => {
    'name': name,
    'district': district,
    'division': division,
    'lat': lat,
    'lon': lon,
    'population': population,
  };

  factory City.fromJson(Map<String, dynamic> j) => City(
    name: j['name'] as String,
    district: j['district'] as String,
    division: j['division'] as String,
    lat: (j['lat'] as num).toDouble(),
    lon: (j['lon'] as num).toDouble(),
    population: j['population'] as int? ?? 0,
  );
}

/// Current weather snapshot.
class CurrentWeather {
  final String cityName;
  final double temperature; // Celsius
  final double feelsLike;
  final int humidity;
  final double windSpeed; // m/s
  final int pressure; // hPa
  final int visibility; // meters
  final int weatherCode;
  final String weatherMain;
  final String weatherDescription;
  final DateTime sunrise;
  final DateTime sunset;
  final DateTime observedAt;
  final int timezoneOffsetSeconds; // shift from UTC
  final double? rainLastHour; // mm
  final double? snowLastHour; // mm
  final double? uvIndex;

  const CurrentWeather({
    required this.cityName,
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.pressure,
    required this.visibility,
    required this.weatherCode,
    required this.weatherMain,
    required this.weatherDescription,
    required this.sunrise,
    required this.sunset,
    required this.observedAt,
    required this.timezoneOffsetSeconds,
    this.rainLastHour,
    this.snowLastHour,
    this.uvIndex,
  });

  bool get isDaytime {
    final now = observedAt.millisecondsSinceEpoch / 1000;
    final sr = sunrise.millisecondsSinceEpoch / 1000;
    final ss = sunset.millisecondsSinceEpoch / 1000;
    return now >= sr && now <= ss;
  }

  factory CurrentWeather.fromOwm(Map<String, dynamic> j, {double? injectedUvi}) {
    final weatherList = (j['weather'] as List?) ?? const [];
    final w0 = weatherList.isNotEmpty
        ? weatherList.first as Map<String, dynamic>
        : <String, dynamic>{};
    final main = (j['main'] as Map?) ?? const {};
    final wind = (j['wind'] as Map?) ?? const {};
    final rain = (j['rain'] as Map?);
    final snow = (j['snow'] as Map?);

    return CurrentWeather(
      cityName: (j['name'] as String?) ?? 'Unknown',
      temperature: ((main['temp'] ?? 0) as num).toDouble(),
      feelsLike: ((main['feels_like'] ?? 0) as num).toDouble(),
      humidity: ((main['humidity'] ?? 0) as num).toInt(),
      pressure: ((main['pressure'] ?? 0) as num).toInt(),
      visibility: ((j['visibility'] ?? 0) as num).toInt(),
      weatherCode: ((w0['id'] ?? 800) as num).toInt(),
      weatherMain: (w0['main'] as String?) ?? '',
      weatherDescription: (w0['description'] as String?) ?? '',
      windSpeed: ((wind['speed'] ?? 0) as num).toDouble(),
      sunrise: DateTime.fromMillisecondsSinceEpoch(
        ((j['sys']?['sunrise'] ?? 0) as num).toInt() * 1000,
        isUtc: true,
      ),
      sunset: DateTime.fromMillisecondsSinceEpoch(
        ((j['sys']?['sunset'] ?? 0) as num).toInt() * 1000,
        isUtc: true,
      ),
      observedAt: DateTime.fromMillisecondsSinceEpoch(
        ((j['dt'] ?? 0) as num).toInt() * 1000,
        isUtc: true,
      ),
      timezoneOffsetSeconds: ((j['timezone'] ?? 0) as num).toInt(),
      rainLastHour: (rain != null) ? (rain['1h'] as num?)?.toDouble() : null,
      snowLastHour: (snow != null) ? (snow['1h'] as num?)?.toDouble() : null,
      uvIndex: injectedUvi ?? (j['uvi'] as num?)?.toDouble(),
    );
  }
}

/// One daily entry in the 5-day forecast.
class DailyForecast {
  final DateTime date;
  final double tempMin;
  final double tempMax;
  final double tempDay;
  final double tempNight;
  final int weatherCode;
  final String weatherDescription;
  final double pop; // probability of precipitation 0..1
  final double windSpeed;
  final int humidity;
  final double rain; // mm

  const DailyForecast({
    required this.date,
    required this.tempMin,
    required this.tempMax,
    required this.tempDay,
    required this.tempNight,
    required this.weatherCode,
    required this.weatherDescription,
    required this.pop,
    required this.windSpeed,
    required this.humidity,
    required this.rain,
  });

  factory DailyForecast.fromOwm(Map<String, dynamic> j) {
    final weatherList = (j['weather'] as List?) ?? const [];
    final w0 = weatherList.isNotEmpty
        ? weatherList.first as Map<String, dynamic>
        : <String, dynamic>{};
    return DailyForecast(
      date: DateTime.fromMillisecondsSinceEpoch(
        ((j['dt'] ?? 0) as num).toInt() * 1000,
        isUtc: true,
      ),
      tempMin: ((j['temp']?['min'] ?? 0) as num).toDouble(),
      tempMax: ((j['temp']?['max'] ?? 0) as num).toDouble(),
      tempDay: ((j['temp']?['day'] ?? 0) as num).toDouble(),
      tempNight: ((j['temp']?['night'] ?? 0) as num).toDouble(),
      weatherCode: ((w0['id'] ?? 800) as num).toInt(),
      weatherDescription: (w0['description'] as String?) ?? '',
      pop: ((j['pop'] ?? 0) as num).toDouble(),
      windSpeed: ((j['wind_speed'] ?? 0) as num).toDouble(),
      humidity: ((j['humidity'] ?? 0) as num).toInt(),
      rain: ((j['rain'] ?? 0) as num).toDouble(),
    );
  }
}

/// One 3-hourly forecast entry.
class HourlyForecast {
  final DateTime time;
  final double temp;
  final int weatherCode;
  final String weatherDescription;
  final double pop;

  const HourlyForecast({
    required this.time,
    required this.temp,
    required this.weatherCode,
    required this.weatherDescription,
    required this.pop,
  });

  factory HourlyForecast.fromOwm(Map<String, dynamic> j) {
    final weatherList = (j['weather'] as List?) ?? const [];
    final w0 = weatherList.isNotEmpty
        ? weatherList.first as Map<String, dynamic>
        : <String, dynamic>{};
    return HourlyForecast(
      time: DateTime.fromMillisecondsSinceEpoch(
        ((j['dt'] ?? 0) as num).toInt() * 1000,
        isUtc: true,
      ),
      temp: ((j['main']?['temp'] ?? 0) as num).toDouble(),
      weatherCode: ((w0['id'] ?? 800) as num).toInt(),
      weatherDescription: (w0['description'] as String?) ?? '',
      pop: ((j['pop'] ?? 0) as num).toDouble(),
    );
  }
}

/// A single air-quality metric.
class AirPollutant {
  final String code; // pm2_5, pm10, o3, etc.
  final double value; // μg/m³

  const AirPollutant({required this.code, required this.value});
}

class AirQuality {
  final int aqi; // 1..5
  final List<AirPollutant> components;

  const AirQuality({required this.aqi, required this.components});
}
