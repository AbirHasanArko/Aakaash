plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.aakaash.aakaash"
    // Bump to 36: geolocator_android, sqflite_android, url_launcher_android,
    // shared_preferences_android, jni, jni_flutter, and androidx.browser:1.9.0
    // all require compileSdk >= 36. android-36 is installed on this machine.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications requires core library desugaring.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.aakaash.aakaash"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(flutter.minSdkVersion, 21) // geolocator / permission_handler require >=21
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            // Enable R8 + the keep rules in `proguard-rules.pro`. Without
            // these, WorkManager (loaded via androidx.startup) gets
            // stripped at compile time and the release APK crashes on
            // launch with `NoSuchMethodException: androidx.work.impl
            // .WorkDatabase_Impl.<init>`.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // flutter_local_notifications (and a few other plugins) need the
    // desugar_jdk_libs artifact on the classpath when core library
    // desugaring is enabled. Without this, Gradle fails with:
    //   "coreLibraryDesugaring configuration contains no dependencies."
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
