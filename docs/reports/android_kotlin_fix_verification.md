# Android Kotlin Fix 验证报告

> 执行人：Aion CLI（teammate）
> 日期：2026-08-25
> 项目路径：D:\claude\work\cn_com_lange\word_app
> 验证时 HEAD：`0f72aac`
> 被验证的修复：`5a6c0bf` fix(build): disable Kotlin incremental compilation to fix cross-drive daemon crash

---

## 一、验证结论

**✅ PASS —— Android 构建不再需要在命令行传 `-Pkotlin.incremental=false`。**

该 workaround 已由 commit `5a6c0bf` 持久化到 `android/gradle.properties`，对所有 Gradle 调用（含 `flutter build`、IDE 同步、直接 `gradlew`）自动生效。实测不带任何 `-P` 参数执行完整 debug 构建成功。

---

## 二、实证验证

### 2.1 无参构建测试

```
flutter build apk --debug        ← 未附加 -Pkotlin.incremental=false
→ √ Built build\app\outputs\flutter-apk\app-debug.apk (58.3s)
```

构建成功，无 daemon 崩溃、无跨盘符编译错误。

### 2.2 修复原理

| 项 | 说明 |
|---|---|
| 问题 | Kotlin 增量编译在 pub cache（C: 盘）与项目目录（D: 盘）之间跨盘符操作时触发 daemon 崩溃（Kotlin issue **KT-47138**） |
| 修复 | 在 gradle.properties 中持久设置 `kotlin.incremental=false` |
| 效果 | 等价于每次命令行手工加 `-Pkotlin.incremental=false`，但一处配置全局生效，调用方无需记忆 |

### 2.3 配置清理

原 gradle.properties 中该 workaround 存在**重复两行**（中文注释 + 英文注释各带一行同名属性）。已清理为单一声明：

```properties
# 禁用 Kotlin 增量编译：解决 pub cache（C:）与项目（D:）跨盘符导致 daemon 崩溃（KT-47138）
# Workaround: Kotlin incremental compilation fails on cross-drive builds (KT-47138)
kotlin.incremental=false
```

属零风险整理（删除的是完全相同的重复键），不改变构建行为。

---

## 三、android/app/build.gradle 的 Kotlin 配置检查

注意：本项目实际使用 **Kotlin DSL（build.gradle.kts）**，不存在 build.gradle（Groovy）文件。检查结果：

| 检查点 | 现状 | 判定 |
|---|---|---|
| 插件接入 | 通过 Flutter 官方插件 `dev.flutter.flutter-gradle-plugin` 接入；`android.builtInKotlin=false`（模板默认）走外部 Kotlin 插件路径 | ✅ 正常 |
| Kotlin 编译目标 | `compilerOptions { jvmTarget = JvmTarget.JVM_17 }` | ✅ 与 compileOptions Java 17 一致 |
| 增量编译设置位置 | 不在 build.gradle.kts 中（正确——该开关属全局配置，位于 gradle.properties） | ✅ 位置正确 |
| kotlinOptions 过时 DSL | 未使用（已用新 compilerOptions API） | ✅ |

---

## 四、注意事项与建议

1. **不要从 gradle.properties 移除 `kotlin.incremental=false`**，除非确认 Kotlin 工具链已修复 KT-47138 且构建环境盘符布局改变；移除后需重跑本报告第 2.1 节的无参构建验证。
2. 该设置的代价是 Kotlin 编译不做增量（全量重编），debug 迭代速度略受影响；当前 58s 的全流程构建时间可接受。
3. stderr 中的 Java native-access / "source value 8 is obsolete" 提示来自部分插件的旧字节码目标，与本修复无关，不影响产物。

---

## 五、判定汇总

| 任务要求 | 结果 |
|---|---|
| 确认 Android 构建不需要 `-Pkotlin.incremental=false` | ✅ 已实证确认 |
| 检查 android/app/build.gradle 中的 Kotlin 配置 | ✅ 完成（实为 .kts，配置正确） |
| 产出验证报告 | ✅ 本文档 |

*Aion CLI · 2026-08-25*
