# 遗留问题清单

> **2026-09-20 重写。** 本文件为当前开口的唯一清单；闭环细节见 `docs/regression_ledger.md`。

| 优先级 | 项 | 说明 |
|---|---|---|
| 已闭环 | R1–R3 / N1–N11 / H1–H4 / M1–M9 | PR #44–#49 及 R4–R9 批 |
| P2 | ReviewScheduleRepository 以具体 ChangeNotifier 暴露 | 有意设计（N5） |
| P2 | widgets→core/repositories 放行 | import_guard 注释 |
| P3 | skin_system 直用 AppPreferences | 主题层无 R-prefs |
| 用户侧 | 微信提醒无通道 / 真机验证积压 | 业务安排 |

历史文档：git 中 `remaining_issues_2026-09-03.md` 旧版本、`docs/audit/*`、`docs/audit_followup_2026-09-04.md`。
