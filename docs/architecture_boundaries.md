# 架构边界与渐进迁移规则

本项目采用**渐进式重构**。当前目标不是一次性移动所有文件，而是先固定依赖方向、应用装配位置和每个模块的迁移完成条件。

## 1. 当前目标结构

```text
lib/
  app/                 # 应用启动、全局 Provider、主题和首页装配
  core/                # 依赖注册、路由、平台无关基础能力
  features/            # 后续按业务逐步迁移的垂直功能模块
  data/                # 本地数据库、DAO、持久化实现（迁移期遗留）
  repositories/        # 数据访问接口及实现（迁移期遗留）
  services/            # 用例服务（迁移期遗留）
  state/               # 页面状态 / Controller（迁移期遗留）
  pages/, screens/     # 现有展示层，按 feature 逐步迁移
  widgets/             # 跨功能纯展示组件；不得继续放入业务编排
```

`app/` 是应用装配层：`app_bootstrap.dart` 只初始化平台与基础设施，`app.dart` 只装配全局状态、主题、首页和路由。`main.dart` 仅启动这两个边界。

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
