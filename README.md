# Monster Word

**Monster Word** 是一款以怪兽养成为激励主线的智能英语单词学习应用，基于 Flutter 构建，当前发布 **Windows** 与 **Android** 双端。

复习调度采用 FSRS 记忆算法，词库与例句全部离线随包，无需联网即可完成学习闭环。

## 核心特性

- **科学复习**：FSRS 记忆算法调度，学习记录与记忆状态本地 SQLite 持久化。
- **怪兽养成激励**：怪兽小屋（个人中心）、肚皮储蓄罐签到仪式、聚宝日历、金币庆祝等一整套正向反馈体系。
- **离线词库与例句**：词库数据库随包内置（`assets/db/wordbook.db.gz`），例句覆盖率 89%+，支持单词发音与例句朗读。
- **多词书管理**：内置词书分类与封面体系。
- **桌面 / 移动双端自适应**：Windows 宽屏布局与 Android 移动布局分别适配打磨。
- **设计系统单真相**：色板 / 圆角 / 字号全部走主题 token，配套 fontScale 棘轮、radius 棘轮与 WCAG 对比度守卫，防止 UI 退化。

## 技术栈

| 项 | 说明 |
|---|---|
| 框架 | Flutter（CI 固定 3.47.0），Dart SDK `^3.13.0` |
| 包名 | `word_app`（工程包名沿用，产品名为 Monster Word） |
| 数据 | SQLite（词库 / 学习记录 / FSRS 状态） |
| Windows 安装器 | Inno Setup（`installer.iss`） |
| 数据脚本 | `scripts/`（Python / Shell，词库构建与数据修补） |

## 快速开始

```bash
flutter pub get
flutter run -d windows        # Windows 桌面端
flutter run -d <android 设备> # Android 端
```

## 质量门禁

推送到 `main` 及发版 tag 由 GitHub Actions 承担（`.github/workflows/`）：

| 工作流 | 内容 |
|---|---|
| Flutter CI（`dart.yml`） | 词库资产基线校验 → `dart format`（120 列）检查 → `flutter analyze`（0 error 基线）→ 全量 `flutter test` |
| Build Windows Release（`build.yml`） | Windows 构建验证 |
| Release Packages（`release_packages.yml`） | tag 触发，产出三件套安装包并创建 GitHub Release |

本地提交前建议必跑：

```bash
flutter analyze --no-fatal-infos
dart format --line-length 120 --set-exit-if-changed .
flutter test test/architecture/   # 架构守卫：import 边界、路由名单、主题 token 单真相等
flutter test                      # 全量测试
```

其中 `test/architecture/` 是本仓库的架构护栏：依赖分层、路由命名、主题 token 单真相、fontScale / radius 棘轮、swallowed-error 上报等均有守卫测试，回潮即红。

## 发版流程

1. 从 `main` 切出 `release/x.y.z` 分支，在 `pubspec.yaml` 与 `installer.iss` 中升号，PR 合并回 `main`。
2. 打 tag `vX.Y.Z+NNN`（与 pubspec 版本严格一致）。
3. Release Packages 工作流产出 `Setup_vX.Y.Z.exe` / `.aab` / `.apk` 三件套并创建 GitHub Release。

详细检查单见 `docs/release_checklist.md`，签名与流水线方案见 `docs/release_pipeline.md`。

## 目录速览

```
lib/          应用代码（按架构边界分层）
test/         单元 / 组件 / 架构守卫测试（test/architecture/ 为护栏）
assets/db/    离线词库与例句数据
scripts/      词库构建、数据修补与校验脚本
docs/         工程文档（规范与台账）
installer.iss Windows 安装器脚本
```

## 文档索引

- `docs/architecture_boundaries.md` —— 架构边界现行规范（import 分层、路由、主题 token）
- `docs/regression_ledger.md` —— 回归台账（REG-ID 体系）
- `docs/reports/` —— 历史报告归档（整体标记 HISTORICAL，为过程快照而非现状）
