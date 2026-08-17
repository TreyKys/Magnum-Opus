import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is configured from android/key.properties, which is
// gitignored along with the keystore itself — neither may ever be committed.
// See RELEASE_SIGNING.md for how to generate them.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.neurodevlabs.magnumopus"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.neurodevlabs.magnumopus"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Only declared when the keystore actually exists, so a checkout
        // without key.properties still configures and builds cleanly.
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storePassword = keystoreProperties["storePassword"] as String
                storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
            }
        }
    }

    buildTypes {
        release {
            // Shrinking stays off — turning R8 on days before a launch risks
            // stripping something reflective in the ad/billing SDKs. The rules
            // file (ML Kit script warnings) is wired up now so enabling
            // isMinifyEnabled later is a one-line change.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )

            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                // Fallback so `flutter run --release` still works before a
                // keystore exists. Play Console REJECTS debug-signed uploads,
                // and installing over a differently-signed build fails with
                // INSTALL_FAILED_UPDATE_INCOMPATIBLE — so this is for local
                // testing only, never for shipping.
                logger.warn(
                    "WARNING: android/key.properties not found — signing the " +
                    "release build with the DEBUG key. This APK cannot be " +
                    "uploaded to Play. See RELEASE_SIGNING.md."
                )
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
