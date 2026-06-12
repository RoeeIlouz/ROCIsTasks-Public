# ROCIs Tasks - ProGuard Rules

# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase - keep only what's needed
-keep class com.google.firebase.analytics.** { *; }
-keep class com.google.firebase.crashlytics.** { *; }
-keep class com.google.firebase.firestore.** { *; }
-keep class com.google.firebase.auth.** { *; }
-keep class com.google.firebase.perf.** { *; }
-keep class com.google.firebase.remoteconfig.** { *; }
-dontwarn com.google.firebase.**

# Hive database rules
-keep class * extends hive.HiveObject
-keepclassmembers class * extends hive.HiveObject {
    <fields>;
}

# Google Sign-In rules
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

# Notification rules
-keep class androidx.work.** { *; }
-keep class * extends androidx.work.Worker
-keep class * extends androidx.work.InputMerger
-keepclassmembers class * extends androidx.work.Worker {
    public <init>(android.content.Context,androidx.work.WorkerParameters);
}

# Device Calendar rules
-keep class com.builttoroam.devicecalendar.** { *; }

# RevenueCat rules
-keep class com.revenuecat.purchases.** { *; }

# Play Core rules (required by Flutter engine)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Remove logging in release builds
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
}
