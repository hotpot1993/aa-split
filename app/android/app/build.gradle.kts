import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 读取签名配置（app/android/key.properties，gitignore 保护，绝不提交）
// 缺失时回退 debug 签名（仅影响本地开发调试，发布构建前必须先生成并配置）
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
var hasReleaseSigning = false
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
    hasReleaseSigning = true
}

android {
    namespace = "com.aasplit.app"
    // permission_handler_android 等新插件要求 37
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // 商店上架用的正式应用标识（applicationId = 包名，发布后不可更改）
        applicationId = "com.aasplit.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // 极光推送占位符（jpush_flutter 插件 manifest 合并需要）
        manifestPlaceholders["JPUSH_APPKEY"] = "aadc425dd712362a851cf69a"
        manifestPlaceholders["JPUSH_CHANNEL"] = "default"
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigning) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            } else {
                // 兜底：无 key.properties 时置空（发布构建会明确报错，不静默用 debug 签名）
                keyAlias = ""
                keyPassword = ""
                storeFile = null
                storePassword = ""
            }
        }
    }

    buildTypes {
        release {
            // 商店包必须使用正式签名；未配置 key.properties 时给出明确提示
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                // 保持本地 `flutter run --release` 可用，但发布脚本会先检查签名配置
                signingConfig = signingConfigs.getByName("debug")
                println("WARNING: key.properties 不存在，release 构建将使用 debug 签名（仅限本地调试，不可上架）")
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
