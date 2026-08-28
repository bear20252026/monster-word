# WS-5 D1: word_detail_page 例句/词组/词根词缀改为结构化正确显示

## 目标
将 `word_detail_page.dart` 中 phrase（词组/搭配）和 wordRoot（词根词缀）从原始 JSON 字符串渲染改为结构化展示。

## 改动范围
仅修改：
- `lib/pages/word_detail_page.dart`（展示逻辑 + initState 延迟加载修复）
- `test/pages/word_detail_phrase_root_test.dart`（新增测试）

## 改动内容

### 1. phrase 结构化展示（桌面端 + 移动端）

**桌面端（`_buildDesktopLayout`，约 L511-524）：**
```dart
// 词组/搭配（结构化展示）
if (PhraseParser.hasData(word.phrase)) ...[
  SizedBox(height: AppleSpacing.lg),
  Text('词组/搭配', style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
  SizedBox(height: AppleSpacing.xs),
  _PhraseGroupList(raw: word.phrase, skin: skin),
],
// 词根词缀
if (word.wordRoot.isNotEmpty) ...[
  SizedBox(height: AppleSpacing.lg),
  Text('词根词缀', style: MistralTypography.heading5.copyWith(color: skin.colors.text2)),
  SizedBox(height: AppleSpacing.xs),
  WordRootTab(wordRootJson: word.wordRoot),
],
```

**移动端（`_buildMobileLayout`，约 L704-716）：** 同样的结构化替换。

### 2. 新增 `_PhraseGroupList` + `_PhraseGroupCard` 组件

在 `word_detail_page.dart` 底部添加两个私有 StatelessWidget：

- `_PhraseGroupList`：调用 `PhraseParser.parse(raw)` 解析 JSON，遍历 `List<PhraseGroup>` 渲染 `_PhraseGroupCard`
- `_PhraseGroupCard`：展示类型标签（固定搭配/常用词组）、英文短语、中文翻译、exams 标签、音频播放按钮（`context.read<AudioPlaybackState>().playWord(item.en)`）

### 3. initState 延迟加载修复（副产物修复）

`_loadNotes()` 和 `_loadExtra()` 在 `initState` 中调用了 `_resolveTargetWord()`，后者依赖 `ModalRoute.of(context)`。在 `initState` 执行时 element 尚未挂载，`ModalRoute.of(context)` 会抛出 `_ModalScopeStatus` 异常。

修复方式：用 `WidgetsBinding.instance.addPostFrameCallback` 将首次调用延迟到首帧后：

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    _loadNotes();
    _loadExtra();
  });
}
```

### 4. 新增 import

```dart
import '../data/phrase_parser.dart';
import '../widgets/word_root_tab.dart';
```

## 测试

### 新增测试
`test/pages/word_detail_phrase_root_test.dart` — 5 个用例：

| # | 测试场景 | 验证 |
|---|---------|------|
| 1 | 有 phrase 数据 | 渲染英文短语（say hello / hello world）、中文（打招呼 / 你好世界）、exams 标签（四级）；不出现原始 JSON |
| 2 | 有 wordRoot 数据 | 渲染词根内容（bio=生命 / log=学科） |
| 3 | 无 phrase 数据 | 不显示「词组/搭配」区块 |
| 4 | 无 wordRoot 数据 | 不显示「词根词缀」区块 |
| 5 | phrase + wordRoot 同时存在 | 两个区块都显示 |

### 测试结果
- ✅ 新增测试：5/5 通过
- ✅ `flutter analyze`：0 issues（lib + test 两文件）

## 边界遵守
- ✅ 仅修改 `lib/pages/word_detail_page.dart` + 新增测试文件
- ✅ 未触碰 learning/domain/data 等其他模块
- ✅ 未触碰 core/app/theme/tokens
- ✅ `WordDetailPage` 公开接口（构造函数、`routeName`）不变
- ✅ 使用既有 `PhraseParser` / `WordRootTab` 组件，未新增外部依赖
