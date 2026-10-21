import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// release 서명: android/key.properties(커밋 안 함)에 storeFile·keyAlias만 적고,
// 비밀번호는 빌드할 때 환경 변수 ALOK_STORE_PASSWORD / ALOK_KEY_PASSWORD 로 받는다
// (install_and_build.command 가 화면에 보이지 않게 물어본다). 둘 중 하나라도 없으면 debug 키로 서명한다.
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val storePw: String? = System.getenv("ALOK_STORE_PASSWORD")?.takeIf { it.isNotEmpty() }
val keyPw: String? = System.getenv("ALOK_KEY_PASSWORD")?.takeIf { it.isNotEmpty() } ?: storePw
val hasReleaseKey = keyProps.getProperty("storeFile") != null && storePw != null

android {
    namespace = "com.alokdalok.alokdalok"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.alokdalok.alokdalok"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // arm 기기 전용 (에뮬레이터용 x86_64 제외 → 용량 절약)
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a")
        }
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(keyProps.getProperty("storeFile"))
                storePassword = storePw
                keyAlias = keyProps.getProperty("keyAlias") ?: "alokdalok"
                keyPassword = keyPw
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                logger.warn("알록달록: release 키가 없어 debug 키로 서명합니다 (install_and_build.command 참고).")
                signingConfigs.getByName("debug")
            }
        }
    }
}

// ML Kit 얼굴 인식: 앱에 모델을 담는 번들 버전 대신 Play 서비스(unbundled) 버전을 쓴다.
// 모델은 Play 서비스가 내려받으므로 APK가 작아진다. API(com.google.mlkit.vision.face)는 같다.
configurations.all {
    exclude(group = "com.google.mlkit", module = "face-detection")
}

dependencies {
    implementation("com.google.android.gms:play-services-mlkit-face-detection:17.1.0")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
