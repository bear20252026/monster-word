# 【重构27】Launcher 图标设计 Brief —— 怪物M × 咖啡绿 两方案

> 项目：Monster Word（D:\claude\work\cn_com_lange\word_app）· 2026-08-24
> 用途：交给图标设计师 / AI 生图工具的**完整需求书**（本文档不含成品图，出图为下一步）
> 配套文档：`docs/branding_assets_plan.md`（工程管线：flutter_launcher_icons 配置与启动屏 XML 已定稿）、`DESIGN.md`（星巴克视觉规范）
> ⚠️ 色名勘误：任务书所称 "House Green #006241"，按 DESIGN.md 实际定义为 **Starbucks Green `#006241`**（历史品牌绿）；House Green 实为 `#1E3932`（近黑深绿）。本 Brief 统一使用 DESIGN.md 的正确命名。

---

## 一、一句话定位

**在星巴克绿的方寸之间，放一只白色的"怪物"。**
App 名 Monster Word：学习入口要有一点点怪趣的亲和力，底色必须是星巴克品牌绿的"正统感"——两者反差就是记忆点。

---

## 二、色彩规范

| 角色 | 色值 | 用途 | 备注 |
|---|---|---|---|
| **底色·主推** | **Starbucks Green `#006241`** | 图标背景满幅纯色 | 品牌主信号色，与星巴克 siren logo 同源绿；自适应图标背景层同此值 |
| 底色·备选 | Green Accent `#00754A` | 若主推绿被否 | 更亮更活泼，是 App 内 CTA/Frap 按钮色；作为图标底会稍"轻" |
| ~~不推荐~~ | House Green `#1E3932` | ✗ | 近黑深绿，做图标底会丢失"绿色识别度"，只留给 App 内 feature band |
| 主体色 | Pure White `#FFFFFF` | 字母/图形主体 | 对 `#006241` 对比度 ≈ **7.4 : 1**（WCAG AAA 级），48px 小尺寸下依然锐利 |
| 点缀色（可选） | Gold `#CBA258` | 仅方案 B 变体的"星星"元素 | DESIGN.md 规定金色只属于 Rewards 仪式感，**默认不用**，若用也 ≤ 图形面积 5% |

硬性规则：
- **扁平、零渐变、零投影、零描边、零纹理**（DESIGN.md："flat … never shouting"）；
- 底色满幅不透明（iOS App Store 强制无 alpha 通道，管线已配 `remove_alpha_ios: true`）；
- 除方案 A 的字母 "M"、方案 B 卡片上的单字母 "Aa" 外，**不得出现任何其他文字**。

---

## 三、构图与安全边距

| 平台裁切方式 | 要求 | 安全区规则 |
|---|---|---|
| Android 自适应图标 | 启动器会裁成圆形/圆角方/泪滴等多种 mask | 前景主体必须落在画布**中央 66%** 内（108dp 画布，72dp 可见区）；四边各留 ≥17% 空底 |
| iOS | 系统自动 superellipse 圆角 | 四边各留 ≥10% 边距，主体不出血 |
| Windows .ico | 方形容器不裁切 | 但最小 16px 使用场景 → 主体笔画必须粗壮 |

统一执行标准：**1024 母版中，主体外接框控制在中央 ~600px（58%）以内**；该母版可直接同时喂给三条平台管线。

---

## 四、创意方案

### 方案 A：字母 M 怪物化（主推）

**概念**：Monster Word 的首字母 M 天然长得像一对獠牙/兽脸轮廓——把圆角无衬线的粗体大写 M 直接"怪物化"，一形双关。

- **字形**：几何圆角无衬线（参照 Inter Black / Nunito ExtraBold 的浑圆度），字重 ≥800，笔画端点全圆头；
- **主体**：白色 M 居中，高度约占安全区的 80%；
- **怪趣点缀（二选一，不得叠加）**：
  - **A1 眼睛版（亲和向）**：两只圆形白色眼睛坐在 M 左右双峰的峰顶上，瞳孔为底色绿的小圆点，微微内八——"好奇地看着你在学什么"；
  - **A2 獠牙版（怪物的向）**：保持纯 M 不加眼，仅在 M 中央 V 谷底部悬一颗小三角獠牙，V 谷本身读作张开的嘴；
- **为什么主推**：单字母在小尺寸辨识度天花板最高；怪物梗直接来自产品名；后续启动屏"简版 M 居中 logo"（branding_assets_plan §2.1）可无缝复用同一图形。

### 方案 B：咖啡杯 × 单词卡融合

**概念**：把星巴克的 to-go 杯和背单词的闪卡合成一个物件——**杯身即单词卡**，隐喻"背单词像喝咖啡一样，是每天的小确幸仪式"。

- **杯体**：正面平视的外带咖啡杯剪影（杯盖横条 + 梯形杯身），全白填充；
- **融合细节**：杯身中央印一个**大号绿色 "Aa"**（底色绿做墨色），或退化为两条短横线示意"待填写的单词"；杯身可整体微倾 5–8° 增添活泼感；
- **热气**：杯口上方**一条**粗圆头 S 形蒸汽曲线（白色），最多一条，不许变成三缕缭绕；
- **图形预算**：总元素数 ≤ 3（杯 + 卡面内容 + 蒸汽），超了就删；
- **风险提示**：杯子造型的横向宽度大于 M，在圆形 mask 下更容易顶边，构图时杯宽控制在安全区 70% 以内。

### 两方案共同禁区

✗ 渐变/阴影/高光/长投影　✗ 拟物质感（陶瓷反光、拉花）　✗ 细线条（<主笔画 1/4 粗度的线都会在 48px 消失）　✗ 怪物全身像（太复杂）　✗ 多余文字/水印

---

## 五、AI 生图提示词规格（可直接复制使用）

> 通用参数：1024×1024 · PNG · 每方案建议出 4–8 张候选。
> 提示词中的色值允许 AI 有偏差，**后期必须用取色器校回精确 hex**（或只让 AI 画白主体，背景色由 Figma 重铺）。

### 5.1 方案 A1（M + 眼睛）正向 Prompt

```text
Flat vector app icon design: a single bold rounded uppercase letter "M" in
pure white, playful monster character style, two small round white eyes
resting on top of the two peaks of the M with tiny green pupils, centered
on a solid Starbucks green background (#006241), minimal geometric mascot
logo, thick uniform rounded strokes, flat design, solid colors only,
generous empty margins around the subject, square format, clean vector
shapes, starbucks-inspired green palette
```

### 5.2 方案 A2（M + 獠牙）正向 Prompt

```text
Flat vector app icon design: a single bold rounded uppercase letter "M" in
pure white whose central valley reads as an open mouth with one small white
fang hanging from the bottom vertex, subtle monster silhouette, centered on
a solid dark green background (#006241), minimal geometric logo mark, thick
uniform rounded strokes, flat design, solid colors only, generous margins,
square format, starbucks-inspired green palette
```

### 5.3 方案 B（咖啡杯 × 单词卡）正向 Prompt

```text
Flat vector app icon design: a minimalist white takeaway coffee cup
silhouette fused with a word flashcard, the cup body is a slightly tilted
white card printed with a large green letters "Aa", one thick rounded steam
swirl rising above the lid, centered composition on a solid green background
(#006241), starbucks-inspired green palette, minimal geometric flat
illustration, solid colors only, generous empty margins, square format
```

### 5.4 负向 Prompt（三方案通用）

```text
no gradients, no shadows, no glow, no outline strokes, no 3D render,
no photorealism, no texture, no paper grain, no latte art, no realistic
cup details, no full monster body, no extra text, no words, no letters
besides the specified ones, no watermark, no signature, no thin lines,
no background pattern, no border frame, no transparent background
```

### 5.5 出图后加工要求（给精修环节）

1. 取色校正：背景精确到 `#006241`（或选定备选 `#00754A`），主体提纯至 `#FFFFFF`；
2. 按第三章安全区重排，导出两个母版文件：
   - `assets/branding/icon_master_1024.png`（满幅绿底 + 白主体）
   - `assets/branding/icon_foreground_1024.png`（**透明底**，仅白主体，缩至中央 66%，供 Android 自适应前景层）
3. 单色健壮性自检：整图转灰度/转纯黑剪影，主体轮廓仍须完整可读。

---

## 六、尺寸产出矩阵

| # | 目标产物 | 路径 | 尺寸 | 生成方式 |
|---|---|---|---|---|
| 0 | **母版** | `assets/branding/icon_master_1024.png` | 1024×1024 | 设计/AI 直出（唯二手工件 ①） |
| 0b | **自适应前景** | `assets/branding/icon_foreground_1024.png` | 1024×1024（主体居中 66%，透明底） | 由母版去底重排（唯二手工件 ②） |
| 1 | Android mipmap-mdpi | `android/.../mipmap-mdpi/ic_launcher.png` | 48 | ✅ flutter_launcher_icons 自动 |
| 2 | Android mipmap-hdpi | 同上 hdpi | 72 | ✅ 自动 |
| 3 | Android mipmap-xhdpi | 同上 xhdpi | 96 | ✅ 自动 |
| 4 | Android mipmap-xxhdpi | 同上 xxhdpi | 144 | ✅ 自动 |
| 5 | Android mipmap-xxxhdpi | 同上 xxxhdpi | 192 | ✅ 自动 |
| 6 | Android 自适应背景 | anydpi-v26 color | 纯色 `#006241` | ✅ 自动（`adaptive_icon_background`） |
| 7 | Android 自适应前景 | anydpi-v26 foreground | 108dp（xxxhdpi 下 432px，由 1024 前景缩放） | ✅ 自动（`adaptive_icon_foreground`） |
| 8 | iOS AppIcon.appiconset | 20/29/40/60/76/83.5 @1x–3x + App Store | 15 个尺寸，最大 1024 | ✅ 自动（`ios: true`，注意 `remove_alpha_ios`） |
| 9 | Windows `app_icon.ico` | `windows/runner/resources/app_icon.ico` | **16/24/32/48/64/128/256** 七档合 1 个 .ico | ✅ 自动（`windows.generate`）；兜底：ImageMagick `magick icon.png -define icon:auto-resize=16,24,32,48,64,128,256 app_icon.ico` |
| 10 | Web favicon / macOS（可选） | web/icons、macos Assets | 192/512 等 | ✅ 自动，本期可不做 |

> 结论：除 1024 母版与 432 级前景层两件手工件外，**其余全部可由 `flutter_launcher_icons: ^0.14.3` 一键生成**（pubspec 配置已在 `docs/branding_assets_plan.md` §1.3 定稿，无需重复编写）。执行命令：`dart run flutter_launcher_icons`。

---

## 七、验收标准（量化，逐条打勾）

| # | 标准 | 通过线 |
|---|---|---|
| 1 | **48px 辨识** | 缩至 48×48 裸眼即可说出主体是"M/怪物"或"咖啡杯"，边缘不糊、元素不粘连 |
| 2 | 16px 极限（Windows 任务栏/favicon） | 至少呈现"绿方块 + 一个白色粗形状"，形状可辨且不碎裂 |
| 3 | 对比度 | 白主体 vs 绿底 ≥ 7:1（`#FFFFFF`/`#006241` = 7.4:1 ✓） |
| 4 | 色彩纪律 | 取色器实测背景 = 精确 hex；全图无第二色相（金饰变体除外且 ≤5% 面积） |
| 5 | 扁平合规 | 无渐变/阴影/描边/纹理；放大 400% 无噪点 |
| 6 | 安全区合规 | Android 圆形 mask 模拟下主体四边不被裁切；iOS 圆角模拟下不出血 |
| 7 | **启动屏和谐** | 图标置于奶油 `#F2F0EB` 画布（浅色启动屏）与深绿 `#1E3932` 画布（夜间启动屏）上各摆一版 mock：绿底白标在两种环境都形成干净的品牌锚点，无脏色冲突；启动屏中央简版 logo 与图标主体同源同形 |
| 8 | alpha 合规 | 母版满幅不透明；iOS 产物经 `remove_alpha_ios` 校验无透明通道 |
| 9 | 单色健壮 | 转纯黑剪影测试：主体轮廓完整、无断笔 |
| 10 | 同源复用 | 方案胜出后，其主体可无损简化为 120dp 启动屏居中小 logo |

---

## 八、交付流程

1. **本 Brief 定稿**（本文档）→
2. 队长按 §五 prompts 生图，每方案 4–8 候选 →
3. 用户/队长圈选 1 个方向 → Figma 精修（校色 + 安全区 + §5.5 两个母版导出）→
4. 按 §六矩阵跑 `dart run flutter_launcher_icons` →
5. 三平台真机/桌面验收（§七逐条打勾，重点拍 48px 桌面与启动屏合影）→
6. 回写 `docs/branding_assets_plan.md` 现状表（❌默认图标 → ✅新品牌图标）。

---
*产出：IconPlanner · 2026-08-24 · 依据 DESIGN.md 四绿体系与 branding_assets_plan 工程现状 · 未生成任何图片*
