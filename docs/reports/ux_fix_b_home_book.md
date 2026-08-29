# UX-FIX-B · 首页/书架修复报告

> **任务来源**: UX Master Ledger 域 B  
> **日期**: 2026-08-28  
> **涉及文件**: 3 个  
> **测试文件**: 1 个 (7 tests, all green)  
> **flutter analyze**: 0 errors  

---

## 改动清单

### 1. `lib/screens/home_screen.dart` — 3 处修复

#### B-1 (🔴高): Learn 空态引导

**行 148-168**: 无词书时 SnackBar 文案改为「还没有词书，先去选一本吧」，新增 `SnackBarAction(label: '去选词书', ...)` 导航到 LibSelectPage。

```dart
// Before
ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(content: Text('暂无词书，请先添加词书')),
);

// After
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: const Text('还没有词书，先去选一本吧'),
    action: SnackBarAction(
      label: '去选词书',
      onPressed: () {
        if (context.mounted) {
          Navigator.pushNamed(context, LibSelectPage.routeName);
        }
      },
    ),
  ),
);
```

#### B-3: 尖叫币说明 (已移至 profile_screen.dart — 见下方)

home_screen.dart 无尖叫币展示，B-3 修复在 profile_screen.dart 完成。

#### B-6 (🟡): 日期中英混用

**行 27-31**: 英文星期名 (`Mon./Tue./...`) 改为中文 (`周一/周二/...`)；日期格式从 `MM/DD` 改为 `X月X日`。

```dart
// Before
const weekdays = ['Mon.', 'Tue.', 'Wed.', 'Thu.', 'Fri.', 'Sat.', 'Sun.'];
return '${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')} ${weekdays[now.weekday - 1]}';

// After
const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
return '${now.month}月${now.day}日 ${weekdays[now.weekday - 1]}';
```

---

### 2. `lib/pages/lib_select_page.dart` — 1 处修复

#### B-2 (🔴高): 词书描述硬编码

**行 494-502**: `_LibItem` 新增 `_categoryOf` 静态方法，从 `book.code` 动态推断分类。

**行 589-592**: 硬编码 `'考研核心高频 | 2026'` 改为 `'${_categoryOf(book.code)} | ${book.wordCount}词'`。

```dart
// Before
Text('考研核心高频 | 2026', ...)

// After
Text('${_categoryOf(book.code)} | ${book.wordCount}词', ...)
```

支持的分类映射（复用 `_LibSelectPageState._categoryOf` 逻辑）:
- `CET4/四级` → `CET4`
- `CET6/六级` → `CET6`
- `GK/高考` → `高考`
- `KY/考研` → `考研`
- `IELTS` → `雅思`
- `TOEFL` → `托福`
- `GRE/GMAT/SAT/BEC/TEM` 等 → `专业出国`
- 其他 → `其他`

---

### 3. `lib/screens/profile_screen.dart` — 3 处修复

#### B-3 (🔴高): 尖叫币说明

**行 249-287**: `_CoinCard` 外层包裹 `Tooltip`，文案「尖叫币是学习奖励货币，签到/学词可赚取，可用于兑换主题装备」；标题旁加 `Icons.help_outline_rounded` 图标暗示可点；余额旁加「学习奖励」说明文字。

#### B-5 (🟡): 装备卡片 chevron 暗示可点但无导航

**行 316-320**: 移除 `Icons.chevron_right`，因为装备卡片当前无导航目标。

#### B-4 (🟡): 学习偏好假卡片

**行 211-237**: `_menuRow` 的 `Icons.chevron_right` 改为条件渲染：`if (onTap != null)` 时才显示 chevron。`'学习偏好'` 无 onTap 参数 → 不再显示箭头，弱化点击暗示。

```dart
// Before
Icon(Icons.chevron_right, size: 18, color: skin.colors.text3),

// After
if (onTap != null) Icon(Icons.chevron_right, size: 18, color: skin.colors.text3),
```

---

## 测试结果

| 测试 | 结果 |
|------|------|
| B-1: 无词书时 SnackBar 含「去选词书」CTA | ✅ |
| B-2: CET4 code → 描述含「CET4」 | ✅ |
| B-2: CET6 code → 描述含「CET6」 | ✅ |
| B-2: KY code → 描述含「考研」 | ✅ |
| B-2: GK code → 描述含「高考」 | ✅ |
| B-2: 未知 code → 描述含「其他」 | ✅ |
| B-6: 日期格式不含英文星期 | ✅ |
| **合计** | **7/7 全绿** |

---

## 改动总结

| 类型 | 数量 |
|------|------|
| 修改文件 | 3 |
| 新增测试文件 | 1 |
| 新增测试用例 | 7 |
| Flutter analyze | 0 errors |

### 未改动确认
- ❌ 未触碰 `lib/app/**`、`lib/core/**`、`lib/theme/**`、`lib/tokens/**`、`lib/features/**`
- ❌ 未触碰 `lib/widgets/review_dialog.dart`
- ❌ 未 git commit/push
- ❌ 未跑全量 flutter test
