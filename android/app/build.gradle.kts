plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")

    // Firebase plugin
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.facebook_messanger"

    compileSdk = 35

    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17

        // FIX FOR flutter_local_notifications
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.facebook_messanger"

        minSdk = flutter.minSdkVersion
        targetSdk = 35

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {

    // FIX FOR flutter_local_notifications
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Firebase BOM
    implementation(platform("com.google.firebase:firebase-bom:34.11.0"))

    // Firebase services
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-messaging")
}

// FORCE COMPATIBLE ANDROIDX VERSIONS
configurations.all {
    resolutionStrategy {
        force("androidx.core:core-ktx:1.15.0")
        force("androidx.core:core:1.15.0")
        force("androidx.activity:activity-ktx:1.9.3")
        force("androidx.activity:activity:1.9.3")
        force("androidx.browser:browser:1.8.0")
    }
}