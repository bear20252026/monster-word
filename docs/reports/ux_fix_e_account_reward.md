# UX-FIX-E 账户/登录/设置/打卡/奖励 + 全局一致/可访问

> 修复来源：`docs/reports/ux_aux4_account_reward.md` + `ux_aux5_consistency.md` + `ux_master_ledger.md`  
> 修复范围：账户/登录/设置/打卡/奖励域 + 全局一致性与可访问性

---

## F-1 🔴 第三方登录死路

**文件**：`lib/features/account/presentation/login_page.dart`

**改动**：
- 移除未接入的微信/QQ/微博/华为第三方登录入口
- 移除 `_socialLogin` 方法（仅弹出"开发中" toast）
- 保留手机号登录、账号密码登录（已可用的登录方式）

**理由**：让用户点击后只收到"开发中" toast 是死路体验。未接入的入口应直接隐藏，避免用户产生挫败感。

---

## F-2 🔴 兑换中心硬编码余额

**文件**：`lib/pages/redemption_center_page.dart`

**改动**：
- 添加 `import 'package:provider/provider.dart'` 和 `import '../../core/scare_coin/scare_coin_store.dart'`
- `_coins = 1280`（硬编码）→ 从 `ScareCoinStore.balance()` 读取真实余额
- 兑换成功后调用 `ScareCoinStore.grant(delta: -item.cost, reason: '兑换 ${item.title}')` 扣减余额
- 余额不足时提示「还差 XX 币，快去签到赚取吧！」而非笼统的「尖叫币不足」
- 兑换成功提示「已解锁」而非「已到账」（更准确）

**测试**：`test/pages/redemption_center_page_ux_test.dart`
- 验证显示真实余额（100）而非硬编码（1280）
- 验证余额不足时显示「还差 XX 币」

---

## F-3 🔴 空态/错误态 CTA

### 尖叫币历史页

**文件**：`lib/features\scare_coin\presentation\scare_coin_history_page.dart`

**改动**：
- 空态从纯文本改为「还没有记录，先去签到吧～」+ 「去签到」按钮
- 按钮点击后执行 `Navigator.pop(context)` 返回上一页

### 签到历史页

**文件**：`lib/features/checkin/presentation\check_in_history_page.dart`

**改动**：
- 空态 CTA 从 `Navigator.pop(context)` 改为导航到 `/class_checkin` 签到页
- 错误提示添加「重试」按钮（`SnackBarAction`），点击后调用 `_refresh()` 重新加载

**测试**：
- `test/features/scare_coin/presentation/scare_coin_history_page_ux_test.dart`：验证空态含「去签到」按钮
- `test/features/checkin/presentation/check_in_history_page_ux_test.dart`：验证错误态含「重试」按钮、文案统一为「签到」

---

## F-4 🟡 统一安全返回

**文件**：
- `lib/features/checkin/presentation/class_checkin_page.dart`
- `lib/features/account/presentation/user_info_manage_page.dart`

**改动**：
- 添加 `import '../../../core/router/nav_utils.dart'`
- `Navigator.pop(context)` → `NavUtils.safePop(context)`（防止栈底黑屏）

---

## F-6 🟡 标题/「即将上线」标记

### 设置页标题

**文件**：`lib/features/settings/presentation/settings_page.dart`

**改动**：
- 标题从「学习偏好」改为「设置」（与导航入口名称一致）
- 添加 `_comingSoonBadge()` 方法渲染「即将上线」橙色标签
- `_Cell` 组件添加 `trailing` 参数以支持尾部标签
- 「助记顺序」和「更多学习偏好」入口添加「即将上线」标签
- 提示文案从「开发中」改为「即将上线，敬请期待」

### 班级签到设置按钮

**文件**：`lib/features/checkin/presentation/class_checkin_page.dart`

**改动**：
- 设置按钮添加「即将」Badge 标签
- 提示文案从「开发中」改为「即将上线，敬请期待」

---

## F-7 🟡 可访问性

### 登录按钮语义标签

**文件**：`lib/features/account/presentation/login_page.dart`

**改动**：
- 手机号登录、账号密码登录按钮包裹 `Semantics(label: '...', button: true)`

### 进度环语义标签

**文件**：`lib/features/checkin/presentation/check_in_history_page.dart`

**改动**：
- 月度进度环包裹 `Semantics(label: '本月进度 XX%')`

### 头像更换按钮

**文件**：`lib/features/account/presentation/user_info_manage_page.dart`

**改动**：
- `GestureDetector` → `InkWell`（带涟漪反馈）
- 包裹 `Semantics(label: '更换头像', button: true)`

### 正负 delta 图标

**文件**：`lib/features/scare_coin/presentation/scare_coin_history_page.dart`

**验证**：已使用 `Icons.trending_up` / `Icons.trending_down` 区分正负 delta，不纯靠颜色

---

## E-1 🔴 术语统一（打卡 → 签到）

**文件**：
- `lib/screens/home_screen.dart`：「打卡 +10」→「签到 +10」，注释「打卡角标」→「签到角标」
- `lib/features/checkin/presentation/class_checkin_page.dart`：全文「打卡」→「签到」（含标题、描述、按钮）

**理由**：统一使用「签到」作为用户可见术语，与 `check_in_widgets.dart`、`spring_check_in_calendar.dart`、`check_in_history_page.dart` 保持一致。

---

## E-4 🟡 装饰字 ExcludeSemantics

**文件**：`lib/features/account/presentation/splash_page.dart`

**改动**：
- Logo 中的装饰性文字「怪」包裹 `ExcludeSemantics`，避免屏幕阅读器朗读无意义字符

---

## E-5 🟡 IconButton tooltip

**文件**：`lib/lib/pages/lib_select_page.dart`

**改动**：
- 切换封面显示的 eye 图标添加 `tooltip: '切换封面显示'`
- 切换描述的 eye 图标添加 `tooltip: _showDescription ? '隐藏词书描述' : '显示词书描述'`

---

## E-6 🟡 其他空态 CTA

**文件**：`lib/pages/my_fav_page.dart`

**改动**：
- 「单词本为空」空态添加「去选词书」按钮（导航到 `/lib_select`）
- 保留「刷新」按钮，两者并排显示

---

## 测试结果

| 测试文件 | 测试用例 | 结果 |
|---------|---------|------|
| `test/features/scare_coin/presentation/scare_coin_history_page_ux_test.dart` | 空态含「去签到」按钮 | ✅ |
| `test/features/scare_coin/presentation/scare_coin_history_page_ux_test.dart` | 正负 delta 用图标区分 | ✅ |
| `test/features/checkin/presentation/check_in_history_page_ux_test.dart` | 空态含「去签到」按钮 | ✅ |
| `test/features/checkin/presentation/check_in_history_page_ux_test.dart` | 错误态含「重试」按钮 | ✅ |
| `test/features/checkin/presentation/check_in_history_page_ux_test.dart` | 文案统一为「签到」 | ✅ |
| `test/pages/redemption_center_page_ux_test.dart` | 显示真实余额（非硬编码 1280） | ✅ |
| `test/pages/redemption_center_page_ux_test.dart` | 余额不足时显示「还差 XX 币」 | ✅ |

**flutter analyze**：所有修改文件 0 error，无新增 warning/info。

---

## 未实施项

- **E-2 返回图标统一**：`dictionary_by_name_page.dart` 属于 dictionary feature（属 C/D 卡范围，本次禁止修改）
- **F-5 频率限制倒计时**：当前代码中无频率限制实现（此前为文档误判），无需修复

---

*修复完成时间：2026-08-29*  
*修复人：QA-词库*
