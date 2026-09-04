import '../models/weather_models.dart';

enum AdvisoryLevel { good, caution, warning, danger }

class FarmAdvice {
  final String title;
  final String emoji;
  final AdvisoryLevel level;
  final String summary;
  final String detail;
  final List<String> tips;

  const FarmAdvice({
    required this.title,
    required this.emoji,
    required this.level,
    required this.summary,
    required this.detail,
    required this.tips,
  });
}

/// Bangladesh 4-season agricultural calendar.
enum BdSeason {
  grisma, // Mar–May  hot, nor'wester, Aus pre-sowing
  barsha, // Jun–Sep  monsoon, Aman transplant, flood risk
  sharat, // Oct–Nov  post-monsoon, Aman harvest, Rabi sowing
  sheet,  // Dec–Feb  winter, Boro, Rabi growing
}

class FarmingAdvisory {
  FarmingAdvisory._();

  static BdSeason seasonFor(DateTime date) {
    final m = date.month;
    if (m >= 3 && m <= 5) return BdSeason.grisma;
    if (m >= 6 && m <= 9) return BdSeason.barsha;
    if (m >= 10 && m <= 11) return BdSeason.sharat;
    return BdSeason.sheet;
  }

  static String seasonName(BdSeason s) => switch (s) {
        BdSeason.grisma => 'Grisma (গ্রীষ্ম) — Pre-Monsoon',
        BdSeason.barsha => 'Barsha (বর্ষা) — Monsoon',
        BdSeason.sharat => 'Sharat (শরৎ) — Post-Monsoon',
        BdSeason.sheet  => 'Sheet (শীত) — Winter',
      };

  static List<String> seasonCrops(BdSeason s) => switch (s) {
        BdSeason.grisma => ['Aus Rice (pre-sow)', 'Jute', 'Summer Vegetables', 'Maize'],
        BdSeason.barsha => ['Aman Rice (transplant)', 'Jute Harvest', 'Water Spinach', 'Arum'],
        BdSeason.sharat => ['Aman Rice (harvest)', 'Mustard (sow)', 'Potato (sow)', 'Lentil'],
        BdSeason.sheet  => ['Boro Rice', 'Wheat', 'Mustard', 'Potato', 'Rabi Vegetables'],
      };

  static String seasonKeyActivity(BdSeason s) => switch (s) {
        BdSeason.grisma => 'Prepare seedbeds for Aus and Aman. Watch for nor\'wester (কালবৈশাখী) storms.',
        BdSeason.barsha => 'Transplant Aman seedlings. Monitor flood levels. Drain waterlogged fields.',
        BdSeason.sharat => 'Harvest Aman rice when 80% of grains are golden. Begin Rabi crop sowing.',
        BdSeason.sheet  => 'Irrigate Boro rice; water table is low. Apply fertilizer in cool morning hours.',
      };

  /// Generates all 7 advisories + overall score from a weather bundle.
  static ({List<FarmAdvice> advisories, int score, BdSeason season}) compute(
    CurrentWeather current,
    List<HourlyForecast> hourly,
    List<DailyForecast> daily,
  ) {
    final season = seasonFor(DateTime.now());
    final windKmh = current.windSpeed * 3.6;
    final rain1h = current.rainLastHour ?? 0.0;

    // next-6h max precipitation probability
    final pop6h = hourly.take(2).fold<double>(0, (m, h) => h.pop > m ? h.pop : m);
    // next-24h max pop
    final pop24h = hourly.take(8).fold<double>(0, (m, h) => h.pop > m ? h.pop : m);
    // next-48h max pop
    final pop48h = daily.take(2).fold<double>(0, (m, d) => d.pop > m ? d.pop : m);
    // total expected rain next 3 days
    final rain3d = daily.take(3).fold<double>(0, (s, d) => s + d.rain);
    final hum = current.humidity;
    final temp = current.temperature;
    final code = current.weatherCode;

    final pesticide = _pesticide(windKmh, pop6h, hum, temp, rain1h);
    final sowing    = _sowing(rain1h, hum, temp, pop6h, rain3d, season);
    final irrigation = _irrigation(rain1h, pop24h, temp, hum);
    final harvest   = _harvest(pop48h, hum, windKmh);
    final extreme   = _extreme(temp, code, season, pop24h);
    final pest      = _pest(temp, hum);
    final fertilizer = _fertilizer(windKmh, pop6h, rain3d, hum);

    final advisories = [pesticide, sowing, irrigation, harvest, extreme, pest, fertilizer];

    // Score: weight each level 0–100
    int levelScore(AdvisoryLevel l) => switch (l) {
          AdvisoryLevel.good    => 100,
          AdvisoryLevel.caution => 65,
          AdvisoryLevel.warning => 30,
          AdvisoryLevel.danger  => 0,
        };

    // Weights: extreme weather + pesticide are most critical
    final weights = [20, 15, 15, 15, 20, 10, 5];
    final score = (advisories
              .asMap()
              .entries
              .fold<double>(0, (s, e) => s + levelScore(e.value.level) * weights[e.key]) /
          weights.fold<int>(0, (s, w) => s + w))
        .round()
        .clamp(0, 100);

    return (advisories: advisories, score: score, season: season);
  }

  // ─── Individual advisory methods ──────────────────────────────────────────

  static FarmAdvice _pesticide(
      double windKmh, double pop6h, int hum, double temp, double rain1h) {
    if (rain1h > 2) {
      return const FarmAdvice(
        title: 'Pesticide Spraying',
        emoji: '🧪',
        level: AdvisoryLevel.danger,
        summary: 'Do NOT spray — it is raining now',
        detail: 'Active rainfall will wash off pesticides within minutes, wasting '
            'chemicals and polluting waterways. Wait at least 4 hours after rain stops.',
        tips: [
          'Check forecast: spray only when rain-free for next 6 hours',
          'Inspect crops and mark affected areas now for later treatment',
        ],
      );
    }
    if (windKmh > 15) {
      return FarmAdvice(
        title: 'Pesticide Spraying',
        emoji: '🧪',
        level: AdvisoryLevel.danger,
        summary: 'Do NOT spray — wind too strong (${windKmh.toStringAsFixed(0)} km/h)',
        detail: 'High winds cause pesticide drift onto neighbouring fields, crops, '
            'and waterways. BD DAE recommends spraying below 10 km/h wind speed.',
        tips: [
          'Wait for early morning (5–8 AM) when wind is typically lightest',
          'Use directed low-volume nozzles if urgent treatment is needed',
        ],
      );
    }
    if (pop6h > 0.5) {
      return const FarmAdvice(
        title: 'Pesticide Spraying',
        emoji: '🧪',
        level: AdvisoryLevel.warning,
        summary: 'Avoid spraying — rain likely in 6 hours',
        detail: 'Rain probability is high in the next 6 hours. Pesticides need at '
            'least 4–6 hours of dry weather after application to be effective.',
        tips: [
          'Postpone spraying to a dry window',
          'Use systemic pesticides (e.g., imidacloprid) that absorb quickly if spraying is urgent',
        ],
      );
    }
    if (hum > 85) {
      return const FarmAdvice(
        title: 'Pesticide Spraying',
        emoji: '🧪',
        level: AdvisoryLevel.caution,
        summary: 'Use caution — very high humidity',
        detail: 'Humidity above 85% slows pesticide drying and may reduce effectiveness '
            'of contact pesticides. Systemic options are preferred in these conditions.',
        tips: [
          'Prefer systemic over contact pesticides today',
          'Spray in early morning before humidity peaks',
          'Reduce spray volume slightly to speed up drying',
        ],
      );
    }
    if (temp < 15 || temp > 35) {
      return FarmAdvice(
        title: 'Pesticide Spraying',
        emoji: '🧪',
        level: AdvisoryLevel.caution,
        summary: temp < 15 ? 'Cold reduces pesticide activity' : 'Heat increases drift risk',
        detail: temp < 15
            ? 'Cold temperatures slow down pest activity and pesticide absorption. '
                'Many insecticides are less effective below 15°C.'
            : 'High temperatures increase pesticide evaporation and operator exposure risk.',
        tips: [
          if (temp < 15) 'Consider delaying treatment; pests are less active in cold',
          if (temp > 35) 'Spray during cooler early morning hours (before 8 AM)',
          'Wear full PPE regardless of temperature',
        ],
      );
    }
    return FarmAdvice(
      title: 'Pesticide Spraying',
      emoji: '🧪',
      level: AdvisoryLevel.good,
      summary: 'Good conditions to spray',
      detail: 'Wind is calm (${windKmh.toStringAsFixed(0)} km/h), no rain expected soon, '
          'temperature and humidity are within optimal range as per BD DAE guidelines.',
      tips: [
        'Spray in early morning (5–9 AM) for best results',
        'Wear gloves, mask, and protective clothing',
        'Do not eat, drink, or smoke while spraying',
        'Keep children and animals away from treated areas for 24 hours',
      ],
    );
  }

  static FarmAdvice _sowing(
      double rain1h, int hum, double temp, double pop6h, double rain3d, BdSeason season) {
    final soilMoist = rain1h > 0 || hum > 70; // proxy for soil moisture

    if (season == BdSeason.barsha && pop6h > 0.7) {
      return const FarmAdvice(
        title: 'Seed Sowing',
        emoji: '🌱',
        level: AdvisoryLevel.warning,
        summary: 'Heavy rain risk — delay direct sowing',
        detail: 'High rain probability may waterlog seedbeds and wash away seeds. '
            'During monsoon, transplant seedlings rather than direct sowing where possible.',
        tips: [
          'Prepare raised seedbeds to prevent waterlogging',
          'Use pre-germinated seeds (ankur/বীজতলা method) for faster establishment',
          'Transplant Aman seedlings 25–30 days after germination',
        ],
      );
    }

    if (temp < 12) {
      return const FarmAdvice(
        title: 'Seed Sowing',
        emoji: '🌱',
        level: AdvisoryLevel.warning,
        summary: 'Too cold for germination',
        detail: 'Soil temperature below 12°C significantly slows or prevents rice '
            'and vegetable seed germination. Most BD crops need 15–35°C.',
        tips: [
          'Use polythene mulch to warm seedbeds',
          'Delay sowing by 1–2 weeks if cold spell forecast',
          'For Boro, use nursery beds with polythene cover',
        ],
      );
    }

    if (temp > 40) {
      return const FarmAdvice(
        title: 'Seed Sowing',
        emoji: '🌱',
        level: AdvisoryLevel.danger,
        summary: 'Extreme heat — do not sow today',
        detail: 'Temperatures above 40°C cause thermal stress on germinating seeds '
            'and seedlings, leading to poor germination rates and seedling death.',
        tips: [
          'Sow in the evening so seeds germinate in cooler overnight temperatures',
          'Mulch seedbeds with rice straw to reduce soil temperature',
        ],
      );
    }

    final sowingSeasonAdvice = switch (season) {
      BdSeason.grisma => 'Aus paddy sowing season (April–May). Jute sowing March–April.',
      BdSeason.barsha => 'Aman transplanting season. Direct sowing risky due to heavy rain.',
      BdSeason.sharat => 'Rabi sowing season: mustard, lentil, potato, wheat.',
      BdSeason.sheet  => 'Boro rice transplanting. Sow in nursery beds with irrigation.',
    };

    if (!soilMoist && rain3d < 5) {
      return FarmAdvice(
        title: 'Seed Sowing',
        emoji: '🌱',
        level: AdvisoryLevel.caution,
        summary: 'Dry soil — irrigate before sowing',
        detail: '$sowingSeasonAdvice Soil appears dry with little rain expected. '
            'Adequate moisture is essential for uniform germination.',
        tips: [
          'Irrigate seedbed 12–24 hours before sowing',
          'Sow in the morning after overnight moisture absorption',
        ],
      );
    }

    return FarmAdvice(
      title: 'Seed Sowing',
      emoji: '🌱',
      level: AdvisoryLevel.good,
      summary: 'Good conditions to sow',
      detail: '$sowingSeasonAdvice Temperature and moisture conditions are favourable.',
      tips: [
        'Treat seeds with fungicide before sowing to prevent damping-off',
        'Sow at recommended depth: rice 1–2 cm, vegetables 0.5–1 cm',
        'Maintain row spacing as per crop: rice 20×15 cm, mustard 30×10 cm',
      ],
    );
  }

  static FarmAdvice _irrigation(
      double rain1h, double pop24h, double temp, int hum) {
    if (rain1h > 5) {
      return const FarmAdvice(
        title: 'Irrigation',
        emoji: '💧',
        level: AdvisoryLevel.good,
        summary: 'No irrigation needed — good rainfall',
        detail: 'Current rainfall is providing adequate moisture. '
            'Running irrigation during rain wastes water and may cause waterlogging.',
        tips: [
          'Check field drainage to prevent waterlogging',
          'Resume irrigation schedule only if 3+ dry days follow',
        ],
      );
    }
    if (pop24h > 0.6) {
      return const FarmAdvice(
        title: 'Irrigation',
        emoji: '💧',
        level: AdvisoryLevel.caution,
        summary: 'Hold irrigation — rain expected in 24 hours',
        detail: 'Significant rain is likely within the next 24 hours. '
            'Irrigating now may cause waterlogging when rain arrives.',
        tips: [
          'Monitor forecast; irrigate only if rain does not materialise by tomorrow',
          'Check soil moisture manually before deciding',
        ],
      );
    }
    if (temp > 32 && hum < 55) {
      return const FarmAdvice(
        title: 'Irrigation',
        emoji: '💧',
        level: AdvisoryLevel.warning,
        summary: 'Irrigate now — hot and dry conditions',
        detail: 'High temperature and low humidity cause rapid soil moisture loss '
            'and crop stress. Paddy fields need 5–7 cm standing water.',
        tips: [
          'Irrigate Boro/Aus paddy to maintain 3–5 cm standing water',
          'Irrigate vegetables in the evening to reduce evaporation loss',
          'Check pump fuel/power supply before peak heat',
        ],
      );
    }
    if (temp > 28 && hum < 65) {
      return const FarmAdvice(
        title: 'Irrigation',
        emoji: '💧',
        level: AdvisoryLevel.caution,
        summary: 'Consider irrigating — moderately dry',
        detail: 'Conditions are moderately warm and dry. Check soil and crop '
            'condition. Wilting in the afternoon indicates irrigation is needed.',
        tips: [
          'Irrigate in early morning or evening',
          'Use alternate wetting and drying (AWD) for paddy to save water',
        ],
      );
    }
    return const FarmAdvice(
      title: 'Irrigation',
      emoji: '💧',
      level: AdvisoryLevel.good,
      summary: 'Irrigation conditions are adequate',
      detail: 'Temperature and humidity are within a comfortable range. '
          'Irrigate per crop schedule rather than on an emergency basis.',
      tips: [
        'Follow AWD (Alternate Wetting and Drying) technique for paddy',
        'Irrigate at field capacity — avoid over-irrigation',
      ],
    );
  }

  static FarmAdvice _harvest(double pop48h, int hum, double windKmh) {
    if (pop48h > 0.6) {
      return const FarmAdvice(
        title: 'Harvest Readiness',
        emoji: '🌾',
        level: AdvisoryLevel.danger,
        summary: 'Postpone harvest — heavy rain expected',
        detail: 'Rain in the next 48 hours will increase crop moisture content, '
            'cause grain shattering, and lead to fungal damage in harvested crops.',
        tips: [
          'Cover harvested grain immediately if caught by rain',
          'Delay threshing until a dry window of 2–3 days',
          'Check crop maturity (80% golden grains) and harvest when dry spell arrives',
        ],
      );
    }
    if (hum > 80) {
      return const FarmAdvice(
        title: 'Harvest Readiness',
        emoji: '🌾',
        level: AdvisoryLevel.warning,
        summary: 'High humidity — harvest with caution',
        detail: 'High atmospheric humidity slows grain drying after harvest. '
            'Harvested grain stored at high moisture (>14%) will develop aflatoxin.',
        tips: [
          'Harvest only if absolutely necessary at high maturity',
          'Sun-dry grain immediately after harvest to < 14% moisture',
          'Use elevated bamboo mats (মাচা) for grain drying',
        ],
      );
    }
    if (pop48h < 0.2 && hum < 65 && windKmh > 5) {
      return const FarmAdvice(
        title: 'Harvest Readiness',
        emoji: '🌾',
        level: AdvisoryLevel.good,
        summary: 'Excellent harvesting conditions',
        detail: 'Dry weather with light breeze is ideal — minimal rain risk for '
            '48 hours allows safe harvesting, threshing, and grain drying.',
        tips: [
          'Harvest when 80% of panicles turn golden/straw-coloured',
          'Begin threshing same day as harvest to minimise field loss',
          'Take advantage of dry weather to sun-dry grain on mats',
        ],
      );
    }
    return const FarmAdvice(
      title: 'Harvest Readiness',
      emoji: '🌾',
      level: AdvisoryLevel.caution,
      summary: 'Acceptable harvest conditions',
      detail: 'Conditions are adequate but not ideal. Monitor the 48-hour '
          'forecast closely before committing to a large harvest.',
      tips: [
        'Harvest in stages if unsure — take part of the crop first',
        'Store harvested grain in a dry, ventilated store',
      ],
    );
  }

  static FarmAdvice _extreme(
      double temp, int code, BdSeason season, double pop24h) {
    // Thunderstorm / nor'wester
    if (code >= 200 && code < 300) {
      return FarmAdvice(
        title: 'Extreme Weather',
        emoji: '⚡',
        level: AdvisoryLevel.danger,
        summary: season == BdSeason.grisma
            ? 'Nor\'wester (কালবৈশাখী) — seek shelter immediately'
            : 'Thunderstorm — stay off the field',
        detail: 'Thunderstorms in Bangladesh kill hundreds each year due to '
            'lightning strikes in open paddy fields. Evacuate immediately.',
        tips: [
          'Do NOT shelter under trees or near ponds',
          'Move indoors or under a solid roof',
          'Disconnect electrical equipment in the field',
          'Resume work only 30 minutes after the last thunder',
        ],
      );
    }
    // Heavy/violent rain
    if (code >= 502 && code <= 531) {
      return const FarmAdvice(
        title: 'Extreme Weather',
        emoji: '🌊',
        level: AdvisoryLevel.danger,
        summary: 'Heavy rain / flash flood risk',
        detail: 'Intense rainfall can cause flash flooding and waterlogging '
            'within hours. Low-lying fields in Sylhet, Sunamganj, Netrokona are '
            'especially vulnerable.',
        tips: [
          'Open all drainage channels now',
          'Move harvested grain and machinery to high ground',
          'Raise seedbed height if flooding is anticipated',
        ],
      );
    }
    // Heat wave
    if (temp >= 38) {
      return FarmAdvice(
        title: 'Extreme Weather',
        emoji: '🔥',
        level: AdvisoryLevel.danger,
        summary: 'Heat wave — ${temp.toStringAsFixed(0)}°C is dangerous',
        detail: 'Temperatures at or above 38°C cause heat stress in rice and '
            'vegetables, and serious health risk for farm workers.',
        tips: [
          'Work only before 9 AM and after 4 PM',
          'Drink water frequently — at least 1 litre per hour',
          'Irrigate crops in the early morning to cool root zone',
          'Shade vegetable nurseries with net covering',
        ],
      );
    }
    // Cold wave (Bangladesh-specific: < 10°C is extreme, < 15°C is notable)
    if (temp <= 10) {
      return FarmAdvice(
        title: 'Extreme Weather',
        emoji: '🥶',
        level: AdvisoryLevel.danger,
        summary: 'Cold wave — ${temp.toStringAsFixed(0)}°C, crop damage risk',
        detail: 'Cold wave conditions threaten Boro rice seedlings, potato, and '
            'winter vegetables. Frost is rare in BD but cold injury is common.',
        tips: [
          'Cover Boro nurseries with polythene sheets at night',
          'Apply light irrigation to protect seedlings from cold',
          'Harvest mature vegetables before damage occurs',
        ],
      );
    }
    if (temp <= 15) {
      return FarmAdvice(
        title: 'Extreme Weather',
        emoji: '❄️',
        level: AdvisoryLevel.warning,
        summary: 'Cold conditions — protect seedlings',
        detail: 'Temperature of ${temp.toStringAsFixed(0)}°C may slow crop growth '
            'and damage tender seedlings in Boro nurseries and vegetable beds.',
        tips: [
          'Use polythene mulch on seedbeds',
          'Delay transplanting of Boro seedlings if under 15 days old',
        ],
      );
    }
    return const FarmAdvice(
      title: 'Extreme Weather',
      emoji: '✅',
      level: AdvisoryLevel.good,
      summary: 'No extreme weather alerts',
      detail: 'No heat waves, cold waves, thunderstorms, or heavy rain detected. '
          'Conditions are within normal farming ranges for Bangladesh.',
      tips: [
        'Stay alert to forecasts during Mar–May (nor\'wester season)',
        'Monitor Bangladesh Meteorological Department (bmd.gov.bd) for alerts',
      ],
    );
  }

  static FarmAdvice _pest(double temp, int hum) {
    if (temp >= 22 && temp <= 32 && hum >= 80) {
      return FarmAdvice(
        title: 'Pest & Disease Risk',
        emoji: '🐛',
        level: AdvisoryLevel.danger,
        summary: 'High fungal disease risk — rice blast conditions',
        detail: 'Temperature ${temp.toStringAsFixed(0)}°C + humidity $hum% '
            'are ideal for rice blast (Magnaporthe oryzae) and sheath blight. '
            'These are the most damaging diseases in Bangladesh rice farming.',
        tips: [
          'Scout fields daily for blast lesions (diamond-shaped grey spots)',
          'Apply tricyclazole or isoprothiolane at first sign of infection',
          'Avoid excessive nitrogen fertilizer which increases blast susceptibility',
          'Ensure good field drainage to reduce leaf wetness duration',
        ],
      );
    }
    if (temp >= 25 && temp <= 35 && hum >= 70) {
      return const FarmAdvice(
        title: 'Pest & Disease Risk',
        emoji: '🦗',
        level: AdvisoryLevel.warning,
        summary: 'Elevated BPH and stem borer risk',
        detail: 'Warm humid conditions favour Brown Plant Hopper (BPH) and '
            'Yellow Stem Borer — two key pests of Bangladesh rice.',
        tips: [
          'Scout for BPH hopper burn (circular yellowing patches)',
          'Check for dead hearts (stem borer) in vegetative stage',
          'Use light traps to monitor adult moth population',
          'Apply cartap hydrochloride or chlorpyrifos if economic threshold crossed',
        ],
      );
    }
    if (hum >= 75) {
      return const FarmAdvice(
        title: 'Pest & Disease Risk',
        emoji: '🍄',
        level: AdvisoryLevel.caution,
        summary: 'Moderate fungal disease risk',
        detail: 'Elevated humidity creates conditions for fungal diseases in '
            'vegetables (downy mildew, early blight) and rice.',
        tips: [
          'Inspect under leaves for powdery/downy mildew signs',
          'Ensure adequate plant spacing for air circulation',
          'Apply mancozeb or copper fungicide preventively if past experience warrants',
        ],
      );
    }
    return const FarmAdvice(
      title: 'Pest & Disease Risk',
      emoji: '🌿',
      level: AdvisoryLevel.good,
      summary: 'Low pest and disease risk today',
      detail: 'Current temperature and humidity are not highly favourable for '
          'major Bangladesh crop diseases or insect pest outbreaks.',
      tips: [
        'Continue regular 2–3 day field scouting',
        'Remove crop residues to reduce overwintering pest populations',
        'Maintain field hygiene to suppress disease build-up',
      ],
    );
  }

  static FarmAdvice _fertilizer(
      double windKmh, double pop6h, double rain3d, int hum) {
    if (pop6h > 0.6 || rain3d > 40) {
      return const FarmAdvice(
        title: 'Fertilizer Application',
        emoji: '🌿',
        level: AdvisoryLevel.warning,
        summary: 'Delay — rain will leach fertilizer',
        detail: 'Heavy rain washes nitrogen (urea) and potassium out of the '
            'root zone before crops can absorb it. This wastes input cost and '
            'pollutes waterways.',
        tips: [
          'Wait for a dry window of at least 12 hours',
          'Use slow-release or deep placement (Guti Urea) to reduce leaching',
          'Apply phosphorus (TSP) now — less affected by rain than urea',
        ],
      );
    }
    if (windKmh > 20) {
      return FarmAdvice(
        title: 'Fertilizer Application',
        emoji: '🌿',
        level: AdvisoryLevel.caution,
        summary: 'High wind — broadcast loss risk (${windKmh.toStringAsFixed(0)} km/h)',
        detail: 'Strong winds cause uneven distribution of broadcast fertilizers, '
            'particularly urea granules, reducing efficiency.',
        tips: [
          'Delay broadcast application until wind drops below 15 km/h',
          'Apply in rows near plant base to reduce drift',
        ],
      );
    }
    if (hum < 40) {
      return const FarmAdvice(
        title: 'Fertilizer Application',
        emoji: '🌿',
        level: AdvisoryLevel.caution,
        summary: 'Very dry soil — limited absorption',
        detail: 'Fertilizers need soil moisture to dissolve and reach plant roots. '
            'Very dry conditions reduce fertilizer uptake efficiency.',
        tips: [
          'Apply light irrigation 1–2 hours before fertilizing',
          'Or wait for natural rain to moisten soil',
        ],
      );
    }
    return const FarmAdvice(
      title: 'Fertilizer Application',
      emoji: '🌿',
      level: AdvisoryLevel.good,
      summary: 'Good conditions to apply fertilizer',
      detail: 'Calm wind, adequate moisture, and no imminent heavy rain makes '
          'this a good time to broadcast or side-dress fertilizers.',
      tips: [
        'Apply urea in two splits: at tillering and panicle initiation',
        'Use Guti Urea (briquette) in paddy for 20–30% less urea needed',
        'Apply 2–3 cm below soil surface for deep placement',
        'Wash hands thoroughly after handling fertilizers',
      ],
    );
  }
}
