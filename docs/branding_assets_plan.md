# 【重构15】品牌资产统一方案：图标 / 启动屏 / 应用名 / 版本

> 依据：【重构10】构建配置审计（docs/build_config_audit.md）
> 性质：**方案文档，本文不改动任何图标/XML/配置**；所有"改法"仅供后续实施任务执行。
> 目标：把发布面从 Flutter 模板默认状态一次性切换到「Monster Word」绿色系咖啡风品牌。

---

## 1. 应用图标方案

### 1.1 设计规格

| 项 | 规格 |
|---|---|
| 风格 | 绿色系咖啡风：主底 **#006241**（星巴克绿），渐变辅助 **#00754A**，可叠加奶油色 #F2F0EB 高光 |
| 主体元素 | 白色 **M 字母**（Monster Word 首字母），融入怪物元素建议：M 的笔画端点做圆角触角/单眼小怪物剪影，保持远距离可辨识 |
| 形状 | Android 自适应图标需安全区：图形集中在画布中央 66% 内 |
| 母版 | 1024×1024 PNG/SVG 源文件，存放建议 `assets/branding/icon_master_1024.png` + 前景层单独一份 |

### 1.2 各平台尺寸清单

| 平台 | 位置 | 尺寸 | 现状 |
|---|---|---|---|
| Windows | windows/runner/resources/app_icon.ico | 单 .ico 内含 **16/24/32/48/64/128/256** 多尺寸 | ❌ Flutter 默认图标 |
| Android | android/app/src/main/res/mipmap-*/ic_launcher.png | mdpi 48 / hdpi 72 / xhdpi 96 / xxhdpi 144 / xxxhdpi 192 | ❌ Flutter 默认图标 |
| Android（建议新增） | mipmap-anydpi-v26 自适应图标 | 前景 108dp（内容区 72dp）+ 背景纯色 #006241 | 无 |
| iOS | ios/Runner/Assets.xcassets/AppIcon.appiconset/ | 模板 Contents.json 已定义全套 15 个尺寸（20~60 @1x-3x）+ App Store 1024 | ❌ Flutter 默认图标 |

### 1.3 工具建议

**首选：flutter_launcher_icons 自动化生成**（Android + iOS + Windows 一条龙）：

```yaml
# pubspec.yaml
dev_dependencies:
  flutter_launcher_icons: ^0.14.3

flutter_launcher_icons:
  image_path: "assets/branding/icon_master_1024.png"
  android: true
  adaptive_icon_background: "#006241"        # 自适应图标背景
  adaptive_icon_foreground: "assets/branding/icon_foreground_1024.png"
  ios: true
  remove_alpha_ios: true                     # App Store 要求无透明通道
  windows:
    generate: true
    image_path: "assets/branding/icon_master_1024.png"
    icon_size: 48                            # 运行后自动产出多尺寸 .ico 覆盖 app_icon.ico
```

执行 `dart run flutter_launcher_icons` 即可全平台替换。辅助工具：
- .ico 兜底转换：ImageMagick `magick icon.png -define icon:auto-resize=16,24,32,48,64,128,256 app_icon.ico`
- 设计稿：Figma 绘制母版 → 导出 1024 PNG

---

## 2. 启动屏方案

### 2.1 配色

| 模式 | 现状 | 改为 |
|---|---|---|
| 浅色 | @android:color/white 纯白 | **奶油色 #F2F0EB** |
| 夜间 | 同样白色（values-night/styles.xml 的 LaunchTheme 未差异化） | **深绿 #1E3932** |
| 中央 logo（可选增强） | 无 | 简版 M 怪物 logo 居中 |

### 2.2 XML 改法（实施时参考）

```xml
<!-- android/app/src/main/res/drawable/launch_background.xml （浅色） -->
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item>
        <shape><solid android:color="#F2F0EB"/></shape>
    </item>
</layer-list>

<!-- 新建 android/app/src/main/res/drawable-night/launch_background.xml （夜间） -->
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item>
        <shape><solid android:color="#1E3932"/></shape>
    </item>
</layer-list>
```

带居中简版 logo 的写法：

```xml
<layer-list ...>
    <item android:drawable="@color/brand_cream"/>   <!-- 颜色建议收进 values/colors.xml -->
    <item android:gravity="center" android:width="120dp" android:height="120dp"
          android:drawable="@drawable/splash_logo"/>
</layer-list>
```

注意事项：
- values-night 已存在（LaunchTheme/NormalTheme），夜间启动屏走 drawable-night 目录即可生效；
- **Android 12+ 会忽略 launch_background.xml**，改用系统 SplashScreen API：如需覆盖，另在 `values-v31/styles.xml` 加 `windowSplashScreenBackground`（同 #F2F0EB / 夜间 #1E3932），否则系统默认底色可能与品牌不符；
- iOS 侧 LaunchImage.imageset 目前是模板空白图，可选同步换一张奶油色底图（低优先级）；
- Windows 无传统启动屏，窗口出现前的白底来自系统，无需处理。

---

## 3. 应用名统一："word_app" → "Monster Word"

### 3.1 修改点清单

| # | 文件 | 现值 | 改为 |
|---|---|---|---|
| 1 | windows/runner/main.cpp | `Create(L"word_app")` | `Create(L"Monster Word")` |
| 2 | windows/CMakeLists.txt BINARY_NAME | `"word_app"` → 产物 `word_app.exe` | 建议 `"MonsterWord"` → `MonsterWord.exe`（见 3.2 说明） |
| 3 | windows/runner/Runner.rc | ProductName / FileDescription = "word_app" | 均 "Monster Word"；OriginalFilename 随 exe 名改为 MonsterWord.exe |
| 4 | android/app/src/main/AndroidManifest.xml | `android:label="word_app"` | `android:label="Monster Word"` |
| 5 | pubspec.yaml description（顺带） | "A new Flutter project." | 一句中文产品简介 |

注：pubspec 的 Dart 包名 `name: word_app` 牵连全部 import 路径，**不建议本次改名**（收益低、风险高）；桌面快捷方式显示名与开始菜单名取自 FileDescription/exe 名，改完上述即正确。

### 3.2 exe 改名的连带影响

若 BINARY_NAME 从 word_app 改为 MonsterWord/Monster Word：

1. **用户旧快捷方式失效**：已分发版本的桌面/开始菜单快捷方式指向 word_app.exe，改名后全部打不开，需要重新安装或重建快捷方式——当前用户基数小、且本次是大版本重发布，影响可接受；
2. **CI/打包脚本引用**：现有 `.github/workflows/build.yml` 只跑 `flutter build windows --release`，未硬编码 exe 名 ✓；但 release 打 zip 步骤（目前手工）以后要按新文件名打包；
3. **exe 文件名含空格的坑**：`BINARY_NAME "Monster Word"` 会产出 `Monster Word.exe`，路径带空格对脚本/命令行不友好 → **推荐 exe 用 `MonsterWord`（无空格），展示名交给 Runner.rc FileDescription 和 android:label 承担**；
4. Runner.rc 的 OriginalFilename 若忘记同步，右键属性会显示旧名（不影响运行但显得不专业）。

---

## 4. 版本策略：1.0.0+1 → **2.0.0+2**

理由：

1. **用户感知层面的 breaking 变化**：品牌重塑（名称/图标/配色）+ UI 重构属于大改版，语义化版本应升 major；
2. **避免升级检测混乱**：历史产物已占用 v1.0（原应用_v1.0_Windows_x64.zip），同号不同内容会让"是否更新过"无从判断；2.0.0 与旧包一刀切开；
3. **build number +2**：保证大于任何已分发包的 build号，为未来接入应用内更新检测留好单调递增空间；
4. 心理层面：2.0 明确传达"这是新产品"，帮助切断与原应用时期的联想。

实施：仅改 pubspec.yaml `version: 2.0.0+2`，Windows 版本资源由 flutter 构建自动注入 Runner.rc，无需手改。

---

## 5. 商标风险处置：历史产物原应用

审计确认 release/ 下有 `原应用_v1.0_Windows_x64.zip` 及同名目录。原应用是在册的知名背单词 App 商标。

**风险评估**：商标侵权风险主要产生于**商业性使用造成公众混淆**。该 zip 仅存在于本地开发机、从未对外分发 → 当前无实际风险，但拖得越久越容易被误传出去。

**处置建议**（本地归档即可，不必删除）：

```powershell
New-Item -ItemType Directory -Path release\_archive
Move-Item "release\原应用_v1.0_Windows_x64.zip" "release\_archive\word_app_legacy_v1.0_20260822.zip"
Move-Item "release\原应用" "release\_archive\word_app_legacy_v1.0_20260822"
```

- 改名去掉原应用字样，保留日期便于回溯；
- 移入 `_archive` 子目录与新产物隔离，防止误上传/误发；
- 后续正式发布流程中加一条纪律：**发布包命名一律 `MonsterWord_vX.Y.Z_Windows_x64.zip`**，杜绝品牌词混入。

---

## 6. 音频库冗余裁决：保留 audioplayers，移除 just_audio

代码证据（grep lib/ 全量结果）：

| 库 | 使用面 |
|---|---|
| **audioplayers** | 核心播放层 lib/player/audio_players.dart（BBAudioPlayer / PhoneticAudioPlayer / SentenceAudioPlayer / TextAudioPlayer 四个类全部基于它，注释明示"Flutter 中统一使用 audioplayers"）；另有 dictionary / learn / review / search / spell_check / spell_session / word_machine / word_detail 等 **8+ 个页面直接调用** |
| just_audio | **仅 lib/lock/lock_media.dart 一处**（65 行小文件），API 使用面极窄：setUrl / setFilePath / play / pause / stop / dispose |

决定性因素——**Windows 桌面支持**：本项目主战场是 Windows（release 产物里就是 audioplayers_windows_plugin.dll）。audioplayers 官方提供 Windows 实现；just_audio 官方无 Windows 端（需第三方 just_audio_windows 补位）。锁屏模块未来若上 Windows，just_audio 反而是短板。

**替换成本评估：极低**

lock_media.dart 全部逻辑可直接委托给现有播放层（或直接换成 audioplayers API），预估 ≤30 行改动：

```dart
// 方案A（推荐）：复用现有封装
final player = BBAudioPlayer();
await player.play(url);            // 网络 URL
await player.playFile(localPath);  // 本地文件
// 方案B：直接用 audioplayers
await _player.play(UrlSource(url));
await _player.play(DeviceFileSource(path));
```

随后从 pubspec 删除 `just_audio` 即可。顺带观察（不属本任务范围）：8 个页面各自 `AudioPlayer()` 裸 new 的写法，可在重构中收敛到 audio_players.dart 单例层。

---

## 实施顺序建议（供排期参考）

1. 🔴 先删 just_audio、补 INTERNET 权限（功能正确性）
2. 🟠 图标三平台一次替换（flutter_launcher_icons）
3. 🟠 应用名四处统一 + 启动屏配色
4. 🟡 version 2.0.0+2、description 更新
5. 🟢 release/ 历史产物归档改名

*制定人：BuildScout（【重构15】）· 2026-08-24 · 本文为方案，未改动任何实际资产*
