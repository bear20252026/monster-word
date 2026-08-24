# 启动屏与应用名统一实施方案

> 项目：Monster Word（word_app）
> 版本：v2.0.0
> 日期：2026-08-24
> 前置参考：`docs/branding_assets_plan.md`（【重构15】品牌资产方案）、`docs/build_config_audit.md`（【重构10】构建审计）

---

## 一、现状分析

### 1.1 当前启动屏配置

| 平台 | 文件 | 现状 |
|------|------|------|
| Android（浅色） | `android/app/src/main/res/drawable/launch_background.xml` | 纯白色背景，无 logo，注释中预留了 `@mipmap/launch_image` 位 |
| Android（深色） | `android/app/src/main/res/drawable-v21/launch_background.xml` | 使用 `?android:colorBackground`，无 logo |
| Android 浅色主题 | `android/app/src/main/res/values/styles.xml` | `LaunchTheme` 继承 `Theme.Light.NoTitleBar`，背景指向 `@drawable/launch_background` |
| Android 深色主题 | `android/app/src/main/res/values-night/styles.xml` | `LaunchTheme` 继承 `Theme.Black.NoTitleBar`，背景指向 `@drawable/launch_background` |
| Windows | `windows/runner/main.cpp` | 窗口标题 `"word_app"`，无 splash 画面；Flutter 首帧回调 `Show()` |

### 1.2 当前应用名散布点

| 位置 | 文件 | 当前值 |
|------|------|--------|
| pubspec name | `pubspec.yaml:1` | `word_app` |
| Android label | `android/app/src/main/AndroidManifest.xml:3` | `word_app` |
| Windows 项目名 | `windows/CMakeLists.txt:3` | `project(word_app ...)` |
| Windows 二进制名 | `windows/CMakeLists.txt:7` | `set(BINARY_NAME "word_app")` |
| Windows 窗口标题 | `windows/runner/main.cpp:30` | `L"word_app"` |
| Windows FileDescription | `windows/runner/Runner.rc:93` | `"word_app"` |
| Windows InternalName | `windows/runner/Runner.rc:95` | `"word_app"` |
| Windows OriginalFilename | `windows/runner/Runner.rc:97` | `"word_app.exe"` |
| Windows ProductName | `windows/runner/Runner.rc:98` | `"word_app"` |

### 1.3 当前版本号

| 位置 | 文件 | 当前值 |
|------|------|--------|
| pubspec version | `pubspec.yaml:19` | `1.0.0+1` |
| Windows 版本 | `windows/runner/Runner.rc:66-67` | 由 Flutter 构建宏注入，fallback 为 `1,0,0,0` / `"1.0.0"` |

---

## 二、星巴克风格启动屏规格

### 2.1 设计语言

参考星巴克 App 启动屏风格：简洁、品牌色块 + 居中图标，无多余装饰。

### 2.2 配色方案

| 模式 | 背景色 | 图标色 | 色值 |
|------|--------|--------|------|
| 浅色模式 | 奶油色 | 绿色 Monster Word M 图标 | 背景 `#F2F0EB`，图标主色 `#1E3932` |
| 深色模式 | 深绿色 | 白色简化 logo | 背景 `#1E3932`，图标色 `#FFFFFF` |

### 2.3 图标规范

- **内容**：Monster Word 品牌 M 字标（简化版，非完整 logo）
- **尺寸**：Android mipmap 各密度下 120dp×120dp（即 hdpi=180px, xhdpi=240px, xxhdpi=360px, xxxhdpi=480px）
- **格式**：PNG（Android mipmap），Windows 使用 `app_icon.ico` 中嵌入或单独 splash
- **居中**：水平垂直均居中

### 2.4 Android 实现方案

#### 2.4.1 文件变动清单

```
android/app/src/main/res/
├── drawable/
│   ├── launch_background.xml          # 修改：浅色背景 + 居中 logo
│   └── splash_logo.png                # 新增：120dp 绿色 M 图标（单密度，drawable 自动缩放）
├── drawable-v21/
│   └── launch_background.xml          # 修改：同上（API 21+ ripple 兼容）
├── drawable-night/
│   └── launch_background.xml          # 新增：深色背景 + 居中白色 logo
├── values/
│   ├── colors.xml                     # 新增/修改：splash_background #F2F0EB
│   └── styles.xml                     # 保持不变
├── values-night/
│   ├── colors.xml                     # 新增：splash_background #1E3932
│   └── styles.xml                     # 保持不变
└── values-v31/
    └── styles.xml                     # 新增：Android 12+ SplashScreen API 适配
```

#### 2.4.2 launch_background.xml 改动（浅色）

```xml
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- 奶油色背景 -->
    <item android:drawable="@color/splash_background" />
    <!-- 居中 logo -->
    <item>
        <bitmap
            android:gravity="center"
            android:src="@mipmap/splash_logo" />
    </item>
</layer-list>
```

#### 2.4.3 colors.xml 新增

```xml
<!-- values/colors.xml -->
<color name="splash_background">#F2F0EB</color>

<!-- values-night/colors.xml -->
<color name="splash_background">#1E3932</color>
```

#### 2.4.4 主题配置

- `values/styles.xml`：`LaunchTheme` 保持 `Theme.Light.NoTitleBar`，背景指向修改后的 `@drawable/launch_background`
- `values-night/styles.xml`：`LaunchTheme` 保持 `Theme.Black.NoTitleBar`，背景指向 `@drawable-night/launch_background`（或通过 `@color/splash_background` 自动跟随夜间模式）

#### 2.4.5 Android 12+（API 31+）适配

Android 12 引入了系统级 SplashScreen API，**会忽略 `launch_background.xml`**。需额外处理：

```xml
<!-- 新建 values-v31/styles.xml -->
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.DeviceDefault.NoActionBar">
        <item name="android:windowSplashScreenBackground">@color/splash_background</item>
        <item name="android:windowSplashScreenAnimatedIcon">@drawable/splash_logo</item>
    </style>
</resources>
```

- 不加此文件则 Android 12+ 设备上启动屏会使用系统默认底色，与品牌配色不一致
- `values-v31` 仅对 API 31+ 生效，不影响旧版本

### 2.5 Windows 实现方案

Windows 端 Flutter 没有原生 splash screen API。窗口出现前的白底来自系统，**无需额外处理**。

仅需配合第三章改动：
- 窗口标题改为 `L"Monster Word"`（`main.cpp:30`）
- `app_icon.ico` 替换为新品牌图标（属于【重构15】图标方案范畴，不在本 spec 范围内）

---

## 三、应用名统一清单

所有需要改动的位置：

| # | 文件 | 行号 | 改动 | 改前 | 改后 |
|---|------|------|------|------|------|
| 1 | `pubspec.yaml` | 4 | `description` | `"A new Flutter project."` | `"Monster Word - 智能英语单词学习"` |
| 2 | `AndroidManifest.xml` | 3 | `android:label` | `word_app` | `Monster Word` |
| 3 | `windows/CMakeLists.txt` | 3 | `project()` 名称 | `word_app` | `MonsterWord` |
| 4 | `windows/CMakeLists.txt` | 7 | `BINARY_NAME` | `word_app` | `MonsterWord` |
| 5 | `windows/runner/main.cpp` | 30 | 窗口标题 | `L"word_app"` | `L"Monster Word"` |
| 6 | `windows/runner/Runner.rc` | 93 | FileDescription | `"word_app"` | `"Monster Word"` |
| 7 | `windows/runner/Runner.rc` | 95 | InternalName | `"word_app"` | `"MonsterWord"` |
| 8 | `windows/runner/Runner.rc` | 97 | OriginalFilename | `"word_app.exe"` | `"MonsterWord.exe"` |
| 9 | `windows/runner/Runner.rc` | 98 | ProductName | `"word_app"` | `"Monster Word"` |

**不改动 `pubspec.yaml` 的 `name: word_app`**：
- `name` 字段决定 Dart 包名，全项目 `import 'package:word_app/...'` 路径均依赖它
- 改名需全局替换所有 import，风险高、收益低
- `name` 是内部标识符，用户不可见，保留 `word_app` 不影响品牌形象

**命名规则**：
- exe 文件名：`MonsterWord`（PascalCase 无空格，避免路径含空格的脚本问题）
- 用户可见名称（`android:label`、窗口标题、ProductName、FileDescription）：`Monster Word`（带空格）
- CMake `project()` / `InternalName`：跟随 exe 名 `MonsterWord`

**exe 改名连带影响**：
- 已分发版本的桌面快捷方式指向 `word_app.exe`，改名后失效——当前用户基数小且为大版本重发布，可接受
- release 打包脚本需按新文件名 `MonsterWord.exe` 打包
- 改名后执行 `flutter clean` 清理构建缓存

---

## 四、版本号升级清单

`1.0.0+1` → `2.0.0+2`

| # | 文件 | 行号 | 改动 | 改前 | 改后 |
|---|------|------|------|------|------|
| 1 | `pubspec.yaml` | 19 | version 字段 | `1.0.0+1` | `2.0.0+2` |
| 2 | `windows/runner/Runner.rc` | 66 | fallback VERSION_AS_NUMBER | `1,0,0,0` | `2,0,0,0` |
| 3 | `windows/runner/Runner.rc` | 72 | fallback VERSION_AS_STRING | `"1.0.0"` | `"2.0.0"` |

**说明**：
- `pubspec.yaml` 中的 `2.0.0+2` 会在 Flutter 构建时自动注入 `FLUTTER_VERSION_*` 宏到 Runner.rc
- `Runner.rc` 中的 fallback 值仅在宏未定义时生效，**正常构建流程无需手改 Runner.rc 版本号**
- 为防御性一致性，可选择同步更新 fallback 值（优先级低）
- Android 端无需额外改动，`versionName` 和 `versionCode` 由 Flutter 构建系统从 pubspec 自动提取

---

## 五、实施顺序建议

1. **第一阶段：素材准备**
   - 设计 Monster Word M 简化图标（浅色/深色两版）
   - 导出各密度 PNG 和 ICO 文件

2. **第二阶段：启动屏**
   - 实现 Android 启动屏（修改 XML + 新增资源 + values-v31 适配）

3. **第三阶段：应用名统一**
   - 按清单逐文件替换 `word_app` → `Monster Word` / `monster_word`

4. **第四阶段：版本号**
   - 更新 pubspec.yaml 和 Runner.rc

5. **第五阶段：验证**
   - Android 浅色/深色模式启动屏显示正常
   - Android 12+ 设备启动屏配色正确
   - 应用列表/任务栏显示 `Monster Word`
   - Windows 窗口标题显示 `Monster Word`
   - 版本号在系统设置中显示 `2.0.0`

---

## 六、风险与注意事项

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| Windows CMake `project()` 改名 | 可能影响已有的构建缓存 | 改名后执行 `flutter clean` 再构建 |
| splash_logo 素材未就绪 | 启动屏显示空白 | 先用纯色背景方案（无 logo），素材就绪后追加 |
| 深色模式 drawable-night 目录 | 部分旧设备不支持 night qualifier | drawable-v21 已覆盖 API 21+，低于此版本占比极低 |
| Android 12+ 忽略 launch_background.xml | 启动屏配色与品牌不一致 | 新增 `values-v31/styles.xml` 使用 SplashScreen API |
| exe 改名导致旧快捷方式失效 | 已安装用户桌面快捷方式打不开 | 当前用户基数小，大版本重发布可接受；发布时附说明 |
| Runner.rc OriginalFilename 未同步 | 右键属性显示旧文件名 | 改名时一并更新 OriginalFilename |
