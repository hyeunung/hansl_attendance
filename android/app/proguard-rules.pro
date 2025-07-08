# Flutter ProGuard Rules
# Keep Flutter framework classes
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Dart VM Service classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.editing.** { *; }
-keep class io.flutter.plugin.localization.** { *; }
-keep class io.flutter.plugin.mouse.** { *; }
-keep class io.flutter.plugin.platform.** { *; }

# Supabase 관련 클래스 보존
-keep class io.supabase.** { *; }
-keep class com.supabase.** { *; }

# Firebase 관련 클래스 보존 (사용시)
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Google Play Core 관련 클래스 보존 (Flutter에서 사용)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Geolocator 플러그인 보존
-keep class com.baseflow.geolocator.** { *; }

# JSON serialization
-keepattributes *Annotation*
-keepclassmembers class ** {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Keep model classes (데이터 클래스)
-keep class * extends java.lang.Object {
    public <fields>;
    public <methods>;
}

# 네트워크 관련
-keep class okhttp3.** { *; }
-keep class retrofit2.** { *; }

# 일반적인 최적화 방지 규칙
-dontoptimize
-dontobfuscate
-dontwarn okhttp3.**
-dontwarn retrofit2.** 