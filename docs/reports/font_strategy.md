# SoDoSans 替代字体方案与 Flutter 接入策略

> 对应 DESIGN.md 第 3 节 Typography 与 "Note on Font Substitutes"。
> 范围：Monster Word（word_app，Flutter 背单词 App）。本文档只做选型与接入策略，不含代码改动。

---

## 0. 结论速览（TL;DR）

| 决策项 | 结论 | 一句话理由 |
|---|---|---|
| 主无衬线字体 | **Inter**（维持现状） | 与 SoDoSans 形似度最高，且项目已捆绑 4 个字重，零迁移成本 |
| 接入方式 | **手动捆绑到 assets/fonts** | 离线可靠、国内网络不受 Google CDN 制约，且与项目既有重本地资产架构一致；**不引入 google_fonts** |
| 中西文混排 | `fontFamily: 'Inter'` + `fontFamilyFallback` 中文回退链（苹方 → 微软雅黑 → Noto Sans SC） | 显式声明才能保证 Android/Windows 上中文不落到难看的默认回退 |
| 字距 `-0.01em` | `letterSpacing: -fontSize × 0.01`（逻辑像素） | CSS em 相对自身字号，Flutter 是绝对值，需逐 token 换算；**仅用于纯西文样式** |
| 成就/奖励衬线 | **Lora**（新增）；过渡期可直接复用已捆绑的 Charter | Lora 暖调编辑感最贴近 Lander Tall / Rewards 手写黑板气质 |

---

## 1. 三候选对比：Inter vs Manrope vs Nunito Sans

### 1.1 本 App 的字体使用画像

先明确本 App 与星巴克官网的两个关键差异，它们决定选型权重：

1. **中文为主**：全部页面导航、按钮、设置、释义翻译都是中文，英文字体实际上只承担"嵌入在中文句子里的英文"和"独立展示的英文单词"两类角色；
2. **英文单词是大字号主角**：学习/复习会话中的核心单词以 38–40px、w700 展示（`AppTypography.heroWord`，见 `lib/tokens/design_tokens.dart`、`lib/screens/learn_session.dart`、`lib/screens/review_session.dart`），是整个界面的视觉焦点。

因此选型优先级是：**大字号展示表现 > 与中文字体的搭配和谐 > 与 SoDoSans 的形似度 > 小字号可读性**。

### 1.2 逐项对比

| 维度 | Inter | Manrope | Nunito Sans |
|---|---|---|---|
| 与 SoDoSans 形似度 | ★★★★★ 同为 Helvetica Neue 血统的人文几何无衬线，高 x-height、开放式字形（SoDoSans 的 CSS 回退链 `"Helvetica Neue", Helvetica, Arial` 即佐证） | ★★★☆☆ 更半圆几何，字形偏窄 | ★★☆☆☆ 圆角末端，气质偏离 |
| 大字号单词展示 | ★★★★★ 为屏幕 UI 设计，有 opsz/display 内建优化，负字距下仍舒展 | ★★★★☆ 现代感好，长词略挤 | ★★★☆☆ 过圆，缺利落感 |
| 与中文（苹方/雅黑）混排 | ★★★★★ 中性灰度和 x-height 最匹配 | ★★★☆☆ 圆度差异带来灰度不均 | ★★☆☆☆ 圆角与汉字笔画冲突明显 |
| 字重范围 | Thin–Black 全 + 可变字体，本项目已有 400/500/600/700 | 200–800 可变字体 | 全 |
| 斜体 | ✅（例句、释义需要） | ❌ 无官方斜体 | ✅ |
| IPA 音标符号覆盖 | 好（含 ə ɜ ʃ ŋ 等） | 一般 | 一般（圆角损失符号细节） |
| 许可证 | OFL | OFL | OFL |

### 1.3 推荐：Inter

1. **形似度最高**：SoDoSans 是 House Industries 为星巴克定制的人文主义无衬线，Inter 是开源界公认最接近的替代（DESIGN.md 也将其列为首位）；
2. **零迁移成本**：项目已捆绑 `Inter-Regular/Medium/SemiBold/Bold.otf` 并在 `MistralTypography` / `AppTypography` 全套 token 中使用，选 Inter 意味着本次重构只需补 fallback 和字距，不需要动任何字体资产；
3. **大字号主角场景最强**：38–40px 的单词展示正落在 Inter 的舒适区——高 x-height 让小写单词饱满醒目，内建的 display 尺寸优化让负字距不挤压；
4. **中文搭配最好**：苹方/微软雅黑同样是中性人文风格，与 Inter 并排时灰度、节奏最均匀；
5. **功能完备**：斜体、IPA 音标、tabular figures（学习统计数字）齐全。

> 备注：Manrope 可作为"更圆润友好"的品牌备选，但仅适合短文案场景，不建议全局替换；Nunito Sans 的圆角风格会让音标细节发糊、与汉字并置违和，不推荐做主字体。
>
> DESIGN.md 提醒"部分开源字体需要放宽到 -0.005em"——Inter 不在此列（它本身就是按紧字距设计的），-0.01em 安全。

---

## 2. 接入方式调研：google_fonts vs 手动捆绑

### 2.1 对比

| 维度 | google_fonts 包 | 手动捆绑 assets/fonts |
|---|---|---|
| 首次加载 | 运行时从 fonts.gstatic.com 下载，首次可能出现字体闪替（FOUT）或回退 | 随安装包即刻可用 |
| 离线可靠性 | ❌ 首启无网时回退系统字体 | ✅ 完全离线 |
| 国内网络 | ❌ Google CDN 直连不稳定/不可达 | ✅ 无外联 |
| 包体积 | 不增加（下载缓存） | 每字重约 100–330KB（本项目现有 4 个 Inter 字重合计约 1.2MB） |
| 版本一致性 | 远端资产可能变化 | 构建期固定 |
| 依赖面 | 新增第三方包及其平台通道 | 无新依赖 |

### 2.2 结论：手动捆绑

1. **网络现实**：目标用户主要在中国大陆，google_fonts 的运行时下载路径（fonts.googleapis.com / fonts.gstatic.com）不可靠，即使它支持"预打包进 assets"的模式，也只是绕一层包依赖，不如直接声明；
2. **架构一致**：本 App 本来就是重本地资产架构——词库 `assets/db/wordbook.db.gz` 首启解压、本地发音音频、壁纸包。1MB 级字体相对这些资产可忽略；
3. **既成事实**：项目已经在用手动捆绑（pubspec 注释"字体（Mistral AI：Inter 无衬线 + Charter 衬线）"），延续即可。

### 2.3 pubspec.yaml 写法示例（仅文档示例，未改动实际 pubspec.yaml）

```yaml
flutter:
  uses-material-design: true

  assets:
    - assets/db/wordbook.db.gz
    - assets/icons/
    - assets/wallpapers/

  fonts:
    # 主无衬线 —— SoDoSans 替代
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Regular.otf
          weight: 400
        - asset: assets/fonts/Inter-Medium.otf
          weight: 500
        - asset: assets/fonts/Inter-SemiBold.otf
          weight: 600
        - asset: assets/fonts/Inter-Bold.otf
          weight: 700

    # 成就/奖励衬线 —— Lander Tall 替代（新增建议）
    - family: Lora
      fonts:
        - asset: assets/fonts/Lora-Regular.ttf
          weight: 400
        - asset: assets/fonts/Lora-Medium.ttf
          weight: 500
        - asset: assets/fonts/Lora-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/Lora-Bold.ttf
          weight: 700
        - asset: assets/fonts/Lora-Italic.ttf
          style: italic

    # 书卷衬线 —— 已存在，保留
    - family: Charter
      fonts:
        - asset: assets/fonts/Charter-Roman.ttf
        - asset: assets/fonts/Charter-Italic.ttf
          style: italic
```

要点：

- `family:` 后的名字是代码里 `TextStyle(fontFamily: ...)` 引用的键，与文件名无关；
- 同一 family 下用 `weight:` / `style:` 映射多个文件，引擎按样式取用，不必在代码里写 "Inter SemiBold" 这种名字；
- TTF 与 OTF 均支持；Google Fonts 下载的静态 TTF 直接可用；
- 体积优化备选项：Inter 有官方可变字体单文件版，Flutter 支持可变字体，但静态多字重兼容性最稳，现阶段 4 字重足够，不建议为省几百 KB 引入复杂度。

---

## 3. 中西文混排策略：英文字体 + 中文回退

### 3.1 原理

Flutter 的 `fontFamily` 只指定一个主字体；主字体未覆盖的码位（全部汉字）按 `fontFamilyFallback` 列表顺序回退，列表走完后才落到平台默认。**不显式声明 fallback 的后果**：Android 回退到 Roboto/Noto CJK（风格尚可但不可控），Windows 常回退到宋体（观感明显劣化）。显式回退链才能跨平台一致。

### 3.2 正确写法

**单条样式（纯 Dart 层）：**

```dart
/// 中西文混排基础样式：英文 Inter 优先，中文按平台回退
const TextStyle mixedText = TextStyle(
  fontFamily: 'Inter',                 // 英文/数字/音标
  fontFamilyFallback: <String>[
    'PingFang SC',                     // iOS / macOS 苹方
    'Microsoft YaHei',                 // Windows 微软雅黑
    'Noto Sans SC',                    // Android 部分机型的 CJK
    'Source Han Sans SC',              // 思源黑体兜底（部分 ROM 内置）
  ],
);
```

**主题层一次声明、全局生效（推荐落地方式）：**

```dart
// ThemeData.fontFamily 只能设主字体，fallback 需要 apply 到 TextTheme：
TextTheme cjkFallback(TextTheme t) => t.apply(
      fontFamily: 'Inter',
      fontFamilyFallback: const [
        'PingFang SC', 'Microsoft YaHei', 'Noto Sans SC',
      ],
    );

MaterialApp(
  theme: ThemeData(textTheme: cjkFallback(Typography.material2021().black)),
);
```

**对本项目的落点**：所有自定义 token 集中在 `lib/tokens/design_tokens.dart`，只需给 `MistralTypography` / `AppTypography` 各 token 统一加上 `fontFamilyFallback`，一处文件改完全局受益。

### 3.3 注意事项

- **回退顺序即优先级**：把最想要的中文体放第一位；iOS 命中苹方后不会再往后找；
- **汉字不要加负字距**：`letterSpacing` 对整串文本生效，CJK 方块字加负距会互相贴黏。负字距只允许出现在纯西文样式上（见第 4 节）；
- **音标现状问题**（顺带发现）：`lib/widgets/card_widgets.dart:36` 引用了 `fontFamily: 'phonetic'`，但 pubspec 从未注册过该 family，目前静默回退到默认字体。建议要么删除这个引用改用 Inter（其对 IPA 覆盖良好），要么真正注册一个音标字体（如 Charis SIL / Gentium Plus，均 OFL）；
- **统计数字**：学习统计类表格如需对齐，可开 `fontFeatures: [FontFeature.tabularFigures()]`（Inter 支持）。

---

## 4. 字距 `-0.01em` 在 Flutter 中的等价写法

### 4.1 换算规则

CSS 的 `letter-spacing: -0.01em` 相对**元素自身 font-size**；Flutter 的 `TextStyle.letterSpacing` 是**绝对逻辑像素**。因此：

```
letterSpacing = -fontSize × 0.01
```

按 DESIGN.md 层级换算成移动端常用字号：

| 角色 | fontSize | letterSpacing |
|---|---|---|
| Body 16 | 16 | -0.16 |
| Small 14（按钮标签） | 14 | -0.14 |
| Micro 13 | 13 | -0.13 |
| 单词主角 heroWord | 38 | -0.38 |
| Display 45（Hero Large 移动档） | 45 | -0.45 |

### 4.2 写法示例

```dart
// 直接写死（token 数量有限，最直观）
const TextStyle heroWord = TextStyle(
  fontFamily: 'Inter',
  fontSize: 38,
  fontWeight: FontWeight.w700,
  height: 1.20,
  letterSpacing: -0.38, // -0.01em @38px，仅西文
);

// 或封装 helper（防止手算出错）
TextStyle sodoTracking(TextStyle base) =>
    base.copyWith(letterSpacing: -(base.fontSize ?? 16) * 0.01);
```

### 4.3 使用边界

- **只作用于纯西文样式**：`heroWord`、音标、纯英文标签可以加；任何可能包含中文的样式（正文、按钮中文文案）**不加**，否则汉字粘连（见 3.3）；
- **Inter 无需放宽**：DESIGN.md 提示部分开源字体紧字距观感差需放宽至 -0.005em，Inter 不需要；若将来个别文案换 Manrope/Nunito Sans，再对该样式放宽到 `-fontSize × 0.005`;
- DESIGN.md 中 Display/Jumbo/Hero 档用的是绝对值 `-0.16px`（网页语境），移植到 Flutter 时按各 token 实际字号换算即可，不必照抄 -0.16。

---

## 5. 成就/奖励场景衬线字体建议

### 5.1 背景

DESIGN.md：Rewards 页在特定标题时刻切换暖调衬线（Lander Tall → 回退 Iowan Old Style / Georgia），营造"咖啡馆手写黑板"的怀旧仪式感。Lander Tall 为定制字体，开源替代：**Lora** 或 **Source Serif Pro**（现名 Source Serif 4）。

### 5.2 对比与本 App 场景匹配

| 维度 | Lora | Source Serif 4 | （现有）Charter |
|---|---|---|---|
| 气质 | 暖调、有笔触感、"编辑杂志"味 | 结构硬朗、出版物气质 | 经典书卷、屏幕阅读老牌 |
| 与星巴克 Rewards 仪式感匹配 | ★★★★★ 最接近暖调黑板/手作感 | ★★★☆☆ 偏正式 | ★★★★☆ 温和但偏"正文" |
| 权重/斜体 | 全 + 优质斜体 | 全 + 优质斜体 | 已有 Roman/Italic/BoldItalic |
| 与 Inter 同屏搭配 | 和谐（同为 GF 生态主流） | 和谐 | 和谐 |
| 新增体积 | 约 500–600KB（4 字重 + 斜体） | 类似 | 0（已捆绑） |

### 5.3 建议

- **首选 Lora**：本 App 的成就/奖励时刻（连续打卡、升级、勋章弹窗）正是"局部仪式性 surface"，Lora 的暖调与星巴克 Rewards 的怀旧编辑感最贴近，且 OFL 许可随包分发无风险；
- **零成本过渡方案**：直接复用已捆绑的 **Charter**（`heroDisplay`/`heading1` 正在用它），先把成就页标题切到 Charter 验证视觉方向，后续再决定是否引入 Lora；
- **Source Serif 4 作备选**：若奖励页最终包含大段说明文字（长文阅读），它的正文稳定性更好；
- **使用纪律**（遵循 DESIGN.md 原则）：衬线只出现在成就弹窗标题、徽章名、奖励横幅等局部 surface 的**标题层**，不与正文无衬线在同一段落混排；正文永远回到 Inter + 中文回退链。

```dart
/// 成就弹窗标题示例（假设采用 Lora）
const TextStyle achievementTitle = TextStyle(
  fontFamily: 'Lora',
  fontSize: 24,
  fontWeight: FontWeight.w600,
  height: 1.2,
  letterSpacing: -0.24, // -0.01em @24px，纯西文标题可用
);

/// 零成本过渡（复用现有 Charter）
const TextStyle achievementTitleTemp = TextStyle(
  fontFamily: 'Charter',
  fontSize: 24,
  fontWeight: FontWeight.w400,
  height: 1.15,
);
```

---

## 6. 落地清单（供后续实现任务参考）

1. `lib/tokens/design_tokens.dart`：给 `MistralTypography` / `AppTypography` 全部 token 增加 `fontFamilyFallback` 中文回退链（集中一处修改）；
2. 纯西文 token（`heroWord`、音标样式）追加 `letterSpacing = -0.01 × fontSize`；含中文 token 不加；
3. 修复 `'phonetic'` 幽灵引用（`lib/widgets/card_widgets.dart:36`）：删除或正式注册音标字体；
4. 若采纳 Lora：下载静态 TTF 放入 `assets/fonts/`，按第 2.3 节示例声明（届时才改 pubspec.yaml）；
5. 保持手动捆绑路线，**不引入 google_fonts 依赖**。

---

## 附：字体获取与许可

| 字体 | 来源 | 许可 | 随 App 分发 |
|---|---|---|---|
| Inter | github.com/rsms/inter（releases 含 OTF/TTF）或 fonts.google.com | SIL OFL 1.1 | ✅ 可捆绑分发 |
| Lora | fonts.google.com/specimen/Lora | SIL OFL 1.1 | ✅ |
| Source Serif 4 | github.com/adobe-fonts/source-serif | SIL OFL 1.1 | ✅ |
| Charter | 已在仓库中（Bitstream Charter 开源版） | OFL/Charter 许可 | ✅（现状） |

OFL 字体可自由嵌入商业闭源应用；如需严谨合规，可在关于页附上 OFL 许可文本副本（非强制）。
