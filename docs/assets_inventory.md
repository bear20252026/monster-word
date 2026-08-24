# 【重构21】全量资产盘点与星巴克迁移清理预案

> 项目：Monster Word（D:\claude\work\cn_com_lange\word_app）· 盘点日期 2026-08-24
> 方法：`Get-ChildItem assets -Recurse` 全量扫描 + `grep` 引用核对（lib/ 全量只读分析）
> 背景：星巴克视觉迁移中，ThemeAnalyst 已判定**全部渐变壁纸与图片壁纸下线**
> ⚠️ 本文档仅为预案，未执行任何删除操作

---

## 一、总览

| 目录 | 文件数 | 总大小 | 说明 |
|---|---|---|---|
| `assets/fonts/` | 7 | 2.39 MB (2,507,404 B) | Inter ×4 + Charter ×3，全部在用 |
| `assets/icons/` | 9 | 9.7 KB (9,926 B) | **全部为零引用死资产** |
| `assets/wallpapers/` | 1 | 56.5 KB (57,861 B) | 仅 beach.jpg；代码另引用 3 张**不存在的图** |
| `assets/db/`（本轮排除） | 1 | 31.2 MB (32,688,627 B) | wordbook.db.gz 词库数据，仅作体积参照 |
| lottie / 音频 | 0 | 0 B | **不存在此类资产**（音频全部走网络） |

**assets/ 总计（除 db）：17 个文件，约 2.45 MB。**

---

## 二、逐项清单

### 2.1 assets/fonts/（7 项 · 2.39 MB）

| 路径 | 类型 | 大小(B) | 当前引用处(grep 结果) | 迁移后命运 |
|---|---|---|---|---|
| fonts/Inter-Regular.otf | 字体 w400 | 254,772 | pubspec(fonts.Inter)；`design_tokens.dart` Typography 全线 `fontFamily:'Inter'`（约 20 处） | **保留**（气质接近星巴克 SoDo Sans，替代方案） |
| fonts/Inter-Medium.otf | 字体 w500 | 264,176 | 同上（w500 条目） | **保留** |
| fonts/Inter-SemiBold.otf | 字体 w600 | 265,000 | 同上（w600 条目） | **保留** |
| fonts/Inter-Bold.otf | 字体 w700 | 265,580 | 同上（w700 条目） | **保留** |
| fonts/Charter-Roman.ttf | 字体 w400 | 497,668 | pubspec(fonts.Charter)；`design_tokens.dart:78,82` HeroWord display 字阶 `fontFamily:'Charter'` | **待定**（见 §5 缺口④） |
| fonts/Charter-Italic.ttf | 字体 italic | 490,796 | pubspec(fonts.Charter, style:italic)；代码内无直接 italic 引用，随家族加载 | **待定**（随 Charter 家族） |
| fonts/Charter-BoldItalic.ttf | 字体 w700 italic | 469,412 | pubspec(fonts.Charter, w700 italic)；同上 | **待定**（随 Charter 家族） |

> 备注：`card_widgets.dart:36-37` 注释明确 **Charter 缺 IPA 音标字符（ŋ/ˈ/ˌ/ː）**，音标已回退 Inter。Charter 实际只服务 HeroWord 大字排版。

### 2.2 assets/icons/（9 项 · 9.7 KB · 全零引用）

以下 9 个 SVG 在 lib/ 中**无任何一处引用**（无 `.svg` 加载代码、未接入 flutter_svg），为上一轮设计迭代遗留死资产（IconPlanner【重构8】已确认）。风格为填充式单色黑，与现行 Material Outlined 线性基调冲突：

| 路径 | 类型 | 大小(B) | 当前引用处 | 迁移后命运 |
|---|---|---|---|---|
| icons/icons_home_classroom.svg | SVG 图标 | 1,379 | **零引用** | **删除（安全）** |
| icons/icons_home_collect.svg | SVG 图标 | 1,147 | 零引用 | **删除（安全）** |
| icons/icons_home_dashboard.svg | SVG 图标 | 848 | 零引用 | **删除（安全）** |
| icons/icons_home_listen.svg | SVG 图标 | 3,104 | 零引用 | **删除（安全）** |
| icons/icons_toolbar_learn_meaning.svg | SVG 图标 | 779 | 零引用 | **删除（安全）** |
| icons/icons_toolbar_learn_spell.svg | SVG 图标 | 571 | 零引用 | **删除（安全）** |
| icons/icons_toolbar_learn_trash.svg | SVG 图标 | 1,178 | 零引用 | **删除（安全）** |
| icons/ic_arrow_long_left.svg | SVG 图标 | 524 | 零引用 | **删除（安全）** |
| icons/ic_more_h.svg | SVG 图标 | 396 | 零引用 | **删除（安全）** |

### 2.3 assets/wallpapers/ 与「10 套壁纸」真相

磁盘实际只有 1 张图；**所谓 10 套壁纸 = `lib/data/wallpaper_data.dart` 中 `WallpaperData.allWallpapers` 的 10 个预设**，其中 5 套渐变为纯代码色值（无文件）、4 套图片壁纸中 3 张文件**根本不存在**：

| # | 壁纸预设(id) | 类型 | 资产文件 | 大小(B) | 引用处 | 迁移后命运 |
|---|---|---|---|---|---|---|
| 1 | default | 纯色 #F5F5F5 | 无（代码色值） | 0 | wallpaper_data.dart:46；wallpaper_select_page.dart:72 | **改造保留**（换星巴克奶油底） |
| 2 | brand_gradient | 渐变(橙) | 无（代码色值） | 0 | wallpaper_data.dart:54 | 删除逻辑（无文件可删） |
| 3 | warm_gradient | 渐变 | 无 | 0 | wallpaper_data.dart:64 | 删除逻辑 |
| 4 | fresh_gradient | 渐变 | 无 | 0 | wallpaper_data.dart:74 | 删除逻辑 |
| 5 | ocean_gradient | 渐变 | 无 | 0 | wallpaper_data.dart:84 | 删除逻辑 |
| 6 | purple_gradient | 渐变 | 无 | 0 | wallpaper_data.dart:94 | 删除逻辑 |
| 7 | beach | 图片 | wallpapers/beach.jpg ✅存在 | 57,861 | wallpaper_data.dart:104-108（assetPath）；home_screen `_WallpaperBg`；learn_page/review_page 壁纸分支；wallpaper_select_page | **删除（需先改代码）** |
| 8 | forest | 图片 | wallpapers/forest.jpg ❌**文件缺失** | — | wallpaper_data.dart:114-118（assetPath 悬空） | 随壁纸功能一并删除逻辑 |
| 9 | city | 图片 | wallpapers/city.jpg ❌**文件缺失** | — | wallpaper_data.dart:124-128（悬空） | 同上 |
| 10 | night | 图片 | wallpapers/night.jpg ❌**文件缺失** | — | wallpaper_data.dart:134-138（悬空） | 同上 |

**⚠️ 运行时风险提示**：forest/city/night 三个 assetPath 指向不存在的文件。`home_screen.dart` 的 `DecorationImage(AssetImage(...))` **没有 errorBuilder**，若用户持久化选择了这三款壁纸，恢复会话时可能抛资产异常（wallpaper_select_page 有 errorBuilder 兜底，主界面没有）。这本身就是应尽快下线的理由。

**壁纸功能完整依赖链**（下线时需一并处理的文件）：
`main.dart`(Provider 注册) → `state/wallpaper_state.dart` → `data/wallpaper_data.dart` → 消费端：`screens/home_screen.dart(_WallpaperBg)`、`pages/learn_page.dart`、`pages/review_page.dart`、`pages/wallpaper_select_page.dart`、`pages/my_space_page.dart:188`(入口文案"外观 & 沉浸场景")、`tokens/design_tokens.dart:239`(层级枚举含 wallpaper)

---

## 三、专项核查结论

### 3.1 音频规模：assets 内为 **零**

全项目**没有任何打包音频资产**（无 .mp3/.wav/.aac/.m4a）。发音体系完全网络化：
- 单词/例句/TTS 发音经有道 `dict.youdao.com/dictvoice` 与 `audio.beingfine.cn`（七牛 CDN 兜底）在线获取；
- 下载后缓存在**应用沙盒目录**（`audio_cache`/`tts`，见 `player/audio_players.dart:237` 等），不占 APK/IPA 包体；
- 结论：无可释放的包内音频体积，迁移也不产生音频新资产需求。

### 3.2 lottie / 动画 JSON：零

无 `.json` 动画资产、未引入 lottie 依赖。星巴克风微动效建议继续用 Flutter 隐式动画实现（对齐 DESIGN.md `--iconTransition: all ease-out .2s`）。

### 3.3 assets 外的体积备注（不计入本次结论）

- `release/` 目录含 Windows 构建产物（zip 43.8 MB + 解压目录约 29 MB）——构建产物非源码资产，建议纳入 .gitignore 审查，但不属于 assets 盘点/清理范围；
- 根目录 `apple/`、`mistral.ai/` 各只有一份 DESIGN.md 文档，无图片资产。

---

## 四、可释放体积统计

| 分档 | 内容 | 体积 |
|---|---|---|
| 安全删除 | assets/icons/ 9 个 SVG | 9,926 B ≈ **9.7 KB** |
| 需确认（先改代码后删） | assets/wallpapers/beach.jpg | 57,861 B ≈ **56.5 KB** |
| 待定 | Charter 三件套 | 1,457,876 B ≈ **1.39 MB**（若新排版弃用衬线） |
| **assets 内合计（确定项）** | icons + beach | **67,787 B ≈ 66.2 KB** |
| **assets 内合计（含待定上限）** | 上述 + Charter | **≈ 1.46 MB** |

> 直白结论：**assets 包体内可释放空间很小（<1.5 MB）**。星巴克迁移的瘦身收益主要来自"少打包无用资源"的工程整洁，而非体积；真正的大头（release/ 构建产物 ~73 MB）不在 assets 管辖内。

---

## 五、清理预案

### 5.1 A 档：安全删除清单（零引用，随时可执行）

```text
assets/icons/icons_home_classroom.svg
assets/icons/icons_home_collect.svg
assets/icons/icons_home_dashboard.svg
assets/icons/icons_home_listen.svg
assets/icons/icons_toolbar_learn_meaning.svg
assets/icons/icons_toolbar_learn_spell.svg
assets/icons/icons_toolbar_learn_trash.svg
assets/icons/ic_arrow_long_left.svg
assets/icons/ic_more_h.svg
```

### 5.2 B 档：需确认清单（存在代码依赖，必须按序执行）

```text
assets/wallpapers/beach.jpg        ← 前置：完成"壁纸系统下线"重构任务
（渐变×5 与 forest/city/night 悬空引用：仅需删代码逻辑，无文件可删）
```

**B 档执行顺序（强制）**：
1. 先改代码：下线壁纸选择页与 WallpaperState/WallpaperData，清除全部 `assetPath` 引用与 `_WallpaperBg` 图片分支，沉浸场景改奶油纯色/House Green 带；
2. 再删文件：beach.jpg；
3. 同步 pubspec（见 5.3）；
4. `flutter clean && flutter pub get` 重构建，检查 `AssetManifest.bin` 不再包含已删路径，回归验证首页/学习页/复习页背景渲染。

> 顺序不能颠倒的原因：beach.jpg 是唯一"真实存在"的图片壁纸，当前可能已被用户选中并持久化（SharedPreferences `selected_wallpaper_id`）。若先删文件，老用户下次启动 `DecorationImage(AssetImage)` 无 errorBuilder 直接崩。

### 5.3 pubspec.yaml 影响点

| 声明行 | 影响 |
|---|---|
| `- assets/icons/`（目录级声明） | A 档执行后目录将变空/删除 → **必须整行移除**（Flutter 对不存在或空的资产目录会在构建时报错/告警） |
| `- assets/wallpapers/`（目录级声明） | B 档执行后同理 → **必须整行移除** |
| `- assets/db/wordbook.db.gz` | **不动**（词库核心数据） |
| fonts 段 Inter 4 条目 | **不动** |
| fonts 段 Charter 3 条目 | 仅当 §2.1 "待定"落定为删除时，**三条一并移除**（family 级联） |
| `uses-material-design: true` | **不动**（Material Icons 编译期内置，与 assets 目录无关；图标体系见 docs/icon_plan.md） |

---

## 六、缺口分析：星巴克风格还缺什么新资产

| # | 缺口 | 必要性 | 说明 |
|---|---|---|---|
| ① | **App 启动图标（launcher icon）母版** | 高 | 现 icon 未按星巴克绿系重制。需 1024×1024 母版（House Green `#1E3932` 底 + 白色 siren 风/字母标），再生成 Android/iOS/macOS/Windows 全平台尺寸。当前 android/ios 平台目录沿用默认模板 |
| ② | **启动屏（splash）视觉** | 中 | 迁移后应为奶油底 + 绿色 logo 居中；纯色可实现，无需图片资产，但需设计定稿 |
| ③ | 空状态/引导插画 | 低（可选） | 星巴克官网语言是"摄影图 + 大字排版"；若不做摄影素材，可用 House Green 线性小插画（SVG 母版）统一空状态。建议先用排版方案兜底，避免新增资产维护成本 |
| ④ | **字体决策** | 高（决策型） | 星巴克官方字体 SoDo Sans 为商业字体不可用。Inter 已是合格替身（**保留**）；真正待定的是 Charter 衬线：星巴克菜单板式偏好粗无衬线大写字距排布，若 HeroWord 改此风格，Charter 三件套（1.39 MB）可整体下线 → 需 DesignOwner 拍板 |
| ⑤ | 沉浸场景背景替代 | 低 | 图片/渐变壁纸下线后以"奶油纯色 + 深绿头部带"承接，**无需新图片资产**；如后续想要氛围纹理，再议一张绿系抽象纹理（待定，不建议本期做） |
| ⑥ | 音频资产 | 无缺口 | 网络化架构不变（§3.1） |
| ⑦ | lottie | 无缺口 | 隐式动画足够（§3.2） |

---

## 七、给后续任务的交接要点

1. **立即可做**：A 档删除（9 SVG，9.7 KB）+ 移除 `- assets/icons/` 声明行——一次提交搞定，零风险；
2. **挂依赖**：B 档（beach.jpg + wallpapers 声明行）阻塞于"壁纸系统下线"重构任务，请排期 owner 按 §5.2 顺序执行；
3. **待拍板**：Charter 字体去留（影响 1.39 MB 与 HeroWord 排版方向）；
4. **新增工作项建议**：launcher icon 母版设计与全平台生成（§6①），建议单开任务；
5. 老用户兼容：删除壁纸前务必处理 `selected_wallpaper_id` 持久化值的读取降级（回退 default 奶油底）。

---
*产出：IconPlanner · 2026-08-24 · 基于 assets/ 全量扫描（17 文件 / 2.45 MB）与 lib/ 只读引用核对*
