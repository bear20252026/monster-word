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

# Google Play Core (R8 missing classes)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# ── 审计 R14（2026-11-16）：flutter_local_notifications release 混淆保留 ──
# 排程通知经 Gson 反射序列化进 SharedPreferences（插件 buildGson +
# RuntimeTypeAdapterFactory 多态样式）；R8 重命名/裁剪模型字段会让重启后
# 反序列化失败 → 已排程的学习提醒丢失。插件 22.3.0 无自带 consumer 规则，
# 且 com.dexterous.** 不在 io.flutter.plugins.** 既有 keep 覆盖内，须显式保留。
-keep class com.dexterous.flutterlocalnotifications.** { *; }
# Gson 本体（TypeToken 匿名子类依赖泛型签名做反射）
-keep class com.google.gson.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keepattributes Signature
-keepattributes *Annotation*
# 通知接收器由 Manifest/AlarmManager 按类名实例化，不可裁剪
-keep class com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver { *; }
-keep class com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver { *; }
-keep class com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**
