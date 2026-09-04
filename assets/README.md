# Assets

Optional Lottie animation files for richer weather visuals. Drop JSON files
with these names into this folder:

```
sunny.json    -> clear day
rain.json     -> drizzle / rain
cloudy.json   -> cloudy / overcast
thunder.json  -> thunderstorm
snow.json     -> snow
night.json    -> clear night
```

Free Lottie weather animations can be found at <https://lottiefiles.com>.
Without these files the app falls back to a graceful pulsing emoji glyph
(see `WeatherVisual` in `lib/widgets/weather_icon_helper.dart`).

## Icons

Place square PNG icons in `icons/` if you want to replace the default
emojis. The base resolution is 256×256.

## App icon

Replace the Flutter default app icon at `android/app/src/main/res/mipmap-*`
and `ios/Runner/Assets.xcassets/AppIcon.appiconset/`. For best results use
the `flutter_launcher_icons` package.
