# Keep Flutter entry points and plugin registration intact while allowing R8
# to strip unused Android classes and resources.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }

-keep class * extends io.flutter.embedding.engine.plugins.FlutterPlugin { *; }
-keep class * extends io.flutter.plugin.common.MethodChannel$MethodCallHandler { *; }

# flutter_local_notifications uses generic type tokens during boot rescheduling.
# R8 must retain signature metadata and the plugin receiver classes.
-keepattributes Signature
-keep class com.dexterous.flutterlocalnotifications.** { *; }

-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task

# Google Cast SDK
-keep class com.google.android.gms.cast.** { *; }
-keep class com.google.android.gms.internal.cast.** { *; }
-keep class com.google.android.libraries.cast.companionlibrary.** { *; }

# MediaRouter
-keep class androidx.mediarouter.** { *; }

# Your CastOptionsProvider (referenced by name in Manifest)
-keep class com.example.athan_call_to_success.CastOptionsProvider { *; }
-keep class com.salamay.googlecast.** { *; }

# Home screen widget providers (referenced by name in AndroidManifest)
-keep class com.example.athan_call_to_success.NextPrayerWidgetProvider { *; }
-keep class com.example.athan_call_to_success.PrayerTimesWidgetProvider { *; }
-keep class com.example.athan_call_to_success.PrayerTrackerWidgetProvider { *; }
-keep class com.example.athan_call_to_success.QiblaWidgetProvider { *; }
-keep class com.example.athan_call_to_success.QuranWidgetProvider { *; }
