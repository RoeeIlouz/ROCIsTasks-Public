# ROCIs Tasks - ProGuard / R8 Rules

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

# AppWidget and RemoteViews rules
-keep class * extends android.appwidget.AppWidgetProvider { *; }
-keep class * extends android.widget.RemoteViewsService { *; }
-keep class com.rocisapps.tasks.** { *; }

# Strip verbose, debug, and info logs in release builds
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
}

# Ignore optional Play Core classes when not using deferred components
-dontwarn com.google.android.play.core.**
