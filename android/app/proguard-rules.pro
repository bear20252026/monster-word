# Monster Word — ProGuard/R8 Rules
# Flutter 必要 keep 规则

# Flutter framework
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# sqflite (SQLite)
-keep class com.tekartik.sqflite.** { *; }

# audioplayers
-keep class xyz.luan.audioplayers.** { *; }

# 防止移除 FlutterEngine 注册的插件
-keepclassmembers class * {
    @io.flutter.embedding.engine.plugins.FlutterPlugin <methods>;
}
