# 发布检查单（现行）

> 每次发版按序执行。历史一次性检查单（v2.0.0 收尾版）见 `docs/reports/release_checklist.md`。
> 签名方案与流水线细节见 `docs/release_pipeline.md`；提交规范见 `docs/commit_convention.md`。

## 1. 前置门禁（本地）

- [ ] `flutter analyze --no-fatal-infos` → No issues found
- [ ] `dart format --line-length 120 --set-exit-if-changed --output=none .` → 0 changed
- [ ] `flutter test test/architecture/` → 67 例全过（依赖分层/路由名单/token 单真相/棘轮守卫）
- [ ] `flutter test` → 全量通过
- [ ] `test -s assets/db/wordbook.db.gz`（词库资产基线在位）

## 2. 升号与提交

- [ ] `pubspec.yaml` 升 `version: X.Y.Z+NNN`（NNN 单调递增，与历史 tag 连续）
- [ ] 从 `main` 切 `release/x.y.z` 分支 → 提交 `chore(release): vX.Y.Z+NNN` → PR 合并回 `main`
- [ ] `installer.iss` 内 `MyAppVersion` 与 pubspec 一致（同 PR）

## 3. 打 tag 与云端出包

- [ ] `git tag vX.Y.Z+NNN && git push origin vX.Y.Z+NNN`
- [ ] Release Packages workflow：quality-gate（analyze+全量测试）→ android（真签名，缺 KEYSTORE_* secrets 直接熔断）→ windows（含 vc_redist Authenticode 验签、Dart 混淆）
- [ ] 产物命名核对：`MonsterWord_vX.Y.Z.apk/.aab`（debug 签名产物必带 `-debugsigned` 后缀，不得当正式包分发）、`MonsterWord_Setup_vX.Y.Z.exe`

## 4. Release 收口

- [ ] GitHub Release 自动创建：核对三件套齐全、非 draft/prerelease
- [ ] 装机实测（Windows 覆盖安装 + Android 覆盖安装；重点：词库首次解压路径、签到/金币、复习闭环）
- [ ] 发版记录文档（工作区 `monster-word-发版记录-*.md` 体系）归档

## 5. 发版后

- [ ] 清理远端 `release/x.y.z` 分支（可选，历史惯例）
- [ ] Sentry 观察崩溃率 24-48h；词库强制重建事件（REG-AUDIT 告警口径）应≈0
