import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localProps = Properties().apply {
    val f = rootProject.file("local.properties")
    if (f.exists()) FileInputStream(f).use { load(it) }
}
val keyProps = Properties().apply {
    val f = rootProject.file("keystore.properties")
    if (f.exists()) FileInputStream(f).use { load(it) }
}

android {
    namespace = "app.cineva.cineva"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "app.cineva.cineva"
        minSdk = 23
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        resourceConfigurations += listOf("en", "tr")
        buildConfigField("String", "TMDB_API_KEY", "\"${localProps.getProperty("TMDB_API_KEY", localProps.getProperty("tmdb.api.key", ""))}\"")
        buildConfigField("String", "ADMOB_BANNER_ID", "\"${localProps.getProperty("ADMOB_BANNER_ID", "")}\"")
        buildConfigField("String", "ADMOB_NATIVE_ID", "\"${localProps.getProperty("ADMOB_NATIVE_ID", "")}\"")
        buildConfigField("String", "ADMOB_INTERSTITIAL_ID", "\"${localProps.getProperty("ADMOB_INTERSTITIAL_ID", "")}\"")
        manifestPlaceholders["ADMOB_APP_ID"] = localProps.getProperty("ADMOB_APP_ID", "ca-app-pub-3940256099942544~3347511713")
    }

    signingConfigs {
        create("release") {
            if (keyProps.isNotEmpty()) {
                storeFile = rootProject.file(keyProps.getProperty("storeFile"))
                storePassword = keyProps.getProperty("storePassword")
                keyAlias = keyProps.getProperty("keyAlias")
                keyPassword = keyProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keyProps.isNotEmpty()) {
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
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
    }

    packaging {
        resources {
            excludes += setOf("META-INF/*.kotlin_module", "kotlin/**", "META-INF/DEPENDENCIES")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
