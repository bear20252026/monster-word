# WS-4 G1: 词书单词列表点击单词跳转 /word_detail

## 目标
补齐功能缺口：词书单词列表点击任意单词可跳转到单词详情页。

## 改动范围
仅修改 `lib/features/book/presentation/book_words_page.dart`。

## 改动内容

### 1. `_WordCard` 添加点击导航
```dart
return GestureDetector(
  onTap: () => Navigator.pushNamed(
    context,
    WordDetailPage.routeName,
    arguments: word,
  ),
  child: Container(
    // ... 原有布局
  ),
);
```

### 2. 添加 import
```dart
import '../../../pages/word_detail_page.dart';
```

### 3. `BookState` 添加测试方法
```dart
@visibleForTesting
void setWordsForTest(List<Word> words) {
  _words = words;
  _currentBookId = 1;
  notifyListeners();
}
```

## 测试

### 新增测试
`test/features/book/presentation/book_words_page_navigation_test.dart`

- 渲染 `BookWordsPage`，注入一个 `Word`
- 点击单词卡片（通过 `find.text('apple')` 查找）
- 验证 `Navigator.pushNamed` 被调用，路由名为 `/word_detail`，参数为 `Word` 对象

### 测试结果
- ✅ 新增测试：1/1 通过
- ✅ 全量测试：375/375 通过（含既有 374 + 新增 1）

## 边界遵守
- ✅ 仅修改 `lib/features/book/presentation/book_words_page.dart`
- ✅ 未触碰 core/app/theme/tokens
- ✅ 未触碰 learning/word_browse 模块
- ✅ 路由名 `/word_detail` 与 `WordDetailPage` 类名不变
