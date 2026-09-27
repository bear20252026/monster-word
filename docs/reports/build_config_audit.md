# 【重构10】构建与发布配置审计报告

> 审计范围：`pubspec.yaml` / `windows/` / `android/` / `release/`
> 方式：只读检查，未执行任何构建，未修改任何文件。
> 结论先行：**发布面（名称、图标、启动屏、签名、权限）几乎全部停留在 Flutter 模板默认状态**，且 `release/` 中存在使用旧品牌原应用的历史产物，需在重构收尾时统一清理与替换。

---

## 1. pubspec.yaml

### 1.1 版本与环境

| 项 | 值 | 说明 |
|---|---|---|
| name | word_app | 包名 |
| description | `"A new Flutter project."` | ⚠️ 仍是模板默认描述 |
| version | 1.0.0+1 | ⚠️ 与旧产物 zip 的 v1.0 同号 |
| environment.sdk | `^3.13.0` | 仅约束 Dart SDK；**未显式声明 flutter 版本区间** |

Dart ^3.13 对应较新的 stable Flutter 分支；团队各机器 Flutter 版本若不一致，建议补上 `flutter:` 约束。

### 1.2 依赖清单及用途推测

| 包 | 用途推测 |
|---|---|
| cupertino_icons | iOS 风格基础图标 |
| sqflite + sqflite_common_ffi | SQLite 词库读写；ffi 变体用于 **Windows 桌面端**支持 |
| path_provider / path | 获取应用文档目录、拼接数据库路径 |
| archive | 解压内置词库 `wordbook.db.gz`（gz 压缩包） |
| provider | 全局状态管理 |
| shared_preferences | 本地键值设置（进度/偏好） |
| audioplayers | 音频播放（Windows 插件已随包打进 release 产物，推测用于发音） |
| just_audio | 音频播放（**与 audioplayers 功能重叠，疑似冗余依赖**） |
| flutter_svg | 渲染 `assets/icons/*.svg` 自定义图标 |
| crypto | 哈希（可能用于数据校验/缓存键） |
| http + http_parser | HTTP 请求与响应解析 |
| encrypt | 加解密（用途待确认） |
| webview_flutter | 内嵌 WebView |

⚠️ **audioplayers 与 just_audio 并存**：两个音频库功能重叠，重构时建议择一保留，可减小包体并避免音频焦点冲突。

dev_dependencies：仅 `flutter_test` + `flutter_lints ^6.0.0`（标准模板，无异常）。

### 1.3 字体与主题相关（重点）

- ❌ **没有 google_fonts** —— 字体全部本地打包，不联网加载。
- 本地字体声明（`assets/fonts/` 下 7 个文件均存在 ✓）：
  - **Inter**：Regular / Medium / SemiBold / Bold（.otf）
  - **Charter**：Roman / Italic / BoldItalic（.ttf）
- 若新设计稿更换字体：需同时替换 `assets/fonts/*` 文件与 pubspec 的 family 声明，无网络字体兜底。
- assets：`assets/db/wordbook.db.gz`、`assets/icons/`（9 个 SVG）、`assets/wallpapers/`（目前仅 `beach.jpg` 一张壁纸）。

---

## 2. windows/ 目录

| 项 | 现状 | 判定 |
|---|---|---|
| 可执行名 BINARY_NAME | `word_app`（windows/CMakeLists.txt） | ⚠️ 通用占位 |
| 窗口标题 main.cpp | `L"word_app"` | ⚠️ 通用占位 |
| ProductName / FileDescription | `word_app`（Runner.rc） | ⚠️ 未品牌化 |
| CompanyName / Copyright | `com.monsterword` / `(C) 2026 com.monsterword` | 已指向 monsterword 命名空间 |
| OriginalFilename | `word_app.exe` | 需随改名同步 |
| 图标 resources/app_icon.ico | **33,772 字节，与 Flutter 默认模板图标完全一致** | ❌ **仍是默认蓝色 Flutter 图标，未更换** |

版本号由 flutter 工具从 pubspec 的 `version` 自动注入 Runner.rc（FILEVERSION/PRODUCTVERSION），无需手改。

---

## 3. android/ 目录

| 项 | 现状 | 判定 |
|---|---|---|
| applicationId / namespace | `com.monsterword.word_app` | ✓ 已定制 |
| 应用名 android:label | `"word_app"`（AndroidManifest.xml） | ⚠️ 桌面显示名为通用占位 |
| minSdk / targetSdk | `flutter.minSdkVersion` / `flutter.targetSdkVersion`（跟随 Flutter 默认） | 中性，可接受 |
| launcher 图标 | 5 个密度的 mipmap `ic_launcher.png`（442–1443 字节） | ❌ **全部为默认 Flutter 小图标** |
| 启动屏 launch_background.xml | `@android:color/white` 纯白 | ❌ 默认白底，无品牌色 |
| 夜间模式 values-night/styles.xml | LaunchTheme 同样白色 windowBackground | ⚠️ 未做夜间差异化 |
| release 签名 | `signingConfig = signingConfigs.getByName("debug")`，模板 TODO 未替换 | ❌ **正式发布必须换 keystore** |

### ⚠️ 高风险发现：主 Manifest 无任何权限声明

- 主 `AndroidManifest.xml` **没有 `<uses-permission>`**；
- `INTERNET` 权限只在 `debug/AndroidManifest.xml` 中（Flutter 模板行为，仅调试生效）；
- 项目使用了 `http` / `webview_flutter` → **当前配置打出的 release APK 所有联网功能会直接失败**。
- 重构引入在线功能前必须在主 Manifest 补：
  `<uses-permission android:name="android.permission.INTERNET"/>`

---

## 4. release/ 目录历史产物（只列出，未动）

```
release/
├── 原应用_v1.0_Windows_x64.zip          （约 43.7 MB，2026-08-22 构建）
└── 原应用/
    ├── word_app.exe                        （注意：exe 名仍是 word_app，外层目录却叫原应用）
    ├── flutter_windows.dll / sqlite3.dll / dartjni.dll
    ├── audioplayers_windows_plugin.dll     （印证 audioplayers 在 Windows 端实际启用）
    └── data/
        ├── app.so / icudtl.dat
        └── flutter_assets/
            ├── wordbook.db.gz              （约 32.7 MB 词库）
            ├── MaterialIcons-Regular.otf / CupertinoIcons.ttf
            └── shaders/
```

观察：

1. 产物命名混乱：zip/目录用旧品牌原应用，exe 却是通用 `word_app.exe`。
2. 原应用是知名第三方背单词 App 的名称，**继续沿用存在商标/混淆风险**，重构后应彻底弃用。
3. 该产物的 FontManifest 只含 Material/Cupertino 图标字体，**未见 Inter/Charter** → 构建于字体声明加入之前，属过期产物，不可作为当前基线参考。

---

## 5. 风险清单：重构后需同步更新的构建侧资产

按优先级排列：

| # | 风险项 | 建议 |
|---|---|---|
| 1 | 🔴 Android 主 Manifest 缺 `INTERNET` 权限，release 包联网必挂 | 引入网络功能前立即补权限声明 |
| 2 | 🔴 Android release 签名仍是 debug keystore | 正式发布前生成正式 keystore 并配 signingConfig |
| 3 | 🟠 Windows 图标 `app_icon.ico` 仍为默认 Flutter 图标 | **换成绿色系咖啡风新 logo**，导出多尺寸 .ico 覆盖原文件 |
| 4 | 🟠 Android launcher 图标 5 个密度全为默认 | 用新 logo 通过 flutter_launcher_icons 一键生成全套 mipmap |
| 5 | 🟠 启动屏纯白无品牌色 | 更新 `launch_background.xml` 为品牌底色，并同步 values-night 夜间版 |
| 6 | 🟡 应用名四处分散：窗口标题(main.cpp)、exe 名(BINARY_NAME)、Runner.rc 元数据、android:label | 统一为新品牌名（如 Monster Word / 中文名），一次改齐 |
| 7 | 🟡 pubspec `description` 仍是模板文案、`version 1.0.0+1` 与旧 zip 同号 | 更新描述；版本 bump（如 1.1.0+2 或 2.0.0+2）避免升级检测冲突 |
| 8 | 🟡 audioplayers 与 just_audio 冗余并存 | 择一保留 |
| 9 | 🟡 无 google_fonts，字体本地打包 Inter+Charter | 新设计如换字体需同步替换 assets/fonts 与 pubspec 声明 |
| 10 | 🟢 release/ 旧产物带原应用商标风险且已过期 | 新版打包后归档或删除旧产物，勿混入发布渠道 |

---

*审计人：BuildScout（【重构10】）· 2026-08-24*
