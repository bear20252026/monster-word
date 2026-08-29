# UX-AUX-2 · 用户视角体检：单词详情 / 词典域

> **审计日期**: 2026-08-28  
> **审计范围**: word_detail_page、dictionary_page、search_page、word_dictionary_popup、word_machine_page、my_fav_page  
> **审计人**: Aion CLI  
> **约束**: 只读审计，未改动 lib/

---

## 摘要

| UX 严重度 | 数量 |
|-----------|------|
| 🔴 高     | 5    |
| 🟡 中     | 12   |
| 🟢 低     | 9    |
| **合计**  | **26** |

---

## 🔴 高 — 影响核心任务或造成明显困惑

### H-1 搜索页点击结果无跳转反馈

**文件**: `lib/features/search/presentation/search_page.dart:92`  
**痛点**: 搜索结果默认选中 `results.first`，但用户不知道"已选中"——没有高亮边框、没有背景色差、没有 ripple。用户点击一个单词后，右侧/下方的详情是否更新无法感知。  
**用户体感**: "我点了一下，什么都没发生。"  
**建议**: 选中项加背景色 (accent 5% alpha) + 左侧 3px accent 指示条，未选中项与选中项形成明显对比。

### H-2 词典详情页 TabController 6 个 tab 但无视觉引导

**文件**: `lib/features/dictionary/presentation/dictionary_page.dart:34`  
**痛点**: 6 个 tab (释义/例句/派生/词根/近义/真题)，但无 TabBarIndicator 或任何视觉引导告诉用户"当前在哪"、"还有什么内容"。用户可能只看第一个 tab 就离开，错过大量内容。  
**用户体感**: "这页面到底有多少内容？我看到的只是释义吗？"  
**建议**: 使用 `TabBar` + `TabBarView` 替代当前手动 `TabController` 切换，带下划线 indicator 和可滑动 tab bar。

### H-3 词典详情页没有收藏/加入生词本的即时视觉反馈

**文件**: `lib/features/dictionary/presentation/dictionary_page.dart:106-138`  
**痛点**: 收藏按钮 (star) 点击后只变图标颜色 (text3 → primary)，但无任何动画或 haptic 反馈。加入生词本按钮只弹 SnackBar 文字 "已加入生词本"，但按钮图标切换不明显 (bookmark_added vs bookmark_add_outlined 同色)。  
**用户体感**: "我点了收藏了吗？好像没反应。"  
**建议**: 收藏点击加 scale 动画 (0.8→1.0) + HapticFeedback.lightImpact；生词本按钮已有 SnackBar 但图标变化不够显著，建议加填充色区分。

### H-4 word_detail_page 收藏按钮无文字标签

**文件**: `lib/pages/word_detail_page.dart:271-293`  
**痛点**: 单词详情页右上角只有两个图标 (收藏 star + 笔记 edit_note)，无 tooltip、无文字标签。新用户可能不知道哪个是收藏、哪个是笔记。  
**用户体感**: "这个五角星是什么意思？"  
**建议**: 加 `tooltip: '收藏'` / `tooltip: '笔记'`，或在图标下方加 micro 文字标签。

### H-5 word_machine_page 单词详情弹出层无关闭手势提示

**文件**: `lib/pages/word_machine_page.dart:487-568`  
**痛点**: WordDetailPopup 弹出时，标题右侧有关闭按钮 (×)，但无拖拽关闭手势、无底部 sheet 拖拽条。用户可能不知道可以点 × 关闭。  
**用户体感**: "弹出来了怎么关？"  
**建议**: 底部加拖拽指示条 (8px 圆角横线) + 支持下滑关闭 (DragDownGesture)。

---

## 🟡 中 — 影响效率或产生轻度不适

### M-1 word_detail_page 释义区无层级视觉区分

**文件**: `lib/pages/word_detail_page.dart:414-503`  
**痛点**: 结构化释义 (`formattedDefinitions`) 中各词性 (n./v./adj.) 使用 heading5 粗体，但各条释义之间仅用 12px 间距区分。当一个词有 3+ 词性时，视觉上显得密密麻麻，扫读困难。  
**建议**: 词性标签用彩色 chip/tag (类似 dictionary_page 的 _buildTag)，释义条目用左侧 2px accent 竖线分组。

### M-2 词典详情页 CET 标签基于单词长度而非实际难度

**文件**: `lib/features/dictionary/presentation/dictionary_page.dart:182-193`  
**痛点**: 标签 (基础/核心/进阶) 是根据 `word.word.length` 硬编码划分的，不是真正的难度数据。"a" 被标为"基础"，"alphabet" 被标为"进阶"，但 "antidisestablishmentarianism" 也被标为"进阶"。用户看到标签会产生误解。  
**建议**: 要么移除这个标签（数据不准确），要么接入真实的难度数据源。

### M-3 搜索历史清除按钮无二次确认

**文件**: `lib/features/search/presentation/search_page.dart:138-153`  
**痛点**: 搜索历史区域有"清除"按钮，点击后直接调用 `_clearHistory()`，无确认弹窗。误触会导致搜索记录全部丢失。  
**建议**: 加 `showDialog` 二次确认，或用 `Undo` SnackBar。

### M-4 my_fav_page 批量编辑入口不明显

**文件**: `lib/pages/my_fav_page.dart:46-51`  
**痛点**: 批量编辑模式通过顶部 AppBar 的 `IconButton` 触发，但图标为 `Icons.edit` (通用编辑图标)，用户可能不会联想到"批量操作"。  
**建议**: 改为 `Icons.checklist` 或 `Icons.select_all`，或加 tooltip "批量操作"。

### M-5 word_detail_page 例句翻译显示但无朗读功能

**文件**: `lib/pages/word_detail_page.dart:683-708`  
**痛点**: 例句区有英文 + 中文翻译 + 音频播放按钮，但只有英文有喇叭图标。中文翻译旁边无任何操作。如果用户想听例句朗读，只听英文，但想对比中文理解时需要来回扫视。  
**建议**: 例句区可考虑折叠/展开翻译，减少视觉干扰。

### M-6 word_dictionary_popup 无底部操作栏

**文件**: `lib/widgets/word_dictionary_popup.dart:168-198`  
**痛点**: 弹出的词典卡片有收藏/生词本按钮和词根 tab，但底部直接是释义内容。用户想知道"还有例句吗？"或"还有更多吗？"——页面截止感模糊。  
**建议**: 底部加"查看详情"链接跳转到 word_detail_page，给用户明确的深入路径。

### M-7 search_page 搜索中 Loading 态仅为圆形进度

**文件**: `lib/features/search/presentation/search_page.dart:87`  
**痛点**: 搜索时 `_isLoading = true`，但 UI 层面可能只在某处显示 CircularProgressIndicator。用户搜索时如果网络慢，不知道在等什么。  
**建议**: 搜索框右侧显示加载 spinner，同时保持搜索框可编辑（取消按钮变为 spinner）。

### M-8 词典详情页与单词详情页功能重叠

**文件**: `lib/features/dictionary/presentation/dictionary_page.dart` vs `lib/pages/word_detail_page.dart`  
**痛点**: 两个页面展示类似内容（释义、音标、例句、词根），但 UI 风格完全不同。dictionary_page 用 Tab 布局，word_detail_page 用单列滚动。用户从搜索进入 dictionary_page，从学习进入 word_detail_page，可能困惑"这两个有什么区别？"  
**建议**: 统一为一个详情页，或明确区分使用场景（词典 = 查词浏览，详情 = 学习笔记）。

### M-9 word_machine_page 单词列表批量删除无进度指示

**文件**: `lib/pages/word_machine_page.dart:363-414`  
**痛点**: 批量删除 (_batchDelete) 是同步循环删除，大量单词时可能卡顿。虽然有 `_deleting` 状态锁，但 UI 上无进度条，用户不知道删了多少。  
**建议**: 加线性进度条或"正在删除 3/15"文字提示。

### M-10 词典详情页收藏无 SnackBar

**文件**: `lib/features/dictionary/presentation/dictionary_page.dart:137`  
**痛点**: 收藏按钮 (star) 点击后只变图标色，无 SnackBar 确认。加入生词本有 SnackBar，但收藏没有——两个操作的反馈不一致。  
**建议**: 收藏操作加 SnackBar "已收藏" / "已取消收藏"。

### M-11 my_fav_page 空态提示无引导

**文件**: `lib/pages/my_fav_page.dart`  
**痛点**: 当收藏列表为空时，预期只显示空态文案，但可能缺少"去查词"或"去学习"的引导按钮。新用户可能不知道收藏从哪里来。  
**建议**: 空态加"搜索并收藏单词"按钮引导到搜索页。

### M-12 word_detail_page 笔记日期格式为 YYYYMMDDHHmmss 字符串

**文件**: `lib/pages/word_detail_page.dart:965-969`  
**痛点**: `_formatDate` 从原始字符串 (如 `20260828120000`) 手动截取，没有用 DateTime/DateFormat。如果日期格式不匹配 14 位，会返回原始字符串（如 `20260828` 直接显示）。  
**用户体感**: "这个日期 20260828 是什么意思？"  
**建议**: 用 `intl` 包的 DateFormat 或手动补充为 "2026-08-28" 格式。

---

## 🟢 低 — 锦上添花，不影响使用

### L-1 word_detail_page 无锚点/快速跳转

**文件**: `lib/pages/word_detail_page.dart`  
**痛点**: 页面很长（释义 + 例句 + 词组 + 词根 + 笔记），但没有"快速跳转到笔记"或"快速跳转到例句"的锚点导航。  
**建议**: 加 floating 章节导航胶囊 (类似于 Notion 的 / 目录)。

### L-2 dictionary_page 没有分享按钮

**文件**: `lib/features/dictionary/presentation/dictionary_page.dart`  
**痛点**: 用户学了一个好词，想分享给朋友，但页面没有分享入口。  
**建议**: 顶部加 `Icons.share` 按钮，分享"我正在学 XXX — 释义/例句"。

### L-3 search_page 搜索框无 voice input

**文件**: `lib/features/search/presentation/search_page.dart:111-133`  
**痛点**: 搜索只支持文本输入，不支持语音查词。  
**建议**: 搜索框右侧加麦克风图标支持语音输入。

### L-4 word_detail_page 无"上一个/下一个"快速切换

**文件**: `lib/pages/word_detail_page.dart`  
**痛点**: 在学习流程中 (fromLearn=true)，虽然有"下一词"按钮，但在单词详情页内没有快速切换。用户如果想回顾上一个单词需要退出再进入。  
**建议**: 考虑加左右滑动手势切换。

### L-5 word_machine_page 单词详情弹出层无收藏操作

**文件**: `lib/pages/word_machine_page.dart:487-568`  
**痛点**: WordDetailPopup 展示了完整单词信息，但没有收藏/生词本按钮。用户想收藏一个遇到的单词，需要先关闭弹窗 → 点击进入详情页 → 再收藏。  
**建议**: 在弹出层底部操作栏加收藏图标。

### L-6 词典详情页真题 tab 数据可能为空

**文件**: `lib/features/dictionary/presentation/dictionary_page.dart:34`  
**痛点**: TabController 固定 6 个 tab，但"真题"tab 的数据可能为空。空 tab 仍可点击，用户点击后看到空白页。  
**建议**: 动态 tab 数量，或空 tab 时显示"暂无真题"提示。

### L-7 词典详情页四六级难度标签基于单词长度

**文件**: `lib/features/dictionary/presentation/dictionary_page.dart:182-193`  
**痛点**: 同 H-2 的子问题——单词长度不等于难度。4 字母单词不一定是"基础"（如 "lymph"）。  
**建议**: 优先使用语料库频率数据。

### L-8 my_fav_page 收藏列表无排序选项

**文件**: `lib/pages/my_fav_page.dart`  
**痛点**: 收藏列表只按添加顺序排列，无法按字母/收藏时间/难度排序。收藏多时浏览困难。  
**建议**: 顶部加排序下拉菜单。

### L-9 search_page 搜索结果无词频/难度标注

**文件**: `lib/features/search/presentation/search_page.dart:163-173`  
**痛点**: 搜索结果只显示单词 + 简短释义，无词频/难度信息。用户无法判断这个词是否常用。  
**建议**: 在单词右侧加"基础/核心/进阶"标签。

---

## 体检维度覆盖矩阵

| # | 维度 | 命中 |
|---|------|------|
| 1 | 上手/引导 | H-4, M-4, M-11 |
| 2 | 核心任务清晰 | H-1, H-2, M-1, M-8 |
| 3 | 反馈与微交互 | H-3, M-10, L-5 |
| 4 | 空/错/加载态 | M-7, L-6 |
| 5 | 一致性 | M-2, M-8, M-10 |
| 6 | 摩擦冗余 | M-6, M-8, L-4, L-5 |
| 7 | 可访问性 | H-4, L-1 |
| 8 | 文案语气 | M-12 |
| 9 | 会话/进度关联 | (无明显问题) |
| 10 | 视觉稳定 | M-1, M-9 |

---

## 修复优先级建议

### 第一批 (高优 — 影响核心查词/学词体验)
1. **H-1** 搜索结果选中态高亮
2. **H-4** word_detail 收藏/笔记 tooltip
3. **H-3** dictionary_page 收藏动画
4. **M-10** dictionary_page 收藏加 SnackBar
5. **M-8** 统一两个详情页或明确场景区分

### 第二批 (中优 — 效率提升)
6. **H-2** dictionary_page tab 栏视觉引导
7. **M-1** 释义层级视觉区分
8. **M-5** 例句翻译折叠
9. **M-6** popup 底部加"查看详情"
10. **M-12** 笔记日期格式化

### 第三批 (低优 — 锦上添花)
11. L-1 到 L-9
