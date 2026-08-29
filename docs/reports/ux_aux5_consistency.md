# UX-AUX-5 用户视角体检：全局一致性 / 文案 / 可访问性 / 反馈

> 站在最终用户角度的全库横向只读体验审计。扫 `lib/**`，聚焦术语文案、视觉范式、返回导航、空错加载态、可访问性、图标语义。
> 约束：只读，未改 lib/。输出每条含 file:line + 用户痛点 + UX 严重度(高/中/低) + 建议方案。

---

## 一、全局一致

### 1.1 签到 vs 打卡 术语不一致 — 【高】

| file:line | 文案 |
|-----------|------|
| `lib/widgets/checkin_widgets.dart:33` | `this.title = '签到'`（默认标题） |
| `lib/widgets/spring_check_in_calendar.dart:313` | `'签到领 ${...} 尖叫币'`、`'今日已签到，明天再来～'` |
| `lib/pages/check_in_history_page.dart:70` | `'签到历史'` |
| `lib/pages/check_in_history_page.dart:152` | `'还没有签到记录'` |
| `lib/screens/home_screen.dart:316` | `'打卡 +10'` |
| `lib/features/checkin/presentation/class_checkin_page.dart:244` | `'班级打卡'`、`'每日打卡'` |

- **用户痛点**：同一个「每日 check-in 领尖叫币」功能，在日历组件/历史页叫「签到」，在首页奖励按钮/班级页叫「打卡」。用户可能误以为是两个不同功能，或困惑于「签到」和「打卡」到底该点哪个。
- **根因**：check-in 组件层用「签到」，首页与班级页用「打卡」，缺少统一的术语表（naming dictionary）。
- **建议方案**：全库统一为「签到」（因 check-in 组件默认标题、历史页、日历奖励文案均已用「打卡」的反向是少数）；将 `home_screen.dart:316` 改为「签到 +10」，`class_checkin_page.dart:244` 改为「班级签到」「每日签到」。若产品意图区分「个人签到」与「班级打卡」，需在视觉/文案上显式说明差异，而非无声混用。

---

### 1.2 返回图标风格不一致 — 【中】

| file:line | 图标 |
|-----------|------|
| 大多数 feature 页面 | `Icons.arrow_back_ios_new` |
| `lib/features/account/presentation/dictionary_by_name_page.dart:63,93` | `Icons.arrow_back` |

- **用户痛点**：同一操作（返回上一页）在不同页面呈现不同图标，破坏肌肉记忆与界面可预期感。iOS 风格页面混用 Material 风格返回箭头。
- **根因**：无强制的设计 token 约束图标选型；dictionary 页独立实现时选用了非标准图标。
- **建议方案**：全库统一使用 `Icons.arrow_back_ios_new`（与账户/设置/词书域一致）；或建立 `AppIcons.back` token 统一出口。

---

### 1.3 SnackBar 无统一封装 — 【低】

全库约 30+ 处直接内联：
```dart
ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(content: Text('...'), duration: Duration(seconds: 1)),
);
```
- **用户痛点**：各页面 SnackBar 时长、字号、圆角、颜色不一致；部分页面用 1 秒（如 `settings_page.dart:112`「助记顺序设置开发中...」），用户来不及读。
- **根因**：缺少全局 `AppMessages.show(context, '文案')` 封装。
- **建议方案**：封装统一 helper，统一时长（建议 2 秒）、字号、成功/警告/错误配色；「开发中」类提示单独归类（见 1.4）。

---

### 1.4 「开发中 / 即将上线」提示措辞不一致 — 【低】

| file:line | 文案 |
|-----------|------|
| `settings_page.dart:112` | `'助记顺序设置开发中...'` |
| `settings_page.dart:136` | `'更多学习偏好开发中...'` |
| `more_settings_page.dart:34` | `'$feature 功能即将上线'` |
| `profile_screen.dart:58` | `'消息功能开发中...'` |
| `lib/screens/learn_session.dart:258` | `'撤销功能开发中'`（无省略号） |
| `login_page.dart:559` | `'$platform 登录功能开发中'` |
| `class_checkin_page.dart:77` | `'班级设置功能开发中...'` |
| `personal_stereo_page.dart:20` | `'随身听功能开发中...'` |
| `my_fav_sentence_page.dart:309` | `'句库学习功能开发中...'` |
| `my_content_page.dart:140` | `'提示功能开发中...'` |
| `lib_select_page.dart:406` | `'$tool 功能开发中...'` |
| `class_activity_page.dart:378` | `'创建班级活动功能开发中...'` |

- **用户痛点**：同一含义有 3 种措辞（「开发中」「开发中...」「功能即将上线」），标点也不统一（有/无省略号）。用户无法判断「开发中」和「即将上线」是同一回事还是不同阶段。
- **根因**：无文案规范；各页面独立硬编码。
- **建议方案**：统一为「即将上线」（最友好，无标点歧义），通过 `AppMessages.comingSoon(context)` 一处维护。

---

### 1.5 品牌装饰色硬编码 — 【低】

- `lib/features/account/presentation/splash_page.dart:134-135`：`Color(0xFF1E3932)`、`Color(0xFFcba258)` 用于流星雨装饰。
- **用户痛点**：当用户切换暗色/自定义皮肤时，流星雨颜色不变，可能与主题冲突。
- **根因**：装饰性动效未接入 `skin.colors` token。
- **建议方案**：将装饰色映射到 `skin.colors.accent` / `skin.colors.gold` 等 token，或至少提供暗色fallback。

---

## 二、文案

### 2.1 「单词本」 vs 「词书」 概念易混淆 — 【中】

| file:line | 文案 | 实际含义 |
|-----------|------|----------|
| `lib/pages/my_fav_page.dart:83` | `'确定要从单词本移除...'` | 收藏单词列表 |
| `lib/pages/my_fav_page.dart:148` | `'单词本'` | 收藏单词列表 |
| `lib/pages/my_fav_page.dart:197` | `'单词本为空'` | 收藏列表无数据 |
| `lib/pages/my_fav_page.dart:220` | `'学习单词本 (${_words.length} 词)''` | 学习收藏单词 |
| 全库其余 200+ 处 | `词书` | 学习教材（如「选择词书」「当前词书」） |

- **用户痛点**：「词书」是学习教材，「单词本」是收藏夹。中文里「书本」与「单词本」字形接近，新用户易把「添加到单词本」（收藏）误认为「添加词书」（购买/切换教材）。
- **根因**：收藏功能沿用 legacy 名称「单词本」，教材功能用「词书」，两词在中文里语义距离近。
- **建议方案**：将「单词本」改为「收藏」或「生词本」（与「词书」区分度更大），全库统一。若保留「单词本」，需在首次引导中显式说明「单词本 = 你收藏的单词」。

---

### 2.2 英文品牌名 — 【低】

- `lib/features/account/presentation/splash_page.dart:145`：`Text('Monster Word', ...)` 品牌名。
- `splash_page.dart:158`：跑马灯 `'Monster Word · 背单词 · 从未如此有趣 · '`。

- **用户痛点**：品牌露出为英文，对部分中文用户有距离感；但属品牌决策而非 bug。
- **评估**：品牌名保留英文是合理决策，不强制修改。但跑马灯中「Monster Word · 背单词」重复了品牌名与中文标语，略冗余。
- **建议方案**：跑马灯精简为「背单词 · 从未如此有趣 · 每日签到 · ···」去除英文品牌，或保留一处品牌露出。

---

### 2.3 「尖叫币」命名一致性 — 【正面】

- 全库 ScareCoin 相关 UI 统一使用「尖叫币」（如 `spring_check_in_calendar.dart:313`「签到领 N 尖叫币」、`scare_coin_history_page.dart` 页面标题）。
- 代码层 `ScareCoin` / `scare_coin` 命名也一致。
- **评估**：术语统一，无「金币」「怪兽币」等混用。✅

---

### 2.4 「打卡」已确认为少数派用法 — 【补充】

- 见 1.1。首页 `home_screen.dart:316` 与班级页 `class_checkin_page.dart:244` 的「打卡」为少数派，其余 5+ 处均为「签到」。
- 统一后无残留混用。

---

## 三、可访问性

### 3.1 装饰性「怪」字无语义标签 — 【中】

- `lib/features/account/presentation/splash_page.dart:137-140`：`Text('怪', style: TextStyle(fontSize: 36, ...))` 作为品牌 Logo 展示。
- **用户痛点**：屏幕阅读器（TalkBack/VoiceOver）会朗读单字「怪」，用户无法理解这是品牌标识，造成困惑。
- **根因**：装饰性文字未加 `ExcludeSemantics` 或 `Semantics(label: '怪兽单词 Logo')`。
- **建议方案**：
  ```dart
  ExcludeSemantics(
    child: Text('怪', ...),
  )
  // 或
  Semantics(label: '怪兽单词', child: Text('怪', ...))
  ```

---

### 3.2 IconButton 缺 tooltip / 语义标签 — 【中】

- 大量功能 IconButton 仅用 icon 无 tooltip：
  - `lib/pages/lib_select_page.dart:118`：「眼睛图标」切换词书描述可见性，无 tooltip、无 Semantics。
  - 各页面返回按钮（`Icons.arrow_back_ios_new`）无 tooltip。
  - `settings_page.dart` 多个设置项 IconButton。
- **用户痛点**：触摸屏用户长按无法获知按钮用途；屏幕阅读器朗读「按钮」而非具体功能。
- **根因**：未强制 `IconButton(tooltip: ...)` 或 `Semantics(label: ...)`。
- **建议方案**：所有交互图标必填 `tooltip`（Flutter 自动将 tooltip 作为无障碍标签）；对无文字按钮显式加 `Semantics(label: '...')`。

---

### 3.3 辅助说明文字偏小 — 【低】

| file:line | 字号 | 内容 |
|-----------|------|------|
| `lib/screens/home_screen.dart:183` | `fontSize: 13` | 「点击切换不同的单词书」 |
| `lib/pages/quick_spell_page.dart:188` | `bodySm` | 「该词书暂无合适的学习内容」 |
| `lib/pages/dictation_session_page.dart:157` | `bodySm` | 同上 |
| `lib/pages/spell_session_page.dart:167` | `bodySm` | 同上 |

- **用户痛点**：13px / bodySm 在低视力用户或阳光下可读性下降。
- **根因**：辅助说明未区分「正文」与「辅助文案」字号层级。
- **建议方案**：辅助文案最小 14sp；关键说明（如空态引导）使用 `bodyMd` 而非 `bodySm`。

---

### 3.4 品牌装饰色硬编码 — 【低】

- `lib/features/account/presentation/splash_page.dart:134-135`：`Color(0xFF1E3932)`、`Color(0xFFcba258)` 用于流星雨装饰。
- **用户痛点**：当用户切换暗色/自定义皮肤时，流星雨颜色不变，可能与主题冲突。
- **根因**：装饰性动效未接入 `skin.colors` token。
- **建议方案**：将装饰色映射到 `skin.colors.accent` / `skin.colors.gold` 等 token，或至少提供暗色fallback。

---

## 四、空 / 错 / 加载态

### 4.1 空状态质量参差不齐 — 【中】

| 等级 | file:line | 表现 |
|------|-----------|------|
| ✅ 优秀 | `lib/pages/check_in_history_page.dart:152` | 「还没有签到记录」+ 说明文案 + CTA「去签到」按钮 |
| ✅ 良好 | `lib/pages/lib_select_page.dart:175-177` | 「暂无词书」+ 「当前分类下没有词书，请切换分类或刷新」+ 说明 |
| ✅ 良好 | `lib/pages/word_export_page.dart:319,356` | 「该词书暂无单词可导出」 |
| ✅ 良好 | `lib/pages/quick_spell_page.dart:188` 等 | 「该词书暂无合适的学习内容」 |
| ⚠️ 一般 | `lib/features/scare_coin/presentation/scare_coin_history_page.dart` | 「还没有记录，先去签到吧～」— 无 CTA 按钮，用户不知道去哪签到 |
| ⚠️ 一般 | `lib/pages/my_fav_page.dart:197` | 「单词本为空」— 无引导/CTA |

- **用户痛点**：部分空态只给了一句文字，用户不知道下一步该做什么（如「还没有记录」但页面没有「去签到」按钮）。
- **根因**：空态无统一模板；各页面独立实现。
- **建议方案**：建立空态三要素模板：① 插图/图标 ② 说明文案 ③ 可选 CTA 按钮。`scare_coin_history_page` 补充「去签到」CTA，`my_fav_page` 补充「去添加单词」引导。

---

### 4.2 错误处理不一致 — 【中】

| 处理方式 | file:line | 表现 |
|----------|-----------|------|
| SnackBar 友好提示 | `lib/pages/lib_select_page.dart:532` | 「加载词书失败: $e」 |
| SnackBar 友好提示 | `lib/pages/word_export_page.dart:319` | 「该词书暂无单词可导出」 |
| 静默失败 | 部分 catch 块 | 仅 `print(e)` 或空 catch，用户无任何反馈 |
| 硬编码异常 | `lib/pages/dictionary_by_name_page.dart:63` | 直接 `Navigator.pop` 无 try-catch |

- **用户痛点**：部分场景操作失败时页面无任何反应，用户以为点击无效而重复操作。
- **根因**：无全局错误处理策略；各页面 catch 行为不一。
- **建议方案**：所有用户触发操作（按钮/手势）的 catch 必须给用户反馈（至少 SnackBar）；网络/DB 错误统一用 `AppMessages.error(context, '...')` 提示。

---

### 4.3 加载态缺失 — 【低】

- 部分页面从 Provider 读数据时直接 build，无骨架屏/loading 指示（如 `my_fav_page.dart` 收藏列表、`scare_coin_history_page.dart` 历史列表）。
- **用户痛点**：数据加载瞬间显示空态或旧数据，用户误以为无数据或卡顿。
- **根因**：异步数据加载无 `isLoading` 状态分支。
- **建议方案**：数据加载期显示 `Shimmer`/骨架屏或 `CircularProgressIndicator`，避免「闪空」。

---

## 汇总

| 严重度 | 数量 | 关键问题 |
|--------|------|----------|
| 高 | 1 | 「签到/打卡」术语不一致 |
| 中 | 6 | 返回图标不一致；「单词本/词书」概念混淆；装饰字无语义标签；IconButton 缺 tooltip；空状态缺 CTA；错误处理不一致 |
| 低 | 5 | SnackBar 无封装；开发中措辞乱；装饰色硬编码；英文品牌冗余；辅助字号偏小；加载态缺失 |

**优先修复建议**：
1. 「签到/打卡」全库统一为「签到」（高，影响功能认知）
2. 空态补充 CTA（中，影响新用户激活）
3. 装饰字加 `ExcludeSemantics`（中，影响无障碍合规）
4. IconButton 补 tooltip（中，影响触屏/无障碍）
5. SnackBar 统一封装（低，提升整体质感）

---

## 方法说明

- 覆盖范围：`lib/**` 全量扫描（account / settings / scare_coin / checkin / book / learning / features / pages / screens / widgets / tokens / shell）。
- 工具：`grep` 批量定位模式 + 关键文件精读。
- 未改 lib 代码、未 git commit/push、未跑全量 flutter test。
