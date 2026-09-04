# scripts/write_api_docs.ps1
# Writes the comprehensive API_DOCUMENTATION.md. Run once after pulling docs.

$content = @'
# Aakaash  API Documentation

> **Audience:** developers extending or maintaining the Aakaash Flutter app.
> **Scope:** every public class, method, and provider in `lib/`.
> **Version:** corresponds to release build with earthquake notifications.

This document is organised by the four layers of the app  core constants 
data models  services (HTTP / OS)  providers (state)  UI entry points.
Each entry lists the public surface, behaviour, error modes, and the
SharedPreferences keys (if any) it touches.

---

## Table of Contents

1. [Core constants & theme](#1-core-constants--theme)
   - [`AppConstants`](#appconstants)
   - [`app_theme.dart`](#app_themedart)
   - [`weather_codes.dart`](#weather_codesdart)
2. [Data models](#2-data-models)
   - [`City`](#city-libmodelsweather_modelsdart)
   - [`CurrentWeather`](#currentweather-libmodelsweather_modelsdart)
   - [`DailyForecast`](#dailyforecast-libmodelsweather_modelsdart)
   - [`HourlyForecast`](#hourlyforecast-libmodelsweather_modelsdart)
   - [`AirQuality` & `AirPollutant`](#airquality--airpollutant-libmodelsweather_modelsdart)
   - [`CalamityType` & `CalamitySeverity`](#calamitytype--calamityseverity-libmodelscalamity_modeldart)
   - [`Calamity`](#calamity-libmodelscalamity_modeldart)
3. [Data layer](#3-data-layer)
   - [`bangladesh_cities.dart`](#bangladesh_citiesdart)
   - [`bd_districts.dart`](#bd_districtsdart)
4. [Services](#4-services)
   - [`OpenWeatherService`](#openweatherservice-libservicesopenweather_servicedart)
   - [`CalamityService`](#calamityservice-libservicescalamity_servicedart)
   - [`LocationService`](#locationservice-libserviceslocation_servicedart)
   - [`BdappsService`](#bdappsservice-libservicesbdapps_servicedart)
   - [`NotificationService`](#notificationservice-libservicesnotification_servicedart)
   - [`NotificationWorker`](#notificationworker-libservicesnotification_workerdart)
5. [Providers (state)](#5-providers-state)
   - [`WeatherProvider`](#weatherprovider-libprovidersweather_providerdart)
   - [`CalamityProvider`](#calamityprovider-libproviderscalamity_providerdart)
   - [`SubscriptionProvider`](#subscriptionprovider-libproviderssubscription_providerdart)
   - [`NotificationProvider`](#notificationprovider-libprovidersnotification_providerdart)
   - [`ThemeProvider`](#themeprovider-libproviderstheme_providerdart)
6. [UI entry points](#6-ui-entry-points)
   - [`main.dart`](#maindart)
7. [SharedPreferences key reference](#7-sharedpreferences-key-reference)

---

## 1. Core constants & theme

### `AppConstants`
**File:** `lib/core/app_constants.dart`

Single source for API keys, base URLs, timeouts, and free-tier limits.

| Member | Type | Default | Purpose |
| --- | --- | --- | --- |
| `owmBase` | `String` | `https://api.openweathermap.org/data/2.5` | OpenWeather REST base. |
| `owmGeoBase` | `String` | `https://api.openweathermap.org/geo/1.0` | OpenWeather geocoding base. |
| `owmApiKey` | `String` | (development key) | OpenWeather appid. Override per build. |
| `freeDailyLimit` | `int` | `3` | Searches/day before the BDApps gate trips. |
| `defaultNotificationRadiusKm` | `double` | `300.0` | Default radius for proximity filtering. |
| `kBangladeshCenter` | `(double, double)` | `(23.81, 90.41)` | Dhaka centroid (used as a fallback). |

>  Replace `owmApiKey` for production. Read it from a `--dart-define` if
> you don't want it in source.

### `app_theme.dart`
**File:** `lib/core/app_theme.dart`

- `buildAppTheme({required Brightness brightness})  ThemeData`
- Glassmorphism `ColorScheme` + Material 3 `TextTheme`.
- Two instances are passed to `MaterialApp` (`theme` + `darkTheme`); switching
  is driven by `ThemeProvider`.

### `weather_codes.dart`
**File:** `lib/core/weather_codes.dart`

Helpers that map OpenWeather condition IDs (e.g. `800` = clear, `502` = heavy
rain) to:

- human-readable descriptions,
- `WeatherVisual` icons (Lottie or emoji fallback),
- day/night gradient pairs,
- severity hints.

---

## 2. Data models

### `City`  *(`lib/models/weather_models.dart`)*
```dart
class City {
  final String name;        // e.g. "Sylhet"
  final String district;    // e.g. "Sylhet"
  final String division;    // e.g. "Sylhet"
  final double lat;
  final double lon;
  final int population;     // 0 if unknown
}
```
- `String get displayLabel`  `name` or `"name, district"` if the two differ.
- `String get fullLabel`  `name  district  division`.
- `Map<String,dynamic> toJson()` / `City.fromJson(Map)`.

### `CurrentWeather`  *(`lib/models/weather_models.dart`)*
```dart
class CurrentWeather {
  final String cityName;
  final double temperature;     // Celsius
  final double feelsLike;
  final int humidity;            // %
  final double windSpeed;        // m/s
  final int pressure;            // hPa
  final int visibility;          // meters
  final int weatherCode;         // OWM condition id
  final String weatherMain;
  final String weatherDescription;
  final DateTime sunrise;
  final DateTime sunset;
  final DateTime observedAt;
  final int timezoneOffsetSeconds;
  final double? rainLastHour;    // mm
  final double? snowLastHour;    // mm

  bool get isDaytime;
  factory CurrentWeather.fromOwm(Map<String,dynamic> j);
}
```
`isDaytime` returns `true` when `observedAt` falls between sunrise and sunset
for the city's timezone.

### `DailyForecast`  *(`lib/models/weather_models.dart`)*
```dart
class DailyForecast {
  final DateTime date;
  final double tempMin, tempMax, tempDay, tempNight;
  final int weatherCode;
  final String weatherDescription;
  final double pop;          // 0..1
  final double windSpeed;
  final int humidity;
  final double rain;          // mm
  factory DailyForecast.fromOwm(Map<String,dynamic> j);
}
```

### `HourlyForecast`  *(`lib/models/weather_models.dart`)*
```dart
class HourlyForecast {
  final DateTime time;
  final double temp;
  final int weatherCode;
  final String weatherDescription;
  final double pop;
  factory HourlyForecast.fromOwm(Map<String,dynamic> j);
}
```

### `AirQuality` & `AirPollutant`  *(`lib/models/weather_models.dart`)*
```dart
class AirPollutant { final String code; final double value; }
class AirQuality   { final int aqi; final List<AirPollutant> components; }
```
Currently unused by the UI but kept for the OWM Air Pollution endpoint.

### `CalamityType` & `CalamitySeverity`  *(`lib/models/calamity_model.dart`)*
Enums driving the visual language of the radar.

```dart
enum CalamityType   { flood, cyclone, earthquake, storm, landslide, wildfire, other }
enum CalamitySeverity { info, warning, danger, extreme }
```

Each enum value exposes:
- `String get label`  `"Flood"`, `"Extreme"`, 
- `IconData get icon`  `Icons.waves_rounded`, 
- `Color get accent`  for pins, ribbons, and tinted backgrounds.
- `CalamitySeverity.fromRiskScore(double s)` 
  ` 0.75  extreme`, ` 0.5  danger`, ` 0.25  warning`, else `info`.

### `Calamity`  *(`lib/models/calamity_model.dart`)*
```dart
class Calamity {
  final String id;                  // stable across re-fetches
  final String title;
  final CalamityType type;
  final CalamitySeverity severity;
  final double latitude, longitude;
  final String locationName;
  final String description;
  final DateTime observedAt;
  final double? magnitude;          // M for earthquakes, K for fires, etc.
  final String sourceName;          // "USGS" / "GDACS" / "Open-Meteo Flood + OpenWeather"
  final String? sourceUrl;
  final String? district;
  final String? division;
  final double? riskScore;          // 0..1 for flood-risk tiles
  final String? timeline;           // "next 72 h" / "next 7 days"

  bool get isWithinBangladesh;      // 20.526.5N, 8892.5E
  bool get isActive;                // recency rules per type
  double distanceKmFrom(double lat, double lon);  // haversine
  Map<String,dynamic> toJson();
  factory Calamity.fromJson(Map<String,dynamic> j);
}
```

**`isActive` rules (used by notification gating):**
| Type | Window |
| --- | --- |
| earthquake, wildfire |  24 h |
| cyclone |  48 h |
| flood (forecast) | `riskScore  0.25` |
| flood (live GDACS) |  48 h |
| storm, landslide, other |  48 h |

---

## 3. Data layer

### `bangladesh_cities.dart`
**File:** `lib/data/bangladesh_cities.dart`

- `const List<City> kBangladeshCities`  70+ city records (name, district,
  division, lat/lon, population).
- `List<City> searchCities(String query)`  case-insensitive substring match
  on name / district / division.
- `City? nearestBangladeshCity(double lat, double lon)`  squared-distance
  nearest (sufficient for ranking).

### `bd_districts.dart`
**File:** `lib/data/bd_districts.dart`

- `class District { String name, division; List<Polygon> polygons; }`
- `Future<List<District>> BangladeshDistricts.load()`  loads
  `assets/map/bd_districts.json` once (cached).
- `District? BangladeshDistricts.findDistrict(List<District>, lat, lon)` 
  point-in-polygon lookup for attaching district + division to events that
  arrive without a label.

---

## 4. Services

### `OpenWeatherService`
**File:** `lib/services/openweather_service.dart`

Thin wrapper over the OpenWeather REST API. **Free-tier friendly**: every
endpoint is reachable from the basic OpenWeather plan.

| Method | Endpoint | Returns | Notes |
| --- | --- | --- | --- |
| `currentByLatLon(lat, lon)` | `/weather` | `Future<CurrentWeather>` | |
| `currentByCity(city)` | `/weather?q=` | `Future<CurrentWeather>` | Adds `,BD` for accuracy. |
| `oneCall(lat, lon)` | `/onecall` | `Future<OneCallBundle>` | 5-day + 24-h. **Falls back** to `forecastByLatLon` on `WeatherApiException`. |
| `forecastByLatLon(lat, lon)` | `/forecast` | `Future<(CurrentWeather, List<HourlyForecast>, List<DailyForecast>)>` | 5-day/3-hourly. |
| `geocode(query, {limit})` | `/geo/1.0/direct` | `Future<List<GeocodingResult>>` | Used when local dataset misses. |
| `reverse(lat, lon, {limit})` | `/geo/1.0/reverse` | `Future<List<GeocodingResult>>` | For GPS labels. |

**Error class:** `WeatherApiException` (with `.message`).

**Internal helper:** `_getJson(Uri)`  15 s timeout, throws on 401/403 with a
helpful message ("verify your API key includes the endpoint you're calling").

### `CalamityService`
**File:** `lib/services/calamity_service.dart`

The headline aggregator. **Public surface:**

```dart
Future<List<Calamity>> fetchCalamities();
Future<List<Calamity>> fetchFloodRiskFromForecast(List<City> cities);
```

#### `fetchCalamities()`
1. Calls the three source fetchers in parallel with
   `Future.wait(..., eagerError: false)` so a single source outage never
   blanks the whole radar.
2. Each fetcher maps JSON to `Calamity` with calibrated severity buckets.
3. `_dedupe` removes near-duplicate entries (type + title + 0.01 lat/lon).
4. Returns the merged list, sorted by `observedAt` desc.

##### USGS Earthquakes
```
GET https://earthquake.usgs.gov/fdsnws/event/1/query
    ?format=geojson
    &starttime={1y_ago}
    &minmagnitude=3.5
    &minlatitude=18&maxlatitude=28
    &minlongitude=86&maxlongitude=94
    &orderby=time&limit=200
```
- 20 s timeout.
- Severity: `M  6  extreme`, `M  5  danger`, `M  4  warning`,
  else `info`.

##### GDACS Global Disasters
```
GET https://www.gdacs.org/gdacsapi/api/events/geteventlist/SEARCH
    ?from={1y_ago}&to=2099-12-31
    &country=Bangladesh&limit=50
```
- 20 s timeout.
- `_classifyGdacsType` matches `EQ`  earthquake, `FL`  flood,
  `TC`  cyclone (also hurricane / typhoon keywords), else `other`.
- Severity: GDACS alert level  `red/orange/yellow/green`.

##### NASA FIRMS Wildfires
```
GET https://firms.modaps.eosdis.nasa.gov/api/area/country/
    VIIRS_NOAA20_NRT/BD/24h.geojson
```
- 12 s timeout.
- Severity: brightness  360 K **or** confidence  80%  danger; brightness
   320 K **or** confidence  50%  warning.

#### `fetchFloodRiskFromForecast(List<City> cities)`
1. **Open-Meteo Flood** for each (lat, lon), 6-way concurrent, with the
   per-call risk score computed via `_riverDischargeRiskFor`.
2. **OpenWeather `/forecast`** for the same cities (3-hourly rainfall).
3. Both lists are fused per-district by `_FloodAggregate`, taking the **higher**
   of the two scores and recording both sources.

##### Open-Meteo Flood calibration
```
GET https://flood-api.open-meteo.com/v1/flood
    ?latitude=&longitude=
    &daily=river_discharge&forecast_days=7
```
Score = `0.7  clamp(peak / 5000, 0, 1) + 0.3  clamp(mean / 2000, 0, 1)`.
- `peak` = max 7-day discharge.
- `mean` = 7-day average discharge.
- 12 s timeout.

##### OpenWeather rain risk
```
GET ${owmBase}/forecast
    ?lat=&lon=&units=metric&appid=${owmApiKey}
```
First 24 entries (3-hourly  24 = 72 h):
- `rainScore = clamp(totalRainMm / 50, 0, 1)`
- `popScore = max(pop)`
- `weightBoost = clamp(weights / 12, 0, 1)  0.3`
  (`weights` counts entries with codes 200599 and extra weights for
  `502/503/504` = very heavy rain).
Final = `0.55  rainScore + 0.35  popScore + weightBoost`.

> Districts with `bestScore  0.05` are dropped ("ignore dry districts").

#### Timing
All requests include a `User-Agent: Aakaash/1.0 (https://github.com/AbirHasanArko)`
header so the APIs can rate-limit / contact you if needed.

### `LocationService`
**File:** `lib/services/location_service.dart`

- `Future<Position> getCurrentPosition()`  checks service enabled  asks
  permission  fetches a 20-second-budget fix with
  `forceAndroidLocationManager: true` (bypasses Play Services fused-provider
  caching to avoid stale fixes). Persists the fix.
- `Future<void> persist(double lat, double lon)`  saves the latest fix into
  SharedPreferences for the background worker.
- `Future<LastKnownLocation?> getLastKnown()`  loads the cached fix;
  returns `null` if older than 24 h.
- `Future<City?> nearestBangladeshCity({lat, lon})`  haversine nearest.
- `Future<String> describePosition({lat, lon})`  `placemarkFromCoordinates`
  with a 6-second timeout; falls back to the nearest BD city label.
- `Future<void> openSettings()`  opens the app's settings page so the user
  can grant a denied permission.

**Custom exception:** `LocationServiceException` carries a `permissionDenied`
flag so the UI can choose between snack / deep-link.

### `BdappsService`
**File:** `lib/services/bdapps_service.dart`

Single class that talks to either:
- **`backend: 'appspro'`** (default)  direct calls to
  `https://api.appspro.dev/api/v1/sdk/*` with `Authorization: Bearer `.
- **`backend: 'bdapps'`**  calls your PHP backend via `baseUrl + path`.

| Method | AppsPro URL | Returns |
| --- | --- | --- |
| `checkStatus(phone)` | `POST /status` | `Future<BdappsStatus>` |
| `requestOtp(phone)` | `POST /otp/request` | `Future<OtpRequestResult>` |
| `verifyOtp({phone, referenceNo, otp})` | `POST /otp/verify` | `Future<OtpVerifyResult>` |
| `unsubscribe(phone)` | `POST /unsubscribe` | `Future<BdappsStatus>` |
| `hostedCheckoutUrl(urlSlug, {redirectUrl})` |  | `String` |
| `embedUrl({publishableKey, token, theme, buttonText})` |  | `String` |

**Phone normalisation (`_normalize`):**
- `+8801XXXXXXXXX`  `1XXXXXXXXX` (strip `88` prefix).
- `01XXXXXXXXX`  `1XXXXXXXXX` (strip leading `0`).

**Failure handling (`_post`):**
- 20 s timeout  friendly timeout exception.
- `SocketException`  friendly "couldn't reach BDApps" message.
- HTTP 5xx  friendly retry hint.
- HTTP 404  hint to set `BDAPPS_BASE_URL`.
- HTML response body (Nginx 502, captcha wall)  "returned HTML instead of
  JSON" exception.
- `FormatException` on JSON parse  "returned unreadable response" exception.

**Factory:** `buildDefaultBdappsService()`  reads
`String.fromEnvironment('APPSPRO_SECRET_KEY')` and constructs the service.

### `NotificationService`
**File:** `lib/services/notification_service.dart`

Singleton (`NotificationService.instance`) wrapping `flutter_local_notifications`
+ `workmanager`.

#### Channels
```dart
class NotificationChannels {
  static const String dailyWeather = 'aakaash_daily_weather';
  static const String calamity     = 'aakaash_calamity';
  static const String earthquake   = 'aakaash_earthquake';
}
```

#### Notification IDs
```dart
class NotificationIds {
  static const int dailyWeatherBase = 1001;
  static const int calamityBase     = 2000;
  static const int calamityMax      = 2500;
  static const int earthquakeBase   = 3000;
  static const int earthquakeMax    = 3500;
}
```

#### WorkManager task names
```dart
const String kCalamityTaskName   = 'com.aakaash.aakaash.calamity_check';
const String kEarthquakeTaskName = 'com.aakaash.aakaash.earthquake_check';
```

#### Tap routing
```dart
enum NotificationRoute { home, calamity, earthquake }
class NotificationRoutePayload { final NotificationRoute route; final String? calamityId; }
```
`setTapHandler` registers a callback that receives the payload; the main
shell routes via the global `NavigatorState` key.

#### Daily weather
- `scheduleDailyWeather({TimeOfDay time, title, body, payload})`  uses
  `zonedSchedule(... matchDateTimeComponents: time)`.
- `cancelDailyWeather()`  cancels id `1001`.
- `showDailyTest(title, body)`  `Importance.high`, immediate.

#### Calamity alerts
- `showCalamity(Calamity c)`  `Importance`/`Priority` mapped from severity,
  `color` from `c.severity.color`, `payload: 'calamity:<id>'`.

#### Earthquake alerts
- `showEarthquake(Calamity c)`  `Importance.max`, `playSound: true`,
  `enableVibration: true`,
  `vibrationPattern: Int64List.fromList([0, 250, 200, 250])`,
  `category: AndroidNotificationCategory.alarm`,
  `payload: 'earthquake:<id>'`. iOS sets
  `interruptionLevel: InterruptionLevel.timeSensitive`.

#### Background workers
- `startCalamityWorker()`  6 h period, `requiresBatteryNotLow: true`,
  `ExistingPeriodicWorkPolicy.replace`.
- `stopCalamityWorker()`  `cancelByUniqueName(kCalamityTaskName)`.
- `startEarthquakeWorker()`  15 min period (WorkManager's minimum),
  no battery constraint so quakes alert even on low battery.
- `stopEarthquakeWorker()`  `cancelByUniqueName(kEarthquakeTaskName)`.

#### Lifecycle
- `initialize()`  loads the IANA timezone DB, creates Android channels,
  wires the OS tap callback. Idempotent.
- `areNotificationsEnabled()` / `requestPermission()`  Android 13+
  `POST_NOTIFICATIONS` runtime permission via `permission_handler`.

### `NotificationWorker`
**File:** `lib/services/notification_worker.dart`

Background isolate entry point. Two top-level functions:

```dart
@pragma('vm:entry-point')
void notificationCallbackDispatcher();   // entry point

class AakaashWorkmanagerBridge { static void execute(); }  // dispatcher
```

Plus two private implementations (`_runCalamityCheck`, `_runEarthquakeCheck`)
and two static helpers reused by the foreground UI:

#### `NotificationCalamityFetcher.fetchAndFilter({client, lat, lon, radiusKm})`
- Reads USGS (M3.5+ bbox) + GDACS (last 7 days, BD-tagged).
- 12 s per-request timeout, swallow-on-error.
- Filters to events with `isActive == true` AND
  `distanceKmFrom(lat, lon)  radiusKm`.
- Returns the deduped list.

> The flood-risk tile layer is **not** used here (would require 12
> OpenWeather calls per tick  too expensive for a notification worker).

#### `NotificationEarthquakeFetcher.fetch({client})`
- Queries USGS with `M  3.5`, bbox `19.527.5N`, `8595E` (BD + 1
  border buffer).
- 12 s timeout.
- Filters to `isActive == true` only (24 h window).
- Returns the deduped list.

#### Worker gating
Both workers gate on **all three** of:
- `notif_enabled == true`
- `notif_subscriber_status == 'registered'`
- `notif_calamity_on` / `notif_earthquake_on == true`

If any gate fails, the worker exits silently (no notification, no log spam).

#### Dedup
Last-seen id-sets are persisted as JSON strings:
- `notif_last_calamity_ids`  kept to the 64 most-recent.
- `notif_last_eq_ids`  kept to the 128 most-recent.

---

## 5. Providers (state)

### `WeatherProvider`
**File:** `lib/providers/weather_provider.dart`

Owns the active city + the last `OneCallBundle`.

```dart
enum WeatherStatus { idle, loading, ready, error }

class WeatherProvider extends ChangeNotifier {
  WeatherStatus status;
  String? errorMessage;
  City? city;
  OneCallBundle? bundle;
  DateTime? lastUpdated;
  bool usingCurrentLocation;

  Future<void> loadForCity(City c);
  Future<void> loadForLatLon(double lat, double lon);
  Future<void> refresh();
  Future<void> searchAndLoad(String query);
}
```

- `loadForLatLon` first reverse-geocodes via `OpenWeatherService.reverse`;
  on empty response it falls back to the nearest local city. If OWM fails,
  it still resolves a local label so the header never shows
  "Detecting location".
- `searchAndLoad` runs the local `searchCities(query)` first; on miss it
  tries OWM geocoding.

### `CalamityProvider`
**File:** `lib/providers/calamity_provider.dart`

State container for the CalamityScreen.

```dart
enum CalamityStatus { idle, loading, ready, error }

class CalamityProvider extends ChangeNotifier {
  CalamityStatus status;
  String? errorMessage;
  DateTime? lastUpdated;
  CalamityType? filter;
  List<Calamity> get all;
  List<Calamity> get visible;            // honours filter
  int get count;
  int get countFlood, countCyclone, countEarthquake;
  int countBySeverity(CalamitySeverity s);
  List<({String district, double risk})> get topRiskDistricts;

  Future<void> load({bool force = false});
  Future<void> refresh();
  void setFilter(CalamityType? type);
}
```

- `load` loads district polygons (`BangladeshDistricts.load()`), fetches
  live calamities + flood-risk tiles in parallel, attaches
  district + division via point-in-polygon.
- `topRiskDistricts` aggregates max risk per district for the heatmap
  legend (sorted desc by score).

### `SubscriptionProvider`
**File:** `lib/providers/subscription_provider.dart`

Owns the BDApps subscription state + free-tier daily counter.

```dart
enum SubscriptionStatus { unknown, unregistered, pending, registered, error }

class SubscriptionProvider extends ChangeNotifier {
  SubscriptionStatus status;
  String? phone;
  String? lastError;
  String? subscriberId;
  String? lastOtpReference;
  int freeSearchesUsedToday;

  bool get freeQuotaExhausted;
  int  get freeRemaining;
  Future<void> load();
  Future<void> incrementFreeUse();
  Future<bool> requestOtp(String phone);
  Future<bool> verifyOtp(String otp);
  Future<void> refreshStatus();
  Future<bool> unsubscribe();
}
```

- The daily counter is keyed on a YYYY-MM-DD string; if today's string
  differs from the saved one, the count resets to 0.
- Every successful status transition calls `_syncNotif()` which forwards
  to `NotificationProvider.syncWithSubscription(...)`.
- Local-phone normalisation (`_normalizeLocal`) converts
  `+8801XXXXXXXXX`  `01XXXXXXXXX`.

### `NotificationProvider`
**File:** `lib/providers/notification_provider.dart`

The single source of truth for notification preferences. **All** writers to
`notif_*` SharedPreferences keys live here.

```dart
class NotificationSettings {
  bool dailyOn;
  TimeOfDay dailyTime;       // default 07:00
  bool calamityOn;
  double radiusKm;           // clamped 50..500, default 300
  bool earthquakeOn;
}

class NotificationProvider extends ChangeNotifier {
  NotificationSettings get settings;
  bool get permissionGranted;
  DateTime? get lastRun;

  Future<void> load();
  Future<bool> requestPermission();

  Future<void> setDaily(bool on);
  Future<void> setDailyTime(TimeOfDay t);
  Future<void> setCalamity(bool on);
  Future<void> setRadius(double km);
  Future<void> setEarthquake(bool on);

  Future<void> syncWithSubscription(SubscriptionStatus status);
  Future<void> testDaily();
  Future<void> testCalamity();
  Future<void> testEarthquake();
}
```

- `load()` also calls `_refreshPermission()` and `_reconcileScheduling()` so
  the OS-side alarms + workers are correct after a device reboot.
- `setRadius` clamps to `[50, 500]` km.
- `syncWithSubscription(registered)` enables defaults if the user has not
  explicitly disabled each toggle previously.
- `_reconcileScheduling` is the only place that schedules/cancels the
  WorkManager tasks or the daily alarm.

### `ThemeProvider`
**File:** `lib/providers/theme_provider.dart`

```dart
class ThemeProvider extends ChangeNotifier {
  ThemeMode _mode;          // default ThemeMode.system
  ThemeMode get mode;
  IconData get icon;
  String get label;
  Future<void> load();
  Future<void> setMode(ThemeMode mode);
  Future<void> cycle();     // system  light  dark  system
}
```

Persists via the `'aakaash.theme_mode'` key.

---

## 6. UI entry points

### `main.dart`
**File:** `lib/main.dart`

```dart
final GlobalKey<NavigatorState> rootNavigatorKey = ...;
Future<void> main() async { ... }      // bootstraps + runApp
class AakaashApp extends StatefulWidget { ... }
```

**Bootstrap order (in `main`):**
1. `WidgetsFlutterBinding.ensureInitialized()`.
2. Lock to portrait.
3. `themeProvider.load()` (so the first frame is the right brightness).
4. `NotificationService.instance.initialize()` (so the first frame can
   query permission state).
5. `runApp(AakaashApp(themeProvider: ...))`.

**Provider tree** (mounted under `MultiProvider`):
- `ChangeNotifierProvider<ThemeProvider>.value`
- `Provider<OpenWeatherService>`
- `Provider<BdappsService>`  `buildDefaultBdappsService()`
- `ChangeNotifierProvider<NotificationProvider>` (auto-`load()`)
- `ChangeNotifierProxyProvider<NotificationProvider, SubscriptionProvider>`
- `ChangeNotifierProvider<WeatherProvider>`
- `ChangeNotifierProvider<CalamityProvider>`

**Tap routing (`_routeFromNotification`):**
- `NotificationRoute.home`  `popUntil(isFirst)`.
- `NotificationRoute.calamity` / `NotificationRoute.earthquake` 
  `push(MaterialPageRoute(CalamityScreen()))`.

---

## 7. SharedPreferences key reference

| Key | Type | Owner | Description |
| --- | --- | --- | --- |
| `notif_enabled` | bool | `NotificationProvider` | Master "feature on" flag. |
| `notif_daily_on` | bool | `NotificationProvider` | Daily weather alarm on/off. |
| `notif_daily_hour` | int | `NotificationProvider` | Local hour (023). |
| `notif_daily_min` | int | `NotificationProvider` | Local minute (059). |
| `notif_calamity_on` | bool | `NotificationProvider` | Calamity worker on/off. |
| `notif_radius_km` | double | `NotificationProvider` | Proximity radius (50500). |
| `notif_earthquake_on` | bool | `NotificationProvider` | Earthquake sentinel on/off. |
| `notif_subscriber_status` | String | `NotificationProvider` | `'registered'` / other. |
| `notif_last_run_ms` | int | worker | Last successful calamity run timestamp. |
| `notif_last_eq_run_ms` | int | worker | Last successful earthquake run timestamp. |
| `notif_last_calamity_ids` | String (JSON list) | worker | Last-seen event ids (max 64). |
| `notif_last_eq_ids` | String (JSON list) | worker | Last-seen eq ids (max 128). |
| `free_search_count` | int | `SubscriptionProvider` | Free-tier counter. |
| `free_search_date` | String (YYYY-MM-DD) | `SubscriptionProvider` | Date of last reset. |
| `subscribed_phone` | String | `SubscriptionProvider` | Cached local-format phone. |
| `last_known_lat` | double | `LocationService` | Last GPS lat. |
| `last_known_lon` | double | `LocationService` | Last GPS lon. |
| `last_known_at_ms` | int | `LocationService` | Freshness check ( 24 h). |
| `aakaash.theme_mode` | String | `ThemeProvider` | `'system'` / `'light'` / `'dark'`. |

---

## Error & exception classes

| Class | Where | Notes |
| --- | --- | --- |
| `WeatherApiException` | `openweather_service.dart` | `final String message`. |
| `LocationServiceException` | `location_service.dart` | `final String message; final bool permissionDenied`. |
| Generic `Exception(...)` | `bdapps_service.dart` | Friendly one-line messages for transport-level failures (timeout, 404, HTML, JSON parse). |
'@

$target = 'd:\Documents\MyWeather\aakaash\docs\API_DOCUMENTATION.md'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($target, $content, $utf8NoBom)
Write-Host "OK: wrote $target ($($content.Length) chars, ASCII, no BOM)"