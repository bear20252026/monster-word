# ARCH-FIX-5/C2-P1 账户/设置/尖叫币/签到域遗留壳迁移

> 任务：把 account/settings/scare_coin/checkin 相关 `lib/pages/*.dart` 里仍含真实实现的遗留业务壳迁入 feature 四层，并把对应 lib/pages 文件改为 `export '...'` 垫片。Additive、安全、不删 shim。

---

## 迁移清单

### T1：纯 re-export（跳过，不作改动）

| lib/pages 文件 | 说明 |
|---|---|
| `login_page.dart` | 已是 re-export → `features/account/presentation/login_page.dart` |
| `account_info_page.dart` | 已是 re-export → `features/account/presentation/account_info_page.dart` |
| `user_info_manage_page.dart` | 已是 re-export → `features/account/presentation/user_info_manage_page.dart` |
| `settings_page.dart` | 已是 re-export → `features/settings/presentation/settings_page.dart` |
| `more_settings_page.dart` | 已是 re-export → `features/settings/presentation/more_settings_page.dart` |
| `scare_coin_history_page.dart` | 已是 re-export → `features/scare_coin/presentation/scare_coin_history_page.dart` |
| `check_in_history_page.dart` | 已是 re-export → `features/checkin/presentation/check_in_history_page.dart` |
| `appearance_page.dart` | 已是 re-export → theme 目录 |
| `my_space_page.dart` | 已是 re-export → `features/account/presentation/my_space_page.dart` |

### T2：含真实逻辑（已迁移）

| 原 lib/pages 路径 | 新 feature 路径 | 备注 |
|---|---|---|
| `lib/pages/feedback_page.dart` | `lib/features/account/presentation/feedback_page.dart` | 帮助与反馈页，表单+提交+感谢页 |
| `lib/pages/help_page.dart` | `lib/features/account/presentation/help_page.dart` | 帮助页，WebView 加载帮助文档 |
| `lib/pages/linked_me_middle_page.dart` | `lib/features/account/presentation/linked_me_middle_page.dart` | 联想记忆中间页 |
| `lib/pages/message_page.dart` | `lib/features/account/presentation/message_page.dart` | 消息中心，消息列表 |
| `lib/pages/my_equip_page.dart` | `lib/features/account/presentation/my_equip_page.dart` | 我的装备页 |
| `lib/pages/net_diagnosis_page.dart` | `lib/features/settings/presentation/net_diagnosis_page.dart` | 网络诊断页 |
| `lib/pages/redemption_center_page.dart` | `lib/features/scare_coin/presentation/redemption_center_page.dart` | 兑换中心（已含 UX-FIX-E 改动：真实余额、还差 XX 币） |

### 跳过（属其它 feature，禁止触碰）

| lib/pages 文件 | 归属 feature | 跳过原因 |
|---|---|---|
| `dashboard_page.dart` | learning | 导入 `features/learning/presentation/learning_statistics_state.dart`，属 off-limits |
| `foot_mark_page.dart` | word_browse | 浏览收藏域，不在本次范围 |
| `personal_stereo_page.dart` | player | 播放域，不在本次范围 |
| `play_order_page.dart` | player | 播放域，不在本次范围 |
| `ui_theme_select_page.dart` | theme | 主题选择属 theme 功能域，禁止触碰 |

---

## 迁移模式（每页统一）

1. 读 `lib/pages/<x>.dart`，确认含真实逻辑（非纯 re-export）
2. 创建 `lib/features/<f>/presentation/<x>_page.dart`，复制全部逻辑
3. 修正相对导入路径（`../` → `../../../`）
4. 将 `lib/pages/<x>.dart` 替换为单行：`export '../features/<f>/presentation/<x>_page.dart';`
5. 保持类名、routeName 不变，确保路由/import 兼容

---

## 本地验证结果

### flutter analyze

```
Analyzing 11 items...
No issues found! (ran in 21.6s)
```

覆盖范围：`lib/features/account`、`lib/features/settings`、`lib/features/scare_coin`、`lib/features/checkin`、已迁移的 7 个 lib/pages shim 文件。

### flutter test

```
00:04 +56: All tests passed!
```

覆盖范围：`test/features/account`、`test/features/settings`、`test/features/scare_coin`、`test/features/checkin`，共 56 测试全部通过。

---

## 关键修复

- `redemption_center_page.dart`：迁移时保留了 UX-FIX-E 改动（真实余额、`还差 XX 币`、`已解锁` 文案、`ExcludeSemantics`、tooltip）
- `net_diagnosis_page.dart`：迁移至 settings feature，导入路径已修正
- 所有 shim 文件保持单行 re-export，不删除、不改路由

---

*迁移完成时间：2026-08-29*  
*迁移人：QA-词库*
