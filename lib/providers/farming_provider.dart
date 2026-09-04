import 'package:flutter/foundation.dart';

import '../data/farming_advisory.dart';
import '../providers/weather_provider.dart';

class FarmingProvider extends ChangeNotifier {
  List<FarmAdvice> advisories = const [];
  int overallScore = 0;
  BdSeason season = BdSeason.sheet;
  bool isReady = false;

  void updateFromWeather(WeatherProvider wp) {
    if (wp.status != WeatherStatus.ready || wp.bundle == null) {
      isReady = false;
      notifyListeners();
      return;
    }
    final result = FarmingAdvisory.compute(
      wp.bundle!.current,
      wp.bundle!.hourly,
      wp.bundle!.daily,
    );
    advisories = result.advisories;
    overallScore = result.score;
    season = result.season;
    isReady = true;
    notifyListeners();
  }
}
