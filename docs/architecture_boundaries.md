# 架构边界与渐进迁移规则

本项目采用**渐进式重构**。当前目标不是一次性移动所有文件，而是先固定依赖方向、应用装配位置和每个模块的迁移完成条件。

## 1. 当前目标结构

```text
lib/
  app/                 # 应用启动、全局 Provider、路由装配（app/router/）、主题和首页装配
  core/                # 依赖注册、平台无关基础能力
  features/            # 后续按业务逐步迁移的垂直功能模块
  data/                # 本地数据库、DAO、持久化实现（迁移期遗留）
  repositories/        # 数据访问接口及实现（迁移期遗留）
  services/            # 用例服务（迁移期遗留）
  state/               # 页面状态 / Controller（迁移期遗留）
  pages/, screens/     # 现有展示层，按 feature 逐步迁移
  widgets/             # 跨功能纯展示组件；不得继续放入业务编排
  models/              # 跨 feature 共享域模型（定位见下文 §1.1）
  tokens/              # 设计令牌唯一定义处（色彩/阴影/品牌常量，M5 白名单）
  theme/               # 皮肤系统与壁纸数据（preset 定义处，M5 白名单）
```

`app/` 是应用装配层：`app_bootstrap.dart` 只初始化平台与基础设施，`app.dart` 只装配全局状态、主题、首页和路由。`main.dart` 仅启动这两个边界。

### 1.1 `models/` 的定位

`lib/models/` 是**跨 feature 共享域模型**的统一存放处，而非某个 feature 的私有目录。

- **准入标准**：被两个及以上 feature 消费、且只含数据结构（不可变实体 / 值对象 / 序列化模型）的类。当前存放 `word.dart`、`book.dart`、`definition.dart`、`new_word_record.dart`、`scare_coin_entry.dart` 等十余个模型。
- **禁止**：业务规则、数据访问、Widget、状态管理进入 `models/`；单 feature 专用的模型应留在该 feature 的 `domain/` 内，不得上提稀释共享层。
- **依赖方向**：`models/` 只依赖 Dart/Flutter 基础库与序列化库；不得 import `features/`、`data/`、`repositories/`、`services/`、`state/` 任何代码。
- **迁移期约定**：各 feature 现存私有模型副本在后续 feature 迁移时统一收敛到 `models/`（或明确留在 feature `domain/`），不新增第三种存放位置。

### 1.2 feature 内部分层的既定豁免

理想结构是每个 feature 内部具备 `presentation/`、`domain/`、`data/` 完整三层，但以下 feature 当前为**既定豁免**，按需补齐、不强制形式对齐：

- `content`：目前只有 `presentation/` 层（句库、句子学习等纯展示驱动场景），暂无独立 domain/data 需求；
- `scare_coin`、`word_browse`：缺少 `domain/` 层，业务规则较薄或暂由页面内联。

豁免不等于许可：这些 feature 新增代码仍须遵守 §2 依赖规则；一旦出现可提炼的领域规则或数据访问，应优先补齐对应层而不是继续堆在 presentation。新增 feature 默认按完整三层建立，不再进入豁免名单。

## 2. 依赖规则

| 来源 | 允许依赖 | 禁止依赖 |
|---|---|---|
| `app/` | `core/`、全局状态、页面装配 | 具体 DAO 业务调用、学习/复习规则实现 |
| `pages/`、`screens/` | State/Controller、纯展示组件、路由 | 新增对 DAO、Engine、播放器实现、`sl<T>()` 的直接依赖 |
| `state/` | Service/Repository 接口、纯领域规则 | `BuildContext`、页面导航、Widget 代码 |
| `services/` | Repository 接口、纯领域规则 | `BuildContext`、Widget、页面 |
| `repositories/` | Data 接口与模型 | 页面、State、Widget |
| `data/` | 平台库、数据库、序列化模型 | Provider、页面、Widget |

迁移期既有跨层引用暂时存在，**本轮不做大范围清理**。新增代码必须遵守该规则；每迁移一个功能，必须删除该功能对应的旧引用，而不是再增加一条兼容路径。

## 3. 服务定位器规则

`GetIt` 仅允许在组合根及 Provider 工厂使用：`app/`、`core/di/` 或测试初始化代码。页面、Widget、domain 代码不得新增 `sl<T>()` 调用。页面应通过 `Provider` 获取明确的 State/Controller，State 通过构造函数接收依赖。

## 4. 迁移顺序与完成定义

迁移按风险而非目录大小推进：

1. `learning`：消除 `LearningState` 与 `LearnState` 的双轨业务真相；
2. `review`：将评分、干扰项、释义格式化从页面移至纯规则和 Controller；
3. `dictionary` 与 `player`：消除页面直连数据库和播放器；
4. `user`、`settings`、`checkin`：迁入垂直 feature 目录；
5. 最后拆分跨功能 adapter 与网络客户端。

一个 feature 只有同时满足以下条件才算迁移完成：页面不直接访问 Data/Engine/Service Locator；Controller 不依赖 `BuildContext`；核心规则有单元测试；旧路径与兼容 Provider 被删除；CI 全绿。

## 5. 提交规则

每次提交只处理一个主要目标：结构、功能、视觉或数据之一。遇到一个缺陷需要修改三个以上页面时，先识别缺失的共享规则或用例入口，不以复制补丁的方式继续扩大修改面。

## 6. CI 渐进门禁

当前仓库的全量分析存在历史 warning 和 info。CI 在本阶段执行三类检查：改动 Dart 文件必须格式化、全量 `flutter analyze` 中 error 必须阻断、全量测试必须执行。warning 和 info 仍会输出并保留为技术债清单，暂不阻断合并；这样可以避免历史存量完全阻塞第一阶段结构治理，同时禁止新增改动引入格式债或编译错误。

后续每完成一个 feature 迁移，应同步清理该 feature 的 analyzer 告警。当全量 warning 降至可控范围后，再移除 `--no-fatal-warnings`；最后在 info 治理完成后移除 `--no-fatal-infos`。不得用忽略规则掩盖本轮新引入的 error。
