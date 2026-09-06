plugins {
    id("com.android.application")

    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration

    // The Flutter Gradle Plugin must be applied after the Android
    // and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.office_app"

    compileSdk = 37

    ndkVersion = flutter.ndkVersion

    compileOptions {
        // ----------------------------------------------------
        // Required by flutter_local_notifications
        // ----------------------------------------------------
        isCoreLibraryDesugaringEnabled = true

        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // ----------------------------------------------------
        // Application ID
        // ----------------------------------------------------
        applicationId = "com.example.office_app"

        // ----------------------------------------------------
        // Flutter configuration
        // ----------------------------------------------------
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // ------------------------------------------------
            // Debug signing for now
            // ------------------------------------------------
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}


// ============================================================
// DESUGARING DEPENDENCY
// ============================================================

dependencies {
    coreLibraryDesugaring(
        "com.android.tools:desugar_jdk_libs:2.1.4"
    )
}


// ============================================================
// KOTLIN
// ============================================================

kotlin {
    compilerOptions {
        jvmTarget =
            org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}


// ============================================================
// FLUTTER
// ============================================================

flutter {
    source = "../.."
}