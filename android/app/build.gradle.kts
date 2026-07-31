import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// key.properties must live at android/key.properties (this file's directory),
// resolved via rootProject so it's unambiguous regardless of which module's
// build script is reading it.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))

    // storeFile must be an ABSOLUTE path (this is Flutter's own documented
    // recommendation) — a relative path here is ambiguous: Gradle's file()
    // resolves it against the CALLING module's directory (android/app/),
    // which does not match where key.properties itself lives (android/).
    // That mismatch previously caused release builds to silently resolve to
    // a non-existent keystore. Fail the build loudly instead of ever
    // falling back to the debug key for a "release" build type.
    val storeFilePath = keystoreProperties["storeFile"] as String
    val resolvedStoreFile = file(storeFilePath)
    if (!resolvedStoreFile.isAbsolute) {
        throw GradleException(
            "android/key.properties: storeFile must be an ABSOLUTE path " +
            "(e.g. /home/user/upload-keystore.jks), not \"$storeFilePath\". " +
            "Relative paths resolve inconsistently depending on which Gradle " +
            "module reads them and have silently broken release signing before."
        )
    }
    if (!resolvedStoreFile.exists()) {
        throw GradleException(
            "android/key.properties points storeFile at " +
            "\"${resolvedStoreFile.absolutePath}\" but no file exists there. " +
            "Refusing to build a release AAB without the real signing key."
        )
    }
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.neurodevlabs.magnumopus"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                // (storeFile validated as an existing absolute path above)
            }
        }
    }

    buildTypes {
        release {
            // Signs with the dedicated release keystore (android/key.properties)
            // when present — and the block above guarantees that if
            // key.properties exists, it points at a real, absolute,
            // existing keystore file (or the build fails outright).
            // Falls back to the debug key ONLY when key.properties is
            // entirely absent, so local `flutter run --release` still
            // works without extra setup. Never upload an AAB built this way.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
