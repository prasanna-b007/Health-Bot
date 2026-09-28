# R8/ProGuard rules for the release build.
#
# Flutter's engine classes are referenced reflectively from native code, so
# they must survive shrinking. The Flutter tool contributes most of this
# automatically; these cover the plugins this app uses.

# Flutter embedding
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# geolocator
-keep class com.baseflow.geolocator.** { *; }

# url_launcher / share_plus resolve activities via the platform channel
-keep class io.flutter.plugins.urllauncher.** { *; }
-keep class dev.fluttercommunity.plus.share.** { *; }

# Keep annotations used by the Play Core split-install stubs Flutter references
-dontwarn com.google.android.play.core.**

# Strip Android log calls from the release binary. Debug output in this app
# includes request and response detail, which should not reach a user's
# device log on a shipped build.
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}
