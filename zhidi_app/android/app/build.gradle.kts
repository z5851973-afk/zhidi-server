import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.zhidi_app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    if (keystorePropertiesFile.exists()) {
        val fis = FileInputStream(keystorePropertiesFile)
        keystoreProperties.load(fis)
        fis.close()
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = file(keystoreProperties.getProperty("storeFile"))
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    flavorDimensions += "app"
    productFlavors {
        create("worker") {
            dimension = "app"
            applicationId = "com.example.zhidi_app.worker"
        }
        create("owner") {
            dimension = "app"
            applicationId = "com.example.zhidi_app.owner"
            manifestPlaceholders["appName"] = "知底"
        }
    }

    defaultConfig {
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

// 入口分流已移至 lib/main.dart（根据 ZHIDI_APP_FLAVOR 运行时判断），
// 不再需要 Gradle 物理复制逻辑。

flutter {
    source = "../.."
}
