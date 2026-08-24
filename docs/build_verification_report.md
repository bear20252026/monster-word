# 【重构98】完整构建验证报告

> 验证人：DevOps（Claude Code）
> 日期：2026-08-24
> 方式：执行 `flutter build` 命令，记录结果
> 约束：不改代码，只产出报告

---

## 1. 验证结果总览

| 平台 | 命令 | 结果 | 耗时 | 备注 |
|---|---|---|---|---|
| Windows | `flutter build windows --debug` | ✅ 成功 | 189.3s | 需先 `flutter clean`（CMake 缓存失效） |
| Android | `flutter build apk --debug` | ❌ 失败 | 52s | Dart 编译错误（非环境问题） |

---

## 2. Windows 构建详情

### 2.1 构建命令

```bash
flutter clean && flutter pub get && flutter build windows --debug
```

### 2.2 构建结果

| 项 | 值 |
|---|---|
| 状态 | ✅ 成功 |
| 产物路径 | `build\windows\x64\runner\Debug\MonsterWord.exe` |
| 产物大小 | 1,270,272 字节（~1.2 MB，debug 版） |
| exe 名称 | MonsterWord.exe ✓（已品牌化） |
| 构建耗时 | 189.3 秒 |

### 2.3 前置问题

首次构建（未 clean）失败，错误：

```
CMake Error: No target "word_app"
```

**原因**：`windows/CMakeLists.txt` 的 `BINARY_NAME` 已被改为 `MonsterWord`，但 CMake 缓存中仍引用旧目标名 `word_app`。

**解决**：`flutter clean` 清除缓存后重建成功。

**建议**：任何修改 `BINARY_NAME` 后必须 `flutter clean`，否则 CMake 增量构建会失败。

---

## 3. Android 构建详情

### 3.1 构建命令

```bash
flutter clean && flutter pub get && flutter build apk --debug
```

### 3.2 构建结果

| 项 | 值 |
|---|---|
| 状态 | ❌ 失败 |
| 失败阶段 | Dart 编译（`compileFlutterBuildDebug`） |
| 构建耗时 | 52 秒 |

### 3.3 错误分析

#### 错误 1：`greenBanner` 未定义

```
lib/widgets/sb_button.dart:181:23: Error: The getter 'greenBanner' isn't defined for the type 'ThemeVars'.
```

#### 错误 2：`greenSoft` 未定义

```
lib/widgets/sb_button.dart:181:58: Error: The getter 'greenSoft' isn't defined for the type 'ThemeVars'.
```

**根因**：`sb_button.dart:181` 引用了 `colors.greenBanner` 和 `colors.greenSoft`，但 `ThemeVars` 类（`skin_system.dart`）没有这两个字段。

这两个颜色存在于 `StarbucksCreamColors` 中：
- `greenBanner` = `Color(0xFF1E3932)`（深绿横幅）
- `greenSoft` = `Color(0xFF2B5148)`（辅助深绿）

但它们未被提升到 `ThemeVars` 语义令牌层。

**修复方案**（二选一）：

1. **推荐**：在 `ThemeVars` 中添加 `greenBanner` 和 `greenSoft` 字段（与 `accent`/`teal` 同级），并在各主题预设中赋值
2. **临时**：`sb_button.dart` 直接导入 `starbucks_tokens.dart` 使用 `StarbucksCreamColors.greenBanner`（破坏语义层抽象，不推荐）

### 3.4 环境警告（非阻断）

Kotlin 增量编译存在跨盘符警告（pub cache 在 C:，项目在 D:），首次构建时可能导致 daemon 崩溃。清理后重试可绕过。这是已知的 Kotlin 编译器 bug，不影响最终产物。

---

## 4. flutter analyze 状态

| 项 | 值 |
|---|---|
| ERROR | 0 |
| 总 issue | 389（全部为 warning/info） |

---

## 5. 修复建议优先级

| # | 问题 | 严重度 | 建议 |
|---|---|---|---|
| 1 | `sb_button.dart` 引用不存在的 `ThemeVars.greenBanner`/`greenSoft` | 🔴 阻断 | 在 `ThemeVars` 补充字段或修正引用 |
| 2 | CMake 缓存与 BINARY_NAME 不同步 | 🟡 已解决 | 修改 BINARY_NAME 后必须 `flutter clean` |

---

## 6. 结论

- **Windows 构建**：✅ 通过（clean 后）
- **Android 构建**：❌ 失败（`sb_button.dart` 引用了 `ThemeVars` 中不存在的字段）
- **阻断项**：需修复 `sb_button.dart:181` 的 `greenBanner`/`greenSoft` 引用后，Android 构建才能通过

---

*验证完成：DevOps（Claude Code）· 2026-08-24*
