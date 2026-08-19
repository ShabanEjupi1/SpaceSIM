import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 🚨 Shtojca zbatohet VETËM nëse `google-services.json` ekziston, DHE mungesa e
// tij te një ndërtim LËSHIMI është GABIM, jo shënim.
//
// Pa këtë të dytën, një AAB hipën te Play me Analytics-in e vdekur dhe asgjë nuk
// e thotë: gradle-ja e kapërcen shtojcën me një rresht të humbur mes mijërave,
// `Firebase.initializeApp()` hidhet, dhe `analitika.dart` e kap me `debugPrint`.
// Tri shtresa heshtjeje. Të paktën njëra duhet të bërtasë.
//
// Skedari NUK hyn te depoja. Merret me:
//   python linux-install/tools/firebase-konfigurimi.py <celesi.json> merr tech.spacecode.esim
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
} else {
    val eshteLeshim = gradle.startParameter.taskNames.any {
        it.contains("Release") || it.contains("bundle") || it.contains("Bundle")
    }
    if (eshteLeshim) {
        throw GradleException(
            "google-services.json MUNGON te android/app/ — Analytics-i do te ishte " +
            "i vdekur te ky leshim. Merre me firebase-konfigurimi.py (paketa tech.spacecode.esim) " +
            "dhe vendose te android/app/google-services.json."
        )
    }
    logger.lifecycle("google-services.json mungon — Firebase-i mbetet i fikur (debug).")
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

// 🚨 Matet SKEDARI, jo vetëm vetia. Te Tokërrgjiku `storeFile=release.jks` tregonte
// një skedar që NUK ekziston: vetia ishte e vendosur, kontrolli i vjetër kalonte, dhe
// ndërtimi binte vetëm te hapi i nënshkrimit — pas 20 minutash nën qemu.
val skedariICelesit = keystoreProperties.getProperty("storeFile")?.let { rootProject.file(it) }
val kaCeles = skedariICelesit?.exists() == true

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
            if (kaCeles) {
                storeFile = skedariICelesit
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
            signingConfig = if (kaCeles) {
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

// ═══ ROJA E NËNSHKRIMIT ═══════════════════════════════════════════════════════
// 🚨🚨 Rënia prapa te çelësi i DEBUG-ut mbetet me qëllim, që `flutter run --release`
// të punojë pa çelës. Por rruga drejt Play-it është `bundle*Release`, dhe AJO ndalet
// — brenda 5 sekondash te konfigurimi, jo pas 20 minutash te hapi i ngarkimit.
//
// 🔑 Lexohen emrat e detyrave të kërkuara, jo grafiku i tyre: `startParameter` është
// API e qëndrueshme te çdo version i Gradle-s, kurse forma e `taskGraph.whenReady`
// ka ndryshuar mes versioneve të Kotlin DSL-së.
run {
    val emrat = gradle.startParameter.taskNames
    val kerkonAab = emrat.any { it.contains("bundle", true) && it.contains("Release") }
    val kerkonApk = emrat.any { it.contains("assemble", true) && it.contains("Release") }
    if (!kaCeles && (kerkonAab || kerkonApk)) {
        val mesazhi = """
            ⛔ Nënshkrimi do të binte prapa te çelësi i DEBUG-ut.
               pritej          : ${rootProject.file("key.properties")}
               storeFile tregon: ${skedariICelesit ?: "(vetia mungon)"}
               kura            : krijo `android/key.properties` me shteg ABSOLUT —
                 storeFile=/mnt/data/workspace/spacecode-brain/keys/esim-upload.jks
                 storePassword=… · keyAlias=esim · keyPassword=…
                 (fjalëkalimet: §12 te credentials.local.txt)
        """.trimIndent()
        if (kerkonAab) throw GradleException(mesazhi)
        logger.warn(mesazhi)
        logger.warn("⚠️  APK-ja e lëshimit vazhdon me çelësin e debug-ut — kurrë për Play.")
    }
}
