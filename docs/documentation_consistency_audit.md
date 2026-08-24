# 文档一致性审查报告 v2（最终版）

> 执行人：Aion CLI（teammate）
> 日期：2026-08-25
> 范围：docs/ 目录全部文档 + 关键平台命名文件交叉验证
> 验证时 HEAD：`0f72aac`
> 本版性质：在 v1 自动扫描基础上进行人工复核与裁定，修正 v1 的批量误报。

---

## 一、审查结论

**✅ PASS —— 应用名已统一，无需修改任何文档。**

- 当前态引用一律使用 **Monster Word / MonsterWord**；
- 文档中残留的旧名称出现均为**合法保留项**（历史记录、数据来源描述、代码标识符、归档路径），替换它们反而会破坏法律审计文档与技术文档的准确性；
- v1 审计建议「将 Mistral/不背单词 统一替换为 Monster Word」属于误报，本版予以纠正。

---

## 二、命名规范（项目既定约定）

依据 `docs/branding_assets_plan.md`，项目采用**双形态品牌命名规范**：

| 形态 | 用途 | 示例 |
|---|---|---|
| **Monster Word**（含空格） | 展示名：窗口标题、桌面图标名、应用内文案、android:label | `Monster Word` |
| **MonsterWord**（无空格） | 文件/产物名：exe 名、zip 包名、InternalName 等 | `MonsterWord.exe` |

团队名 "Monster world" 为组织名称，与应用名无关。

### 平台命名实测（当前源码状态）

| 文件 | 字段 | 值 | 符合规范 |
|---|---|---|---|
| pubspec.yaml | description | "Monster Word - 智能英语单词学习" | ✅ |
| android/app/src/main/AndroidManifest.xml | android:label | "Monster Word" | ✅ |
| windows/runner/main.cpp | 窗口标题 | L"Monster Word" | ✅ |
| windows/runner/Runner.rc | FileDescription / ProductName | "Monster Word" | ✅ |
| windows/runner/Runner.rc | InternalName / OriginalFilename | "MonsterWord" / "MonsterWord.exe" | ✅ |

**结论：平台层命名 100% 符合既定双形态规范，无残留模板默认名或旧品牌名。**

---

## 三、docs/ 中旧名称出现的分类裁定

对 v1 扫描出的全部命中逐条人工复核上下文，分类如下：

### 3.1 「不背单词」（原 App 品牌）—— 全部为合法保留

| 上下文类型 | 代表文档 | 裁定 |
|---|---|---|
| 数据来源/权属描述（法律审计核心内容） | wordbook_license_audit.md、dictionary_license_review.md、privacy_security_report.md | **必须保留**——这些文档的职责就是证明数据来自「不背单词」服务端，替换后失去证据效力 |
| 历史版本记录 | changelog_v2.0.0.md、git_release_readiness.md、git_health_report.md | **保留**——历史事实不可改写 |
| 旧产物隔离/清理清单 | release_checklist.md、release_pipeline.md、build_config_audit.md、branding_assets_plan.md | **保留**——清单本身就是要按这个名字去检查清理 |
| 归档路径引用 | security_reverse_engineering_report.md、reference_index.md | **保留**——指向实际存在的归档目录名 |

### 3.2 「Mistral*」—— 全部为合法保留

| 上下文类型 | 代表文档 | 裁定 |
|---|---|---|
| Dart 类名/Token 标识符（`MistralColors`、`MistralTypography`） | batch2_token_spec.md、batch4_page_spec.md、live_pages_hardcode_map.md、hardcode_color_audit.md、visual_consistency_report.md 等 | **必须保留**——`lib/tokens/design_tokens.dart` 中类名实际如此，改名属于代码重构任务而非文档一致性问题；文档描述代码现状必须用真名 |
| 旧设计主题的历史描述（"原 Mistral 橙色主题"、"旧 Mistral 色阶"） | dark_skin_strategy.md、starbucks_migration_plan.md、batch3_component_integration_report.md | **保留**——描述设计演进历史 |
| 目录名引用（`mistral.ai/DESIGN.md`） | assets_inventory.md | **保留**——真实存在的目录名 |
| 字体来源注释引用（pubspec 注释"Mistral AI：Inter + Charter"） | font_strategy.md | **保留**——引用 pubspec 原文 |

### 3.3 「UnlearnableWord」

仅在 documentation_consistency_audit.md v1 自身的发现列表中出现，docs 其他文档无此名称的实际使用，无处理需要。

---

## 四、v1 自动审计的勘误

v1 版本（脚本生成于 2026-08-24）存在系统性误报：

| v1 问题 | 说明 | 本版处置 |
|---|---|---|
| 将所有「不背单词」判定为应替换 | 忽略了上下文（历史记录/数据来源/清理清单均不可替换） | 纠正为「合法保留」 |
| 将 `MistralColors.*` 等 Token 类名判定为应替换为 "Monster Word" | 这些是真实存在的代码标识符，替换会破坏技术文档正确性 | 纠正为「合法保留」 |
| 未区分「展示名」与「产物名」双形态规范 | 导致规范表述自相矛盾 | 本版第 2 节明确规范并实测验证 |

v1 的原始扫描明细仍有留档价值，但其「建议行动」部分以本版裁定为准。

---

## 五、遗留事项（非本次范围，仅登记）

1. **Token 体系统一**：`design_tokens.dart`（MistralColors 等旧类名）→ skin.colors/星巴克 token 的迁移已在 architecture_health_report.md、documentation_consistency_summary.md 登记，属代码重构路线图事项，与文档一致性无关。
2. info 级 lint 与测试中 deprecated API 更新，见 regression_test_v4.md 第 2.3 节。

---

## 六、最终裁定表

| 检查维度 | 结果 |
|---|---|
| 当前态应用名统一（Monster Word/MonsterWord 双形态） | ✅ 通过 |
| 平台命名文件（Android/Windows/pubspec） | ✅ 通过，零残留 |
| docs/ 旧名称残留 | ✅ 全部为合法上下文，无需修改 |
| 需要修改的文档数量 | **0** |

**审查完成。**

*Aion CLI · 2026-08-25*
