# ROCIs Tasks - ProGuard Rules

# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Hive database rules
-keep class * extends hive.HiveObject
-keepclassmembers class * extends hive.HiveObject {
    <fields>;
}

# Google Sign-In rules
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

# Device Calendar rules
-keep class com.builttoroam.devicecalendar.** { *; }

# Remove logging in release builds
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
}

# Flutter Deferred Components / Play Core (ignore missing Play Core classes if not using deferred components)
-dontwarn com.google.android.play.core.**
