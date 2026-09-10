import java.util.Properties
import java.io.FileInputStream
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.codeable.glassforge.workbench"
    // Pinned rather than `flutter.compileSdkVersion` so the Play Store policy
    // floor (Android 16 / API 36) holds regardless of the local Flutter SDK.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    signingConfigs {
        create("release") {
            if (System.getenv("ANDROID_KEYSTORE_PATH") != null) {
                storeFile = file(System.getenv("ANDROID_KEYSTORE_PATH"))
                keyAlias = System.getenv("ANDROID_KEYSTORE_ALIAS")
                keyPassword = System.getenv("ANDROID_KEYSTORE_PRIVATE_KEY_PASSWORD")
                storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
            } else if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                storeFile = keystoreProperties["storeFile"]?.toString()?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    defaultConfig {
        applicationId = "com.codeable.glassforge.workbench"
        minSdk = flutter.minSdkVersion
        // Google Play rejects updates that target below Android 16 (API 36).
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true

        // Selects the Google Play Billing Library 8 variant of
        // purchases-hybrid-common. Play rejects updates built against
        // Billing 7 or lower.
        missingDimensionStrategy("billingclient", "bc8")
    }

    flavorDimensions += "default"

    productFlavors {
        create("production") {
            dimension = "default"
            applicationIdSuffix = ""
            manifestPlaceholders["appName"] = "Glass Forge Workbench"
        }
        create("staging") {
            dimension = "default"
            applicationIdSuffix = ".stg"
            manifestPlaceholders["appName"] = "Glass Forge Workbench [STG]"
        }
        create("development") {
            dimension = "default"
            applicationIdSuffix = ".dev"
            manifestPlaceholders["appName"] = "Glass Forge Workbench [DEV]"
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = if (signingConfigs.getByName("release").storeFile != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
        getByName("debug") {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_11
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// Copy google-services.json from firebase/<flavor>/ into app/src/<flavor>/
// so the Google Services plugin picks it up automatically.
// Skips gracefully if the file doesn't exist (Firebase not yet configured).
android.productFlavors.forEach { flavor ->
    val flavorName = flavor.name
    val src = rootProject.file("firebase/$flavorName/google-services.json")
    val dst = file("src/$flavorName/google-services.json")

    tasks.register<Copy>("copy${flavorName.replaceFirstChar { it.uppercase() }}GoogleServices") {
        description = "Copies google-services.json for $flavorName flavor"
        if (src.exists()) {
            from(src)
            into(dst.parentFile)
        } else {
            doLast {
                logger.warn("google-services.json not found at ${src.path} — skipping (add it when you set up Firebase)")
            }
        }
    }
}

tasks.configureEach {
    if (name.startsWith("process") && name.endsWith("GoogleServices")) {
        val flavorName = android.productFlavors
            .map { it.name }
            .firstOrNull { name.contains(it, ignoreCase = true) }

        if (flavorName != null) {
            val copyTaskName = "copy${flavorName.replaceFirstChar { it.uppercase() }}GoogleServices"
            if (project.tasks.names.contains(copyTaskName)) {
                dependsOn(copyTaskName)
            }
        }
    }
}
