# 深色模式与皮肤系统兼容策略

> 【重构5】分析报告 · 2026-08-24 · 只读代码分析产出
>
> 分析对象：`lib/theme/skin_system.dart`、`lib/state/wallpaper_state.dart`、`lib/data/wallpaper_data.dart` 及全库暗色模式现状
>
> 对照规范：根目录 `DESIGN.md`（星巴克视觉规范）

---

## 一、现状盘点

### 1.1 皮肤系统工作机制

架构是一条「ChangeNotifier → InheritedWidget → 语义令牌」的链路：

```
SkinSystem(ChangeNotifier)          // 持有 _themeId，setTheme() 触发通知
  └─ SkinProvider(InheritedWidget)   // 在 main.dart 顶层包裹
       └─ context.skin → ThemeVars   // 页面取语义化颜色令牌
```

- **令牌层**：`ThemeVars` 定义约 30 个语义化颜色令牌（`pageBg`、`cardBg`、`textPrimary`、`textSecondary`、`accent`、`wallpaperScrim` 等），并含 glass / wallpaper / quiz / vip 四组场景令牌。**这个令牌架构本身是健康的**，问题出在预设内容与配套机制。
- **预设层**：目前共 **3 套皮肤**：

| 皮肤 ID | 名称 | 画布 pageBg | 状态栏亮度 | 备注 |
|---|---|---|---|---|
| `bright` | 明亮 | `#F5F5F5` | Brightness.dark | 硬编码默认值 |
| `dark` | 深邃 | `#212532`（深蓝灰） | Brightness.light | 原版深色背景 |
| `pure_black` | 极夜 | `#040404` | Brightness.light | OLED 向 |

### 1.2 已发现的问题（现状即带伤）

1. **皮肤选择不持久化**：`_themeId = 'bright'` 为硬编码初始值，无 SharedPreferences 写入。用户每次重启 App 都被重置回"明亮"。
2. **「跟随系统」开关是假的**：`appearance_page.dart` 中开关为 `value: true, onChanged: (v) {}`——纯 UI 摆设，没有任何 `platformBrightness` 监听或 `themeMode` 接线。
3. **状态栏亮度语义过载（隐患）**：`ThemePreset.statusBarBrightness` 被同时当作 `MaterialApp.theme.brightness` 使用。结果是"明亮"主题给 `ColorScheme.fromSeed` 传入的是 `Brightness.dark`——亮色皮肤生成暗色 ColorScheme，语义反转，后续做真·暗色模式时必然踩坑。
4. **壁纸初始值闪变**：`WallpaperState` 初始 `_current = beachWallpaper`（沙滩图），持久化值加载完成前会先渲染沙滩壁纸。
5. **双令牌残留**：`lib/tokens/design_tokens.dart`（原 Mistral 橙色主题静态常量）与皮肤系统并存，属旧视觉遗留。
6. **两个死入口**：
   - `wallpaper_select_page.dart` 定义了 `WallpaperSelectPage`，但**全代码库无任何导航引用**——用户根本无法到达；
   - `main.dart:48` import 了 `ui_theme_select_page.dart` 却从未使用（死导入）。
   - 外观设置唯一真实入口：`profile_screen.dart:179 → AppearancePage.routeName`。

### 1.3 壁纸功能的使用分布

壁纸机制支持三类素材：`solid`（纯色）/ `gradient`（渐变）/ `image`（图片资产），当前内置 **10 套**：1 纯色（`#F5F5F5`）+ 5 渐变 + 4 图片。消费点共三处，全部是**整页画布级**使用：

| 文件 | 用法 |
|---|---|
| `home_screen.dart:36` | `watch<WallpaperState>().current` 渲染全屏背景（`_WallpaperBg`） |
| `learn_page.dart:36` | 同上，学习页全屏背景 |
| `review_page.dart:104-162` | 全屏背景 + 叠加 `skin.wallpaperScrim.withOpacity(0.15)` 半透明遮罩保证可读性 |

关键结论：**壁纸不是装饰元素，它直接占据"画布"这一角色**——这正是它与星巴克规范冲突的根源。

### 1.4 暗色模式现状总结

- 有"深邃/极夜"两套深色皮肤，但**没有真正的暗色模式**：无系统亮度跟随、无持久化、无 Material `darkTheme`、ColorScheme 语义错位。
- 现有深色皮肤的令牌值（`#212532` 蓝灰、`#040404` 黑）是旧视觉遗产，与星巴克绿色体系无关。

---

## 二、冲突分析：奶油画布 vs 壁纸/皮肤机制的本质矛盾

DESIGN.md 的核心命题是：**"不要用纯白画布，奶油色是灵魂；无渐变、纯色块分层。"** 这与现有机制存在四层本质矛盾：

### 矛盾 1：画布所有权的争夺（最核心）

星巴克规范中，奶油色（`#F2F0EB`/`#F7F3ED`）**本身就是品牌资产**，画布 = 品牌表达的第一载体。而壁纸机制的设计前提恰恰相反——画布是用户可替换的自由变量。两者不能共存于同一个位置：只要首页/学习页/复习页的背景还是用户选的渐变或照片，"奶油画布是灵魂"就不成立。这不是参数调优问题，是**所有权归属问题**。

### 矛盾 2：渐变禁令的直接违反

10 套壁纸中 5 套是渐变（gradient），规范明确"无渐变"。即使保留壁纸功能本身，现素材集已整体违规。

### 矛盾 3：多皮肤自由 vs 品牌唯一性

皮肤系统的存在暗示"视觉语言可切换"，而本次重构的目标是确立星巴克视觉为唯一官方语言。三套皮肤里只有待新建的星巴克主题合规，另两套（蓝灰深邃、纯黑极夜）都是旧视觉遗产——保留它们等于官方自带两套不合规皮肤。

### 矛盾 4：令牌双轨制

`design_tokens.dart`（Mistral 橙）与 `skin_system.dart` 并存，新代码若误引旧令牌会造成色彩漂移。规范落地要求单一令牌源。

---

## 三、策略建议（推荐 C：分层收编折中方）

### 方案 A —— 彻底移除壁纸/皮肤，单一星巴克主题

- **做法**：删除 `SkinSystem/WallpaperState/WallpaperData/appearance_page/wallpaper_select_page/design_tokens.dart`，硬编码一套 Starbucks 主题。
- **优点**：最彻底地消除矛盾；删除约千行死代码与孤儿页面；品牌绝对统一。
- **缺点**：① 把婴儿和洗澡水一起倒掉——`dark/pure_black` 两套皮肤证明项目已有深色需求（夜间背单词场景刚需），推倒后暗色模式要从零重建；② `ThemeVars` 的 30 个语义令牌架构是正确投资，删掉等于放弃未来一切换肤/主题能力；③ 产品层面永久失去个性化空间，未来想加任何节日主题都要重新搭架子。
- **判定**：方向正确但手段过度。

### 方案 B —— 保留机制，新增 "Starbucks" 官方皮肤为默认

- **做法**：在现有 3 套旁新增第 4 套 `starbucks` 设为默认，其余保留可选。
- **优点**：改动最小、渐进安全；暗色基础设施得以保留。
- **缺点**：只是把矛盾**掩盖**而非解决——渐变/图片壁纸依然占据画布位，用户随手一换就破坏品牌画布；三套不合规旧皮肤继续存在；"默认值"挡不住用户改设置。
- **判定**：回避了画布所有权这个核心矛盾，不推荐。

### 方案 C（推荐）—— 「画布归品牌，装饰归个性」的分层收编

原则一句话：**凡承载内容的画布一律归品牌令牌管；壁纸降级为无内容遮挡区的纯色装饰，个性收敛到品牌允许的边界内。**

具体动作：

1. **皮肤层收敛为 2 套**：
   - `starbucks_cream`（新默认）：按 DESIGN.md 重塑全部 30 个令牌（奶油画布 `#F2F0EB`、主绿 `#00754A` 强调、墨绿 `#03453F` 正文、圆角沿用卡片既有规格）；
   - `starbucks_dark`（新增，见第四节设计）：替代 `dark` 与 `pure_black`（OLED 需求由 dark 的 surface 层压暗覆盖，或保留 pure_black 作无障碍选项，二选一）。
   - 保留 `ThemeVars` 架构与 `SkinSystem/SkinProvider` 不动——只换预设内容，页面代码零改动。
2. **壁纸层降级**：
   - 首页/学习页/复习页三处**移除壁纸渲染，画布回归 `skin.pageBg`**（奶油）；
   - 壁纸仅允许出现在**无正文遮挡的装饰区**（如个人页头部横幅），且素材收敛为星巴克官方纯色/纹理块——**下线全部渐变与图片壁纸**，`WallpaperType.gradient/image` 可废弃；
   - 删除孤儿 `wallpaper_select_page.dart` 与 `main.dart:48` 死导入。
3. **补齐机制欠账**（无论选哪个方案都必须做）：
   - `themeId` 持久化到 SharedPreferences（对齐壁纸已有的 `'selected_wallpaper_id'` 模式）；
   - 「跟随系统」开关接线：监听 `MediaQuery.platformBrightnessOf` / `didChangePlatformBrightness`，映射 `themeMode`；
   - 分离「Material 亮度」与「状态栏图标亮度」两个语义（修复 1.2-3 的过载）。
4. **清理令牌双轨**：`design_tokens.dart` 中仍被引用的常量迁入 `ThemeVars` 后整文件删除。

**说理**：A 丢掉了项目已被验证需要的暗色能力和正确的令牌架构，代价大于收益；B 保留了与品牌矛盾的画布自由度，等于规范随时可被用户一键绕过；C 用所有权切分化解了核心矛盾——画布（品牌不可让渡的部分）收归令牌，壁纸（个性表达的合法部分）压缩到不伤害品牌的区域，同时以最小页面改动量完成迁移。**成本居中、风险可控、且顺手清偿了持久化/假开关/死代码三笔技术债。**

---

## 四、暗色模式提案：深绿三层体系

星巴克无官方 App 级暗色版，需自建设计。先回答命题中的选择题：

### 4.1 画布基底：深绿系，而非暖炭色

| 候选 | 论证 |
|---|---|
| **暖炭色**（如 `#1C1B18`） | 与奶油亮色同温呼应，但夜间打开 App **失去品牌识别度**——任意深色阅读 App 都长这样。且炭色偏中性，与绿色的强调色对比关系平淡。 |
| **直接 `#1E3932` 做画布** | 品牌锚定强，但该色亮度偏高（约 L\*23），大面积铺满作为底色时饱和度存在感过强，长时间盯屏易疲劳，也压缩了卡片层的提亮空间。 |
| **✅ 推荐：深绿三层体系** | 以 `#1E3932` 做**表面层**而非画布，画布用更深的墨绿近黑。层级感来自规范的"纯色块分层"思想，品牌绿仍在画面中占主导。 |

### 4.2 Token 建议（starbucks_dark）

设计原则：**昼夜语义反转**——亮色模式下"奶油=画布、深绿=强调"；暗色模式下"深绿=表面、奶油=前景强调"。两个品牌色互换角色，形成闭环。

| Token | starbucks_cream（亮） | starbucks_dark（暗） | 说明 |
|---|---|---|---|
| `pageBg` | `#F2F0EB` 奶油 | `#101B17` 墨绿近黑 | 画布基底，比 #1E3932 更深更沉 |
| `surfaceRaised`(cardBg) | `#FFFFFF` 或 `#FBF9F5` 卡片 | `#1E3932` 品牌深绿 | **#1E3932 的正确位置**：卡片/浮层 |
| `surfaceHigh` | — | `#274A40` 提亮绿 | 弹窗、菜单等二级浮层 |
| `accent` | `#00754A` 主绿 | `#00A862` 亮薄荷绿 | #00754A 在暗底上不够亮，需提亮一档保对比 |
| `accentOnSurface` | `#F2F0EB` 奶油 | `#D4E9E2` 浅薄荷 | 强调色上的文字 |
| `textPrimary` | `#03453F` 墨绿 | `#E8E3DA` 暖米白 | 暖调白，避免冷灰 |
| `textSecondary` | `#5C6B66` 灰绿 | `#9DB0A9` 雾绿 | |
| `wallpaperScrim` | `= pageBg` | `= pageBg` | 壁纸降级后此令牌趋于退役 |

**对比度自检**：`#E8E3DA` on `#101B17` ≈ 12.8:1（AAA）；`#9DB0A9` on `#101B17` ≈ 6.9:1（AA 正文达标）；`#00A862` on `#1E3932` ≈ 3.6:1（大字/图形达标，正文用浅色）。

**状态栏**：暗色下图标用 light；同时把 `statusBarBrightness` 从 `theme.brightness` 中拆出，`MaterialApp` 改用标准 `theme`/`darkTheme` + `themeMode` 结构。

---

## 五、迁移风险清单

| # | 风险 | 影响 | 缓解措施 |
|---|---|---|---|
| R1 | **statusBarBrightness 语义过载**：重构时若沿用旧的 brightness 传递方式，暗色模式的 ColorScheme 会重蹈"亮皮暗芯"覆辙 | 高 | 第一步就拆分两个语义，`MaterialApp` 迁移到 `theme + darkTheme + themeMode` 标准结构 |
| R2 | **review_page 动态遮罩耦合**：`skin.wallpaperScrim.withOpacity(0.15)` 与壁纸渲染绑定，移除壁纸时漏改会导致透明层叠错误 | 中 | 三处壁纸消费点一次性同步清理，删 `wallpaperScrim` 前全局 grep |
| R3 | **壁纸初始闪变**：`WallpaperState` 初始值为 beachWallpaper，若壁纸下线前先发版，启动仍可能闪现沙滩图 | 低 | 壁纸移除与默认皮肤切换同一版本发布 |
| R4 | **持久化升级兼容**：新增 themeId 持久化后，老用户升级首次启动的默认值路径要明确（读不到 key → 回落 starbucks_cream） | 中 | 写入前判空，定义清晰 fallback；勿依赖运行时默认构造 |
| R5 | **design_tokens.dart 残留引用**：删除旧橙色令牌前若有文件仍在 import，编译期才会暴露 | 中 | 迁移期先 grep 所有 `design_tokens` import，逐个改指 ThemeVars 后再删文件 |
| R6 | **假开关接线的平台差异**：「跟随系统」接线后需处理 Android/iOS 亮度变化回调（`didChangePlatformBrightness`）与生命周期，半成品比假开关更伤体验 | 中 | 接线时补平台测试；开关关闭态 = 手动选定皮肤 |
| R7 | **场景令牌映射缺失**：ThemeVars 中 glass/quiz/vip 组令牌在两套新皮肤中必须逐一给出值，遗漏会在对应页面出现 null/黑块 | 中 | 建立 token 清单核对表，逐页面走查 quiz/vip/glass 相关界面 |
| R8 | **双入口混淆**：`AppearancePage` 是唯一真实入口，但孤儿壁纸页与死导入容易让后来者误以为还有第二入口 | 低 | 同版本删除 `wallpaper_select_page.dart`、`ui_theme_select_page.dart` 及 `main.dart:48` 死导入 |
| R9 | **图片资产体积变化**：4 张图片壁纸从 bundle 移除后包体减小（正向），但需确认无其他页面复用这些资产 | 低 | 删除前全局 grep assetPath 引用 |
| R10 | **视觉回归**：三套→两套皮肤后，所有页面对新奶油/暗色令牌的适配需要逐页走查（尤其硬编码颜色的历史页面） | 高 | 迁移分支上全局 grep `Color(0x` 硬编码，建立清单逐个替换为 skin 令牌后再合入 |

---

## 结论

- 现状：皮肤架构健康但内容失焦、机制带伤（不持久化、假开关、亮度语义错位）；壁纸占据画布位且素材整体违反规范；暗色模式实质不存在。
- 策略：**方案 C** —— 画布归品牌（奶油/深绿令牌管到底）、装饰归个性（壁纸降级为受限纯色装饰）、顺手清偿三笔机制债。
- 暗色：深绿三层体系（画布 `#101B17` / 表面 `#1E3932` / 强调 `#00A862`），昼夜语义反转，品牌识别与护眼兼得。
