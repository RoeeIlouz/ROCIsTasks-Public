# ROCIs Tasks - ProGuard / R8 Rules

# AppWidget and RemoteViews rules
-keep class * extends android.appwidget.AppWidgetProvider { *; }
-keep class * extends android.widget.RemoteViewsService { *; }

# Strip verbose, debug, and info logs in release builds
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
}

# Ignore optional Play Core classes when not using deferred components
-dontwarn com.google.android.play.core.**
