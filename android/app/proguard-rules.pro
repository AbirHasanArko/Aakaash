# ─────────────────────────────────────────────────────────────────────
#  Aakaash · ProGuard / R8 keep rules
# ─────────────────────────────────────────────────────────────────────
#  These rules supplement `proguard-android-optimize.txt` (which is
#  shipped with the Android Gradle Plugin) so the release APK still
#  works after R8 shrinks and obfuscates the bundled libraries.
#
#  Anything R8 strips that is loaded via reflection, annotations, or
#  JNI at runtime must be kept here.
#
#  Most of these are workmanager + AndroidX Startup keep rules
#  (see https://developer.android.com/topic/libraries/app-startup for
#  context). They are required because the workmanager_android plugin
#  registers WorkManagerInitializer as a ContentProvider via
#  androidx.startup, which reflectively reads WorkDatabase_Impl.
# ─────────────────────────────────────────────────────────────────────

# Print the full mapping table when minify is on so we can debug
# future NoSuchMethodException reports.
-printmapping build/outputs/mapping/release/mapping.txt
-printseeds   build/outputs/mapping/release/seeds.txt

# ──────────────── AndroidX Startup ────────────────
# ContentProvider declared via androidx.startup uses reflection to
# look up its initializer. Keep the provider and its entrypoints.
-keep class androidx.startup.** { *; }
-keep interface androidx.startup.** { *; }
-keep class * implements androidx.startup.Initializer { *; }
-keepclassmembers class * {
    @androidx.startup.InitializationProvider <methods>;
}

# ──────────────── androidx.work (workmanager) ────────────────
# WorkManagerInitializer (registered via androidx.startup) loads
# WorkDatabase_Impl reflectively. R8 pruned its generated Room
# subclass and the app crashed at boot with
#   java.lang.NoSuchMethodException: androidx.work.impl.WorkDatabase_Impl.<init> []
# Keeping the entire implementation package is the only safe fix;
# without it WorkManager is unusable.
-keep class androidx.work.** { *; }
-keep interface androidx.work.** { *; }
-keepclassmembers class androidx.work.** { *; }
-keep enum androidx.work.** { *; }

# Keep WorkManager's Room-generated DAO + database classes verbatim.
-keep class * extends androidx.room.RoomDatabase { *; }
-keep @androidx.room.Database class * { *; }
-keep @androidx.room.Entity class * { *; }
-keep @androidx.room.Dao class * { *; }
-keep @androidx.room.TypeConverter class * { *; }

# ──────────────── flutter_local_notifications ────────────────
# Uses Gson + reflection for scheduled notification payloads.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-keep class com.google.gson.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-dontwarn sun.misc.Unsafe
-dontwarn javax.annotation.**

# ──────────────── flutter_timezone ────────────────
# Re-exports JNI bindings.
-keep class dev.fluttercommunity.plus.timezone.** { *; }

# ──────────────── shared_preferences, geolocator, etc. ────────────────
# Plugin registrant classes are looked up by name in the generated
# `GeneratedPluginRegistrant`. Keep them.
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
-keep class * implements io.flutter.embedding.engine.plugins.FlutterPlugin {
    public <init>(...);
}

# ──────────────── Misc safety nets ────────────────
# Anything annotated as @Keep must survive.
-keep @androidx.annotation.Keep class * { *; }
-keepclassmembers class * {
    @androidx.annotation.Keep <methods>;
    @androidx.annotation.Keep <fields>;
}

# Don't warn about classes referenced only by optional Play Services.
-dontwarn com.google.android.play.core.**
