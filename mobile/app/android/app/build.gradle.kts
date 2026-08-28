import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase — `google-services.json`u işler. Sürümü settings.gradle.kts'te.
    id("com.google.gms.google-services")
}

// Upload imzalama anahtarı (22 Ağustos 2026, ROADMAP FAZ B → 0.A1).
//
// `key.properties` ve `.jks` REPOYA GİRMEZ (android/.gitignore zaten
// `key.properties`, `**/*.jks` ve `**/*.keystore` satırlarını taşıyor).
// CI bu dosyayı `ANDROID_KEYSTORE_BASE64` + `ANDROID_KEYSTORE_PASSWORD`
// secret'larından üretiyor (bkz. .github/workflows/mobile-build.yml).
//
// **Dosya YOKSA release DEBUG anahtarına düşer — bilinçli:** `flutter run
// --release` ve CI'daki Appetize test .apk'sı anahtar olmadan da çalışmaya
// devam etsin diye. Play'e giden `.aab` böyle bir derlemeyle ASLA
// üretilmemeli; workflow'daki AAB adımı bu yüzden secret yokken hiç
// koşmuyor ve ürettiği paketin imzasını `keytool` ile GERİ OKUYUP
// doğruluyor (debug anahtarıyla imzalanmış bir .aab'yi Play reddeder,
// ama sessizce üretilebilir — o sessizliği kapatan şey o adım).
val keystorePropertiesFile = rootProject.file("key.properties")
val hasUploadKeystore = keystorePropertiesFile.exists()
val keystoreProperties = Properties().apply {
    if (hasUploadKeystore) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}

android {
    namespace = "com.kelimeki.kelimeki"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Mağazaya İLK yüklemeden sonra KALICI (bkz. mobile/CLAUDE.md).
        applicationId = "com.kelimeki.kelimeki"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // `versionName` pubspec.yaml'ın `version`'ından; `versionCode` de
        // oradaki `+N`'den gelir — CI `--build-number` ile üzerine yazıyor
        // (Play aynı versionCode'u iki kez kabul etmiyor).
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasUploadKeystore) {
            create("release") {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasUploadKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
