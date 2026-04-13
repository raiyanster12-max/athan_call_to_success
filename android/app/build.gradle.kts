plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties

val localProps = Properties().apply {
    val f = rootProject.file("local.properties")
    if (f.exists()) {
        f.inputStream().use { load(it) }
    }
}

val googleMapsApiKey: String = (
    providers.gradleProperty("GOOGLE_MAPS_API_KEY").orNull
        ?: providers.gradleProperty("googleMapsApiKey").orNull
        ?: System.getenv("GOOGLE_MAPS_API_KEY")
        ?: localProps.getProperty("GOOGLE_MAPS_API_KEY")
        ?: localProps.getProperty("googleMapsApiKey")
        ?: ""
).trim()

android {
    namespace = "com.example.athan_call_to_success"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.athan_call_to_success"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // androidx.car.app:app requires at least API 23.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = googleMapsApiKey
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("com.google.android.gms:play-services-cast-framework:21.0.1")
    // Android Auto / Android Automotive OS – Car App Library
    implementation("androidx.car.app:app:1.4.0")
}

gradle.taskGraph.whenReady {
    val buildingRelease = allTasks.any { task ->
        val n = task.name.lowercase()
        (n.contains("assemble") || n.contains("bundle")) && n.contains("release")
    }

    val looksInvalid = googleMapsApiKey.isBlank() ||
        googleMapsApiKey.length < 30 ||
        !googleMapsApiKey.startsWith("AIza")

    if (buildingRelease && looksInvalid) {
        throw GradleException(
            "GOOGLE_MAPS_API_KEY is missing/invalid for release build. " +
                "Expected a real Google key like AIza... (typically ~39 chars). " +
                "Set one of: -PgoogleMapsApiKey=AIza... OR environment GOOGLE_MAPS_API_KEY OR " +
                "local.properties entry GOOGLE_MAPS_API_KEY=AIza...",
        )
    }
}
