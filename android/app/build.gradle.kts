plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.zrelxr06.malwirus"
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
        applicationId = "com.zrelxr06.malwirus"
        minSdk = 23 //
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }


    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Talsec Release
    releaseImplementation("com.aheaditec.talsec.security:TalsecSecurity-Community-Flutter:+-release")

    // Talsec Debug
    implementation("com.aheaditec.talsec.security:TalsecSecurity-Community-Flutter:+-dev")
    
    // ONNX Runtime for ML model
    implementation("com.microsoft.onnxruntime:onnxruntime-android:1.15.1")
    
    // Gson for JSON parsing
    implementation("com.google.code.gson:gson:2.10.1")
}

