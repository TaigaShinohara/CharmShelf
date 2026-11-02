// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import java.util.Properties
import java.security.MessageDigest
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    `java-gradle-plugin`
    groovy
    `kotlin-dsl`
    kotlin("jvm") version "2.2.20"
}

group = "dev.flutter.plugin"
version = "1.0.0"

// Optional: enable stricter validation, to ensure Gradle configuration is correct
tasks.validatePlugins {
    enableStricterValidation.set(true)
}

gradlePlugin {
    plugins {
        // The "flutterPlugin" name isn't used anywhere.
        create("flutterPlugin") {
            id = "dev.flutter.flutter-gradle-plugin"
            implementationClass = "com.flutter.gradle.FlutterPlugin"
        }
        // The "flutterAppPluginLoaderPlugin" name isn't used anywhere.
        create("flutterAppPluginLoaderPlugin") {
            id = "dev.flutter.flutter-plugin-loader"
            implementationClass = "com.flutter.gradle.FlutterAppPluginLoaderPlugin"
        }
    }
}

tasks.withType<JavaCompile> {
    options.release.set(11)
}

tasks.test {
    useJUnitPlatform()
}
// https://stackoverflow.com/questions/55456176/unresolved-reference-compilekotlin-in-build-gradle-kts
tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile> {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_11)
    }
}

dependencies {
    // Versions available https://mvnrepository.com/artifact/androidx.annotation/annotation-jvm.
    // Version release notes https://developer.android.com/jetpack/androidx/releases/annotation
    compileOnly("androidx.annotation:annotation-jvm:1.9.1")
    // When bumping, also update:
    //  * KGP error version in packages/flutter_tools/gradle/src/main/kotlin/DependencyVersionChecker.kt
    implementation("org.jetbrains.kotlin:kotlin-gradle-plugin:2.0.0")
    // Update to 1.8.0 when min kotlin is 2.1
    // https://github.com/Kotlin/kotlinx.serialization/releases for kotlin version compatibility.
    // All kotlinx implementation dependencies must work with the oldest kotlin supported versions.
    // Defined in packages/flutter_tools/gradle/src/main/kotlin/DependencyVersionChecker.kt
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.4.0")
    // When bumping, also update:
    //  * AGP version constants in packages/flutter_tools/lib/src/android/gradle_utils.dart
    //  * ndkVersion constant in packages/flutter_tools/lib/src/android/gradle_utils.dart
    //  * ndkVersion in FlutterExtension in packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt
    compileOnly("com.android.tools.build:gradle:8.11.1")

    testImplementation(kotlin("test"))
    testImplementation("com.android.tools.build:gradle:8.11.1")
    testImplementation("org.mockito:mockito-core:5.8.0")
    testImplementation("io.mockk:mockk:1.13.16")
}

// 共有SDKは変更せず、このプロジェクトだけ6ファイルを差し替える。
val sdkProperties = Properties().apply {
    file("../local.properties").inputStream().use { load(it) }
}
val upstream = file("${sdkProperties.getProperty("flutter.sdk")}/packages/flutter_tools/gradle")
val expectedSources = mapOf(
    "src/main/kotlin/DependencyVersionChecker.kt" to "573148ac80642432e1c84a7874efdea6a827fcaa8dd34de01e61ab4a6be309ef",
    "src/main/kotlin/FlutterPlugin.kt" to "aba6c2f7331ea613227fed69666f8edb3839c09413188ccab64989dabe4bcd6f",
    "src/main/kotlin/tasks/BaseFlutterTask.kt" to "27dd5ea0f0938f3d1cfb54b992601b39cbf25ae8f20bfe2da771d2ebbb630c56",
    "src/main/kotlin/tasks/BaseFlutterTaskHelper.kt" to "2436cca453b4a1ac7720b3a951f6bce8fc668e966d577d4b256c2d8a96ff43f7",
    "src/main/kotlin/tasks/FlutterTask.kt" to "93dc5805d863e1df88f1b297a18dc1eedd619c7e80bfdaa37b7edbf9dd506920",
    "src/main/kotlin/tasks/FlutterTaskHelper.kt" to "117ff398ef94af8ce4fe83ecb227da5ccb2a2d4e6bcdeb05f1392f7e5343ef22",
    "build.gradle.kts" to "8bce67c561f7a91bb743b443242b8d804ddc4190dc5524278bdecf8797515008",

)
expectedSources.forEach { (path, expected) ->
    val actual = MessageDigest.getInstance("SHA-256")
        .digest(upstream.resolve(path).readBytes()).joinToString("") { "%02x".format(it) }
    check(actual == expected) {
        "Flutter Gradleプラグインが検証済みソースと異なります。ローカル修正を再検証してください: $path"
    }
}
kotlin.sourceSets.named("main") {
    kotlin.setSrcDirs(listOf(upstream.resolve("src/main/kotlin"), file("src/main/kotlin")))
    val excludedUpstreamFiles = expectedSources.keys.filter { it.endsWith(".kt") }
        .map { upstream.resolve(it).canonicalFile }.toSet()
    kotlin.exclude { it.file.canonicalFile in excludedUpstreamFiles }
}
