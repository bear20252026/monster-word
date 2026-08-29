# B档设计语言迁移：account+settings+checkin+dictionary 半径/间距 token → context.design

**任务**: #01a04d43-2835-7493-adde-3f412903514a  
**日期**: 2026-08-29  
**Owner**: Aion CLI (teammate)

---

## 迁移概要

| Feature | 文件数 | 替换数 |
|---|---|---|
| account | 3 | 20 |
| settings | 3 | 10 |
| checkin | 7 | 35 |
| dictionary | 12 | 158 |
| **合计** | **25** | **223** |

---

## 替换规则

| 旧 token | 新 token |
|---|---|
| `AppRadius.xxx` | `context.design.radius.xxx` |
| `AppSpacing.xxx` | `context.design.spacing.xxx` |
| `AppleRadius.xxx` | `context.design.radius.xxx` |
| `AppleSpacing.xxx` | `context.design.spacing.xxx` |

- 仅 build 方法内替换（方法签名中的参数类型不动）
- `const` 自动移除（`context.design` 非 const）
- `design_tokens.dart` import 保留（颜色/排版/AppGlass 不动）
- `skin_system.dart` import 确认存在

---

## 修复

1. **collins_detail_intro_page.dart** — `_buildFallbackContent` 方法签名无 `BuildContext context` 参数，添加了 `BuildContext context` 并更新调用处传入 `context`。

---

## 验证结果

### flutter analyze
```
flutter analyze lib/features/account/presentation lib/features/settings/presentation lib/features/checkin/presentation lib/features/dictionary/presentation
→ No issues found! (ran in 18.0s)
```

### flutter test
```
flutter test test/features/account/ test/features/settings/ test/features/checkin/ test/features/dictionary/
→ 72/72 All tests passed!
```

---

## 跳过

- `responsive.dart` 结构常量未动
- 颜色（MistralColors.*）、排版（MistralTypography.*）、AppGlass 未动
- 不含 AppRadius/AppSpacing 的文件未动
