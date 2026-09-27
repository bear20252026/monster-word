# 【重构】Launcher 图标集成指南

> 项目：Monster Word（D:\claude\work\cn_com_lange\word_app）
> 日期：2026-08-24
> 前置：docs/launcher_icon_brief.md（图标设计 Brief）、docs/branding_assets_plan.md（工程管线配置）
> 约束：只产文档和方案；不改构建配置；中文

---

## 一、前置条件

在执行集成之前，需要确认：

| 条件 | 状态 | 说明 |
|---|---|---|
| 1024px 母版图 | ⏳ 待 PageRefactorer 产出 | `assets/branding/icon_master_1024.png` |
| 1024px 前景层 | ⏳ 待产出 | `assets/branding/icon_foreground_1024.png`（透明底，主体居中 66%） |
| flutter_launcher_icons 包 | ⏳ 待添加到 pubspec.yaml | `dev_dependencies` |
| assets/branding/ 目录 | ⏳ 待创建 | 存放母版文件 |

---

## 二、集成方案（全自动）

### 2.1 添加依赖

在 `pubspec.yaml` 的 `dev_dependencies` 中添加：

```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.14.3
```

### 2.2 添加配置

在 `pubspec.yaml` 末尾添加：

```yaml
flutter_launcher_icons:
  # 母版图路径（1024×1024，绿底白主体）
  image_path: "assets/branding/icon_master_1024.png"

  # Android
  android: true
  adaptive_icon_background: "#006241"                              # 自适应图标背景色
  adaptive_icon_foreground: "assets/branding/icon_foreground_1024.png"  # 自适应前景层

  # iOS
  ios: true
  remove_alpha_ios: true                                           # App Store 强制无透明通道

  # Windows
  windows:
    generate: true
    icon_size: 48                                                  # 生成 16-256px 多尺寸 .ico
```

### 2.3 执行生成

```bash
cd D:\claude\work\cn_com_lange\word_app

# 1. 确保母版文件存在
ls assets/branding/icon_master_1024.png
ls assets/branding/icon_foreground_1024.png

# 2. 获取依赖
flutter pub get

# 3. 一键生成全平台图标
dart run flutter_launcher_icons
```

---

## 三、各平台产出说明

### 3.1 Android

| 产出 | 路径 | 尺寸 |
|---|---|---|
| mipmap-mdpi | `android/app/src/main/res/mipmap-mdpi/ic_launcher.png` | 48×48 |
| mipmap-hdpi | `android/app/src/main/res/mipmap-hdpi/ic_launcher.png` | 72×72 |
| mipmap-xhdpi | `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png` | 96×96 |
| mipmap-xxhdpi | `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png` | 144×144 |
| mipmap-xxxhdpi | `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` | 192×192 |
| 自适应背景 | `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` | 纯色 `#006241` |
| 自适应前景 | `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` | 108dp（432px） |

> 自适应图标（Android 8.0+）：系统自动裁切为圆形/圆角方/泪滴等 mask，前景层主体必须在中央 66% 内。

### 3.2 iOS

| 产出 | 路径 | 尺寸 |
|---|---|---|
| AppIcon.appiconset | `ios/Runner/Assets.xcassets/AppIcon.appiconset/` | 15 个尺寸（20-1024px） |

> iOS 要求：无透明通道（`remove_alpha_ios: true` 已配置），系统自动 superellipse 圆角裁切。

### 3.3 Windows

| 产出 | 路径 | 尺寸 |
|---|---|---|
| app_icon.ico | `windows/runner/resources/app_icon.ico` | 16/24/32/48/64/128/256px 合一 |

> 当前文件：`windows/runner/resources/app_icon.ico`（33KB，Flutter 默认图标）。
> 工具会自动替换为新图标。

---

## 四、手动兜底方案（若 flutter_launcher_icons 失败）

### 4.1 Windows .ico 手动生成

```powershell
# 使用 ImageMagick 将 PNG 转为多尺寸 .ico
magick assets/branding/icon_master_1024.png -define icon:auto-resize=16,24,32,48,64,128,256 windows/runner/resources/app_icon.ico
```

### 4.2 Android 手动替换

```powershell
# 将母版缩放到各尺寸并复制
$src = "assets/branding/icon_master_1024.png"
$base = "android/app/src/main/res"

# 使用 ImageMagick 或 Flutter 工具缩放
magick $src -resize 48x48 "$base/mipmap-mdpi/ic_launcher.png"
magick $src -resize 72x72 "$base/mipmap-hdpi/ic_launcher.png"
magick $src -resize 96x96 "$base/mipmap-xhdpi/ic_launcher.png"
magick $src -resize 144x144 "$base/mipmap-xxhdpi/ic_launcher.png"
magick $src -resize 192x192 "$base/mipmap-xxxhdpi/ic_launcher.png"
```

### 4.3 iOS 手动替换

需要按 Xcode 的 `AppIcon.appiconset/Contents.json` 中定义的 15 个尺寸逐一导出。建议使用在线工具（如 appicon.co）或 flutter_launcher_icons 自动处理。

---

## 五、验收步骤

集成完成后，逐平台验证：

| # | 平台 | 验证方法 | 预期结果 |
|---|---|---|---|
| 1 | Android 模拟器 | `flutter run` → 查看启动器图标 | 新图标显示，无裁切/模糊 |
| 2 | Android 自适应 | 长按图标 → 查看圆形/方圆形裁切 | 主体在中央，不被裁切 |
| 3 | iOS 模拟器 | `flutter run` → 查看桌面图标 | 新图标显示，无透明边 |
| 4 | Windows 桌面 | `flutter build windows` → 查看 exe 图标 | 新图标显示 |
| 5 | Windows 任务栏 | 运行 exe → 查看任务栏图标 | 16px 清晰可辨 |
| 6 | 启动屏和谐 | 图标与启动屏 #F2F0EB 画布并列 | 品牌锚点统一 |

---

## 六、当前状态

| 项目 | 状态 | 备注 |
|---|---|---|
| 母版图 | ⏳ 待生成 | PageRefactorer 负责 |
| 前景层 | ⏳ 待生成 | 由母版去底重排 |
| pubspec 配置 | 📝 已有方案 | 见 §2.2，待写入 |
| flutter_launcher_icons | ⏳ 待安装 | `dart run` 执行 |
| 集成执行 | ⏳ 待母版就绪 | 自动化一键完成 |
