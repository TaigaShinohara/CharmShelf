plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties

val keystoreProperties = Properties()
val usesOnePassword = System.getProperty("os.name").contains("Mac", ignoreCase = true) &&
    rootProject.file("../auth/android-signing.local.json").isFile
val externalSigningPath = providers.environmentVariable("CODEX_ANDROID_KEY_PROPERTIES").orNull
val keystorePropertiesFile = externalSigningPath?.let { path ->
    require(path.isNotBlank()) { "CODEX_ANDROID_KEY_PROPERTIES must not be blank" }
    rootProject.file(path).also {
        require(it.isFile) { "CODEX_ANDROID_KEY_PROPERTIES must point to an existing file" }
    }
} ?: rootProject.file("key.properties")
val hasSigningProperties = (!usesOnePassword || externalSigningPath != null) && keystorePropertiesFile.isFile
if (hasSigningProperties) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}
val allowDebugReleaseSigning =
    providers.environmentVariable("ALLOW_DEBUG_RELEASE_SIGNING").orNull == "true"
if (usesOnePassword && externalSigningPath == null && !allowDebugReleaseSigning) {
    val instructions = "Mac release signing requires 1Password; use python3 scripts/android_signing_1password.py -- COMMAND"
    if (gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }) {
        throw GradleException(instructions)
    }
    // Also cover aggregate/abbreviated tasks before any release packaging.
    tasks.matching { it.name.startsWith("pre") && it.name.endsWith("ReleaseBuild") }.configureEach {
        doFirst {
            error("Mac release signing requires 1Password; use python3 scripts/android_signing_1password.py -- COMMAND")
        }
    }
}
val environmentSigningVariableNames =
    listOf(
        "ANDROID_KEYSTORE_PATH",
        "ANDROID_KEYSTORE_PASSWORD",
        "ANDROID_KEY_ALIAS",
        "ANDROID_KEY_PASSWORD",
    )
val environmentSigningValues =
    environmentSigningVariableNames.associateWith { variableName ->
        if (!usesOnePassword && externalSigningPath == null) providers.environmentVariable(variableName).orNull else null
    }
val hasAnyEnvironmentSigningValue =
    environmentSigningValues.values.any { !it.isNullOrBlank() }
val hasCompleteEnvironmentSigning =
    environmentSigningValues.values.all { !it.isNullOrBlank() }
val releaseBuildRequested =
    gradle.startParameter.taskNames.any { taskName ->
        taskName.contains("release", ignoreCase = true)
    }

android {
    namespace = "com.tsmusic.privateshelf"
    // permission_handler 13 targets Android 17 APIs; keep targetSdk unchanged.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.tsmusic.privateshelf.opensource"
        // Opt-in isolated package for reproducible performance QA; production
        // builds keep their existing identifier and label.
        val performanceQa = providers.gradleProperty("tagshelfPerformanceQa").orNull == "true"
        if (performanceQa) {
            // Give a fresh device run its own container without clearing older QA data.
            val qaInstance = providers.gradleProperty("tagshelfQaInstance").orNull.orEmpty()
            require(qaInstance.isEmpty() || qaInstance.matches(Regex("[0-9]{1,8}"))) {
                "tagshelfQaInstance must be empty or 1-8 digits"
            }
            applicationIdSuffix = ".performanceqa$qaInstance"
        }
        manifestPlaceholders["appLabel"] = if (performanceQa) "CharmShelf 性能検証" else "CharmShelf"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    androidResources {
        // アプリで使用する言語のリソースだけを含める。
        localeFilters += listOf("ja", "en")
    }

    buildTypes {
        release {
            // コード難読化と最適化を有効化
            isMinifyEnabled = true
            // 未使用リソースの削除を有効化
            isShrinkResources = true
            // Proguardの設定ファイル
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )

            if (releaseBuildRequested &&
                hasAnyEnvironmentSigningValue &&
                !hasCompleteEnvironmentSigning
            ) {
                val missingVariables =
                    environmentSigningValues.filterValues { it.isNullOrBlank() }.keys
                throw GradleException(
                    "Android release signing environment is missing: " +
                        missingVariables.joinToString(),
                )
            }

            if (hasCompleteEnvironmentSigning) {
                signingConfig = signingConfigs.create("releaseFromEnvironment") {
                    val releaseStoreFile =
                        file(environmentSigningValues.getValue("ANDROID_KEYSTORE_PATH")!!)
                    if (!releaseStoreFile.isFile) {
                        throw GradleException(
                            "Release keystore does not exist: ${releaseStoreFile.path}",
                        )
                    }
                    storeFile = releaseStoreFile
                    storePassword =
                        environmentSigningValues.getValue("ANDROID_KEYSTORE_PASSWORD")
                    keyAlias = environmentSigningValues.getValue("ANDROID_KEY_ALIAS")
                    keyPassword = environmentSigningValues.getValue("ANDROID_KEY_PASSWORD")
                }
            } else if (hasSigningProperties) {
                val requiredProperties =
                    listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
                val missingProperties =
                    requiredProperties.filter {
                        keystoreProperties.getProperty(it).isNullOrBlank()
                    }
                if (missingProperties.isNotEmpty()) {
                    throw GradleException(
                        "android/key.properties is missing: ${missingProperties.joinToString()}",
                    )
                }

                signingConfig = signingConfigs.create("release") {
                    val storeFileTarget = keystoreProperties.getProperty("storeFile")
                    val releaseStoreFile = file(storeFileTarget)
                    if (!releaseStoreFile.isFile) {
                        throw GradleException(
                            "Release keystore does not exist: ${releaseStoreFile.path}",
                        )
                    }
                    storeFile = releaseStoreFile
                    storePassword = keystoreProperties.getProperty("storePassword")
                    keyAlias = keystoreProperties.getProperty("keyAlias")
                    keyPassword = keystoreProperties.getProperty("keyPassword")
                }
            } else if (allowDebugReleaseSigning) {
                // 明示的に許可したローカル検証だけで使用する。CI・配布ビルドでは禁止。
                signingConfig = signingConfigs.getByName("debug")
            } else if (releaseBuildRequested) {
                throw GradleException(
                    "Release signing is not configured. Set all ANDROID_KEYSTORE_* " +
                        "variables, add android/key.properties, " +
                        "or set ALLOW_DEBUG_RELEASE_SIGNING=true only for a local smoke build.",
                )
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

dependencies {
    testImplementation("junit:junit:4.13.2")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("com.google.android.play:feature-delivery:2.1.0")
}

flutter {
    source = "../.."
}
