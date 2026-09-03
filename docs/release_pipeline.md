# 【重构23】发布流水线：签名方案与发布检查单

> 承接：【重构10】构建审计（发现签名/权限/品牌问题）、【重构15】品牌资产计划（确定 Monster Word 命名与 2.0.0+2 版本策略）。
> 性质：**纯方案文档**。本文不生成 keystore、不改 gradle；所有命令与配置草案仅供实施任务执行。

---

## 1. Android 签名方案

### 1.1 现状回顾（重构10 审计结论）

`build.gradle.kts` 中 release 仍指向 debug keystore（模板 TODO 未替换）。正式发布前必须完成本节配置。

### 1.2 生成 release keystore（一次性，实施时执行）

```powershell
# 在项目外的密钥目录执行（见 1.3 存放建议）
keytool -genkey -v `
  -keystore monsterword-release.jks `
  -alias monsterword `
  -keyalg RSA -keysize 2048 `
  -validity 10000
```

提示时输入：
- 密钥库密码 / 密钥密码：**强密码，存入密码管理器**（不要写在任何文件里提交）；
- 组织信息：CN=Monster Word, OU=Lange, O=Lange, L/C 按实填写；
- validity 10000 天 ≈ 27 年：覆盖应用全生命周期。**签名一旦用于对外分发就不可更换**（换了签名用户无法覆盖安装），所以第一步就把有效期拉满。

### 1.3 存放位置与备份纪律（绝不入 git）

| 规则 | 说明 |
|---|---|
| 存放位置 | 项目目录之外，如 `D:\keys\monsterword\monsterword-release.jks`；若必须放项目内则放 `android/app/upload-keystore.jks` |
| git 防护 | `android/.gitignore` **已预置** `key.properties`、`**/*.keystore`、`**/*.jks` 三条规则 ✓，无需改动；提交前 `git status` 复查一遍即可 |
| 备份 | 至少 **2 份离线备份**（U盘/移动硬盘各一），与电脑分地存放；丢失 keystore = 无法再发布可覆盖安装的更新，等于产品重置 |
| 密码纪律 | 密码只进密码管理器 + key.properties（本地）；禁止出现在聊天记录、文档、CI 明文变量里 |

### 1.4 build.gradle.kts signingConfig 草案（密码走 key.properties / 环境变量）

本地开发：`android/key.properties`（已被 gitignore，模板自带）：

```properties
storePassword=<从密码管理器粘贴>
keyPassword=<同上>
keyAlias=monsterword
storeFile=D:/keys/monsterword/monsterword-release.jks
```

`android/app/build.gradle.kts` 草案：

```kotlin
import java.util.Properties
import java.io.FileInputStream

// 优先读 key.properties（本地），缺失时回退环境变量（CI 场景）
val keystoreProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) load(FileInputStream(f))
}
fun prop(name: String) =
    keystoreProps.getProperty(name)
        ?: System.getenv("MW_${name.uppercase()}")

android {
    signingConfigs {
        create("release") {
            val sp = prop("storePassword")
            if (sp != null) {                       // 有凭据才装配，无凭据不报错
                storeFile = file(prop("storeFile")!!)
                storePassword = sp
                keyAlias = prop("keyAlias")
                keyPassword = prop("keyPassword")
            }
        }
    }
    buildTypes {
        release {
            // 有正式签名用正式的；没有就保持 debug 并在 CI 上显式警告，
            // 绝不允许悄悄拿 debug 包当 release 发。
            signingConfig = if (prop("storePassword") != null)
                signingConfigs.getByName("release")
            else signingConfigs.getByName("debug")
        }
    }
}
```

CI 场景：四个值注入为 GitHub Actions **Secrets**（MW_STORE_PASSWORD 等），job 里临时写出 key.properties 再构建，结束后删除。

---

## 2. Windows 发布清单：代码 → MonsterWord_vX.Y.Z_Windows_x64.zip

前提（一次性，属【重构15】实施范围）：BINARY_NAME 已改为 `MonsterWord`、图标已替换、Runner.rc 展示名已统一。

| 步骤 | 操作 | 说明 |
|---|---|---|
| 1 | 改 `pubspec.yaml` → `version: X.Y.Z+N` | **版本号唯一源头**，见下方同步点说明 |
| 2 | `git add pubspec.yaml && git commit -m "chore(release): vX.Y.Z"` 并打 tag `vX.Y.Z` | 版本变更可追溯 |
| 3 | `flutter clean && flutter pub get` | 清掉旧构建缓存 |
| 4 | `flutter analyze`（建议去掉 `--no-fatal-warnings`） | 当前 CI 配置 warning 不拦截 ⚠️ |
| 5 | `flutter test` | 单测全绿 |
| 6 | 确认 `assets/db/wordbook.db.gz` 是真词库 | ⚠️ CI 里是 placeholder 占位文件，本地发布必须核实 |
| 7 | `flutter build windows --release --obfuscate --split-debug-info=build/debug-info` | 产物在 `build/windows/x64/runner/Release/`；`--obfuscate` 启用 Dart 代码混淆，`--split-debug-info` 分离调试符号（保留用于 crash 日志还原） |
| 8 | 核对产物四要素 | ① exe 名 = `MonsterWord.exe` ② 右键属性版本号 = X.Y.Z ③ 图标为新 logo ④ `data/flutter_assets/fonts/` 下有 Inter/Charter（旧产物曾缺字体） |
| 9 | 冒烟测试：双击运行 | 启动屏→主页→查词发音→复习打卡走一遍 |
| 10 | 打包 zip | 结构：zip 解压后直接是 `MonsterWord/` 文件夹（exe+data+dll），命名 `MonsterWord_vX.Y.Z_Windows_x64.zip` |
| 11 | 记录 SHA256 | `Get-FileHash <zip> -Algorithm SHA256`，写入 release notes |
| 12 | 归档到 `release/`，确认 `_archive/` 内无旧品牌名混入 | 与历史原应用产物隔离 |

**版本号同步点澄清**（避免重复维护）：

- `pubspec.yaml` 的 `version` 是**唯一需要手改的地方**；
- Windows 的 Runner.rc 中 FILEVERSION/PRODUCTVERSION 由 flutter 构建工具从 pubspec **自动注入**，手工改了也会被下次构建覆盖；
- Android 的 versionName/versionCode 同样由 pubspec 派生（versionCode 取 build number N）；
- 所以流程里只有步骤 1 一处改动，其余自动跟随。

**CI 顺带改进建议**（供后续任务）：`.github/workflows/build.yml` 的 artifact 名仍是 `bubei-word-windows`（旧品牌拼音残留 ⚠️）→ 改 `monsterword-windows`；analyze 步骤建议移除 `--no-fatal-warnings`；可在 job 末尾加自动打 zip 步骤产出规范命名的包。

---

## 3. 发布检查单（Checklist）

每次发版逐项勾选，全绿才允许出包。

### A. 构建正确性

- [ ] `pubspec.yaml` 版本号已 bump 且与本次 tag 一致
- [ ] `flutter clean && flutter pub get` 后重新构建
- [ ] `flutter analyze` ERROR = 0（目标 WARNING = 0）
- [ ] `flutter test` 全部通过
- [ ] `wordbook.db.gz` 为真实词库而非 placeholder
- [ ] 无遗留 `print` / debug 日志输出

### B. Android 发布面

- [ ] 主 Manifest 已加 `<uses-permission android:name="android.permission.INTERNET"/>`
- [ ] release 使用正式 keystore 签名（**非 debug**）：`apksigner verify --print-certs` 核对证书 CN
- [ ] key.properties / *.jks 未出现在 `git status`（未入库）
- [ ] `android:label` = Monster Word
- [ ] launcher 图标全套替换（5 密度 + 自适应图标）
- [ ] 启动屏浅色 #F2F0EB / 夜间 #1E3932 双模式正常
- [ ] just_audio 已移除、无冗余依赖

### C. Windows 发布面

- [ ] exe 名 = MonsterWord.exe；窗口标题 = Monster Word
- [ ] Runner.rc ProductName/FileDescription = Monster Word；右键属性版本号正确
- [ ] 图标 = 新 logo（资源管理器/任务栏可见）
- [ ] `data/flutter_assets/fonts/` 含 Inter + Charter 全部 7 个字体文件
- [ ] sqlite3.dll 在位（sqflite_common_ffi 运行依赖）
- [ ] zip 命名 `MonsterWord_vX.Y.Z_Windows_x64.zip`，解压即用，SHA256 已记录

### D. 流程与合规

- [ ] 冒烟测试通过（启动/查词/发音/复习/设置五项）
- [ ] git tag vX.Y.Z 已推送
- [ ] release notes 已写（新特性 + SHA256）
- [ ] `release/_archive/` 外无原应用等旧品牌字样文件
- [ ] 本地归档区无未改名的历史产物外泄风险

---

## 4. 版本策略落地：2.0.0+2 从哪个提交生效

**生效点：品牌化改造合入 main 的那个合并提交（merge commit）。**

具体约定：

1. 【重构15】的实施 PR（图标替换 + 四处应用名统一 + 启动屏配色 + 删 just_audio + INTERNET 权限 + `version: 2.0.0+2`）**全部放在同一个 PR** 内；
2. 该 PR 合入 main 的 merge commit 即 2.0.0 起点：合入后 main 上任何一次构建产出的都是 2.0.0+2；
3. 合入后立即在 merge commit 上打 tag `v2.0.0`，作为首个 Monster Word 正式版的锚点；
4. 此前的过渡期构建一律视为内部预览版，不得对外分发（它们仍叫 word_app.exe / 1.x，正好天然区分）；
5. 之后遵循「发版必 bump」纪律：每次出正式包都按第 2 节步骤 1–2 先改版本号再构建，杜绝同号不同内容。

理由复述（承接【重构15】：品牌重塑+UI重构属 breaking 大改版，major 升级与旧 v1.0 一刀切；build 号从 2 单调递增，为将来应用内更新检测留好空间）。

---

*制定人：BuildScout（【重构23】）· 2026-08-24 · 纯文档，未生成 keystore、未改动 gradle*
