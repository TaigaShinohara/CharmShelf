# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Isar specific rules
-keep class io.isar.** { *; }
-keepnames class io.isar.** { *; }

# Audio (just_audio / audio_service / audioplayers)
-keep class com.ryanheise.just_audio.** { *; }
-keep class com.ryanheise.audioservice.** { *; }
-keep class xyz.luan.audioplayers.** { *; }

# Secure Storage & Encryption
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Shared Storage (SAF)
-keep class io.flutter.plugins.sharedstorage.** { *; }

# Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Image Compress
-keep class com.fluttercandies.imagecompress.** { *; }

# Google Play Core & In-App Review
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**
