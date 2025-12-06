plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.coffea_suite"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.coffea_suite"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 21
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("release") {
            // ✅ Kotlin syntax for signing config
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // ✅ Auto-Rename APK Logic (Kotlin DSL)
    applicationVariants.all {
        val variant = this
        variant.outputs
            .map { it as com.android.build.gradle.internal.api.BaseVariantOutputImpl }
            .forEach { output ->
                val appName = "CoffeaSuite"
                val versionName = variant.versionName
                val versionCode = variant.versionCode

                // Check if it is a pre-release (starts with 0.)
                val isBeta = versionName.startsWith("0.")
                val tag = if (isBeta) "-BETA" else ""
                
                // Construct the new name
                // Result: CoffeaSuite_v0.3.0-BETA_build9.apk
                val newName = "${appName}_v${versionName}${tag}_build${versionCode}.apk"
                
                output.outputFileName = newName
            }
    }
}

flutter {
    source = "../.."
}
