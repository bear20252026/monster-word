# 【重构98】完整构建验证报告

> 验证人：DevOps（Claude Code）
> 日期：2026-08-24
> 方式：执行 `flutter build` 命令，记录结果
> 约束：不改代码，只产出报告
> 更新：第二轮验证（sb_button.dart 修复后）

---

## 1. 验证结果总览

| 平台 | 命令 | 结果 | 耗时 | 产物 |
|---|---|---|---|---|
| Windows | `flutter build windows --debug` | ✅ 成功 | 167.0s | MonsterWord.exe（1.2 MB） |
| Android | `flutter build apk --debug` | ✅ 成功 | 261.6s | app-debug.apk（188.6 MB） |

**双平台构建均通过 ✅**

---

## 2. Windows 构建详情

### 构建命令

```bash
flutter clean && flutter pub get && flutter build windows --debug
```

### 构建结果

| 项 | 值 |
|---|---|
| 状态 | ✅ 成功 |
| 产物路径 | `build\windows\x64\runner\Debug\MonsterWord.exe` |
| 产物大小 | 1,270,272 字节（~1.2 MB，debug 版） |
| exe 名称 | MonsterWord.exe ✓（已品牌化） |
| 构建耗时 | 167.0 秒 |

### 已解决问题

首次构建（未 clean）曾失败：`CMake Error: No target "word_app"`。原因是 `BINARY_NAME` 从 `word_app` 改为 `MonsterWord` 后 CMake 缓存失效。`flutter clean` 后解决。

---

## 3. Android 构建详情

### 构建命令

```bash
flutter clean && flutter pub get && flutter build apk --debug -Pkotlin.incremental=false
```

> ⚠️ 需加 `-Pkotlin.incremental=false` 参数绕过 Kotlin 增量编译跨盘符 bug（见 §3.3）。

### 构建结果

| 项 | 值 |
|---|---|
| 状态 | ✅ 成功 |
| 产物路径 | `build\app\outputs\flutter-apk\app-debug.apk` |
| 产物大小 | 197,859,425 字节（~188.6 MB，debug 版含词库） |
| 构建耗时 | 261.6 秒 |

### 3.1 第一轮失败（已修复）

第一轮 Android 构建因 Dart 编译错误失败：

```
lib/widgets/sb_button.dart:181: Error: The getter 'greenBanner' isn't defined for the type 'ThemeVars'.
lib/widgets/sb_button.dart:181: Error: The getter 'greenSoft' isn't defined for the type 'ThemeVars'.
```

**修复**：TokenEngineer 将 `sb_button.dart` 的引用从 `colors.greenBanner`/`colors.greenSoft`（ThemeVars）改为直接引用 `StarbucksCreamColors.greenSoft`。

### 3.2 第二轮成功

修复 Dart 错误后，Android 构建成功通过。

### 3.3 Kotlin 增量编译跨盘符 bug

**现象**：Kotlin daemon 在编译 `audioplayers_android`、`shared_preferences_android`、`webview_flutter_android` 三个插件时崩溃，报错：

```
java.lang.IllegalArgumentException: this and base files have different roots:
C:\Users\...\Pub\Cache\...\xxx.kt and D:\claude\work\...\android
```

**根因**：pub cache 位于 C: 盘，项目位于 D: 盘。Kotlin 增量编译器计算相对路径时跨盘符失败（已知 Kotlin bug，KT-47138）。

**解决方案**：构建时加 `-Pkotlin.incremental=false` 禁用增量编译。

**长期建议**：
- 将 `kotlin.incremental=false` 写入 `android/gradle.properties`（本报告未改文件）
- 或将 PUB_CACHE 环境变量设到 D: 盘

---

## 4. flutter analyze 状态

| 项 | 值 |
|---|---|
| ERROR | 0 |
| 总 issue | 389（全部为 warning/info） |

---

## 5. 构建环境备注

| 项 | 值 |
|---|---|
| Flutter 版本 | 3.47.0（stable） |
| Dart SDK | ^3.13.0 |
| Java | JDK 17（Android 构建） |
| Gradle | 9.3.1 |
| OS | Windows 11 Home China |

---

## 6. 结论

- **Windows 构建**：✅ 通过
- **Android 构建**：✅ 通过（需 `-Pkotlin.incremental=false`）
- **Dart 编译**：✅ ERROR=0（sb_button.dart 已修复）
- **无阻断项**

---

*验证完成：DevOps（Claude Code）· 2026-08-24 · 第二轮验证*
