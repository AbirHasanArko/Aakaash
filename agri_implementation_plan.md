# Farmer's Corner — Agricultural Advisory for Bangladesh

Add a new **"Farmer's Corner" (কৃষকের কোণ)** screen to Aakaash that transforms existing weather data (temperature, humidity, wind speed, rainfall, weather codes) into actionable farming advice tailored for Bangladesh's agricultural calendar, crops, and climate.

## Background

Bangladesh is primarily an agrarian country (~40% of the labour force). Farmers make daily decisions based on weather — when to sow, when to spray pesticides, when to irrigate, when to harvest. This feature requires **no new API calls** — it consumes the same `OneCallBundle` (current + hourly + daily) already fetched by `WeatherProvider`.

---

## User Review Required

> [!IMPORTANT]
> **No new dependencies required.** The feature is purely a logic + UI layer on top of existing weather data. No new API keys, no new packages.

> [!IMPORTANT]
> **Language:** All advisory text will be in **English** (consistent with the rest of the app). We can add Bangla translations in a future iteration if desired. Would you prefer Bangla from the start?

---

## Open Questions

> [!IMPORTANT]
> **Navigation placement:** The current Home screen uses a popup menu (⋮) with "Natural Calamities" and "About Aakaash". I plan to add "Farmer's Corner" as a **third item** in that same popup menu, with a 🌾 (`Icons.agriculture_rounded`) icon. Alternatively, it could be a **5th segment tab** on the Home screen. Which do you prefer?

> [!NOTE]
> **Scope:** The initial version will be a read-only advisory screen (no user preferences for crop type). A future iteration could let the farmer select their crops and get personalised advice. Is the read-only version acceptable for v1?

---

## Proposed Changes

### Advisory Engine (Pure Dart Logic — No UI)

This is the core "brain" of Farmer's Corner. A stateless utility class that takes weather data and returns structured advisories.

#### [NEW] [farming_advisory.dart](file:///d:/Documents/MyWeather/aakaash/lib/data/farming_advisory.dart)

A `FarmingAdvisory` class containing:

**Data model — `FarmAdvice`:**
```dart
class FarmAdvice {
  final String title;          // e.g. "Pesticide Application"
  final String icon;           // emoji or IconData reference
  final AdvisoryLevel level;   // good / caution / warning / danger
  final String summary;        // one-line verdict
  final String detail;         // 2-3 sentence explanation
  final List<String> tips;     // actionable bullet points
}

enum AdvisoryLevel { good, caution, warning, danger }
```

**Advisory categories (each is a method that returns a `FarmAdvice`):**

| Category | Key Weather Inputs | Bangladesh-Specific Logic |
|---|---|---|
| **🧪 Pesticide Spraying** | Wind speed, rain probability (next 6h), humidity, temperature | Good: wind < 10 km/h, no rain for 6h, temp 20–30°C. Bad: wind > 15 km/h (drift), rain within 4h (washoff), humidity > 85% (poor drying). References BD DAE (Dept. of Agricultural Extension) guidelines. |
| **🌱 Seed Sowing** | Soil moisture proxy (recent rain + humidity), temperature, season (month-based), forecast rain in 3 days | Uses Bangladesh's 6-season agricultural calendar: Aus (Apr–Jul), Aman (Jun–Nov), Boro (Nov–May), Rabi crops (Oct–Mar). Good: adequate recent moisture + warm temp + no heavy rain imminent. |
| **💧 Irrigation Advisory** | Rain last hour, rain forecast next 3 days, temperature, humidity | If no rain in 24h and temp > 32°C and humidity < 60% → "Irrigate now". If rain expected within 24h → "Hold irrigation, rain coming". |
| **🌾 Harvest Readiness** | Rain probability next 48h, humidity, wind speed | Good: dry spell (pop < 20% for 48h), moderate wind for drying. Bad: rain expected → "Postpone harvest, protect stored grain". |
| **⚠️ Extreme Weather Warnings** | Temperature extremes, heavy rain codes (502/503/504), thunderstorm codes (200-232), tropical weather | Heat wave (> 38°C), cold wave (< 10°C in BD context), heavy rain / flash flood risk, thunderstorm / nor'wester (কালবৈশাখী) warnings during Mar–May. |
| **🐛 Pest & Disease Risk** | Temperature + humidity combination | High humidity (>80%) + warm (25-35°C) = high fungal disease risk. Specific BD pests: rice blast (temp 22-28°C + high humidity), stem borer risk, BPH risk markers. |
| **🌿 Fertilizer Application** | Wind speed, rain forecast, soil moisture proxy | Good: calm wind, no rain for 12h, moist soil. Bad: heavy rain expected (leaching), very dry soil (poor absorption). |

**Season detection — Bangladesh agricultural calendar:**
```
Gregorian month → Season:
  Mar–May  : Grisma (গ্রীষ্ম) — hot season, nor'wester risk, Aus pre-sowing
  Jun–Sep  : Barsha (বর্ষা) — monsoon, Aman transplanting, flood risk
  Oct–Nov  : Sharat (শরৎ) — post-monsoon, Aman harvest, Rabi sowing
  Dec–Feb  : Sheet (শীত) — winter, Boro season, Rabi growing
```

**Overall farm score (0–100):** A composite "Farming Conditions" score aggregating all categories, displayed as a prominent gauge at the top of the screen.

---

### Provider

#### [NEW] [farming_provider.dart](file:///d:/Documents/MyWeather/aakaash/lib/providers/farming_provider.dart)

A `ChangeNotifier` that:
- Depends on `WeatherProvider` (via `ChangeNotifierProxyProvider`)
- Recomputes advisories whenever weather data changes
- Exposes: `List<FarmAdvice> advisories`, `int overallScore`, `String currentSeason`, `bool isLoading`

---

### Screen

#### [NEW] [farmers_corner_screen.dart](file:///d:/Documents/MyWeather/aakaash/lib/screens/farmers_corner_screen.dart)

A full-screen page with:

1. **Header** — "🌾 Farmer's Corner" title with city name and current season badge
2. **Overall Score Gauge** — circular gauge (0–100) with color gradient (red → yellow → green), built with `CustomPainter` (no new dependency)
3. **Advisory Cards** — a scrollable list of `GlassCard`s, one per category:
   - Color-coded left border strip (green/amber/orange/red matching `AdvisoryLevel`)
   - Icon + title + level chip
   - Summary text
   - Expandable detail section with tips
4. **Seasonal Crop Info** — a bottom section showing current Bangladesh season, recommended crops, and key activities
5. **Last updated timestamp** — from `WeatherProvider.lastUpdated`

The screen follows the existing app design language: `GlassCard`s, Material 3 color scheme, same typography via `google_fonts`.

---

### Integration Points

#### [MODIFY] [main.dart](file:///d:/Documents/MyWeather/aakaash/lib/main.dart)

- Register `FarmingProvider` as a `ChangeNotifierProxyProvider<WeatherProvider, FarmingProvider>` in the `MultiProvider` tree

#### [MODIFY] [home_screen.dart](file:///d:/Documents/MyWeather/aakaash/lib/screens/home_screen.dart)

- Add `'farmers'` entry in the popup menu (⋮ button) alongside "Natural Calamities" and "About Aakaash"
- Add `onFarmersCorner` callback to `_Header`
- Wire the navigation: `Navigator.push → FarmersCornerScreen`

---

## File Summary

| File | Action | Purpose |
|---|---|---|
| [farming_advisory.dart](file:///d:/Documents/MyWeather/aakaash/lib/data/farming_advisory.dart) | **NEW** | Advisory engine — all weather → farming logic |
| [farming_provider.dart](file:///d:/Documents/MyWeather/aakaash/lib/providers/farming_provider.dart) | **NEW** | State management — bridges WeatherProvider to UI |
| [farmers_corner_screen.dart](file:///d:/Documents/MyWeather/aakaash/lib/screens/farmers_corner_screen.dart) | **NEW** | Full-screen UI with score gauge + advisory cards |
| [main.dart](file:///d:/Documents/MyWeather/aakaash/lib/main.dart) | **MODIFY** | Register FarmingProvider in the provider tree |
| [home_screen.dart](file:///d:/Documents/MyWeather/aakaash/lib/screens/home_screen.dart) | **MODIFY** | Add menu entry + navigation to Farmer's Corner |

---

## Verification Plan

### Automated Tests
```bash
flutter analyze
```
- Ensure zero analysis warnings on new files.

### Manual Verification
- Run the app and navigate to Farmer's Corner from the popup menu
- Verify advisories update when switching cities
- Verify the score gauge renders correctly
- Verify each advisory category shows contextually relevant advice for:
  - A hot, dry day in May (Dhaka) — expect: "Good time for pesticide" + "Irrigate now" + nor'wester warning
  - A rainy monsoon day in July (Sylhet) — expect: "Do NOT spray pesticide" + "Hold irrigation" + flood warning
  - A cool winter day in January (Rajshahi) — expect: Boro season info + cold wave check
