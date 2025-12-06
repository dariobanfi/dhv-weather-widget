plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.example.dhvweather"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.example.dhvweather"
        minSdk = 24
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }
    kotlinOptions {
        jvmTarget = "1.8"
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.google.android.material:material:1.11.0")
    
    // Background Work
    implementation("androidx.work:work-runtime-ktx:2.9.0")
    
    // Lifecycle (for observing WorkInfo)
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.6.2")

    // HTML Parsing
    implementation("org.jsoup:jsoup:1.17.2")
    
    // JSON
    implementation("com.google.code.gson:gson:2.10.1")
}
