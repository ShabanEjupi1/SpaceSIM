import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Nënshkrimi i lëshimit. `key.properties` dhe `.jks` janë të gitignore-uara dhe
// rrinë vetëm te makina që ndërton (te CI-ja i shkruan puna «Vendos çelësin»).
//
// !! `esim-upload.jks` është KOPJE E VETME te `spacecode-brain/keys/`. Nëse
//    humbet, ky aplikacion nuk përditësohet dot më kurrë: Android-i refuzon një
//    paketë të nënshkruar me çelës tjetër, dhe Play-i do të donte paketë e
//    listim krejt të ri.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

android {
    namespace = "tech.spacecode.esim"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "tech.spacecode.esim"
        minSdk = 24
        // 🚨 Play kërkon **API 36 për çdo ngarkim të ri që nga 31 gushti 2026**,
        // dhe nga 1 nëntori bllokon çdo përditësim që nuk e ka. Nisim drejt me
        // 36, që të mos ngrihet asgjë në panik vitin që vjen.
        // ⚠️ Play e mat këtë mbi TË GJITHA artefaktet aktive, edhe ato te
        //    `internal` — një ndërtim i vjetër i harruar aty e bllokon një
        //    lëshim krejt të ri. Shih Tokerrgjik/store/tools/pastro-gjurmet.mjs.
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystoreProperties.getProperty("storeFile") != null) {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Pa `key.properties` bie prapa te çelësi i debug-ut, që e mban
            // `flutter run --release` të punueshëm lokalisht — por një AAB i
            // tillë refuzohet nga Play Console.
            signingConfig = if (keystoreProperties.getProperty("storeFile") != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
