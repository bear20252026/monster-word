# Monster Word 全盘质量工程纲领（Quality Engineering Program）

> 目标：商业级质量。不再「按用户报告逐个修」，而是**全盘一次体检 + 常驻回归门禁**。
> 任何横切问题（导航、状态、provider、空态、崩溃、依赖边界）进同一张**问题清单**，修完必配**回归测试**。

## 1. 全盘体检维度（每域必查）

| 维度 | 检查点 |
|------|--------|
| **静态/编译** | `flutter analyze` 0 error（新增代码不引入 warning/info） |
| **导航/进出栈** | 返回不黑屏；能逐级回首页；前进目标路由注册且参数齐；无 pushReplacement 破坏逐级返回 |
| **空态/参数** | 深链/恢复场景无参进入不 NPE/不白屏；空词表/空列表优雅降级 |
| **Provider/状态** | 每页用到的 provider 在该 scope 可用；无 `ProviderNotFound`；无 `setState after dispose`；无 `ModalRoute.of` 在 initState |
| **会话状态机** | 学/复习/听写/拼写/造句/沉浸：指数推进、完成回跳、进度竞态、currentWord null 处理 |
| **数据/解析** | book/word 的 JSON（interpret/example/phrase/root/audio）解析容错；列名匹配 |
| **音频** | 单词发音 + 例句发音接口正确、按钮齐全 |
| **架构边界** | import_guard 依赖方向；page 不直连他人 feature 内部；契约端口化 |
| **生命周期** | 动画/控制器 dispose；异步回调 mounted 守卫 |
| **资源** | 路由名/类名稳定；无未注册路由死点；无外部依赖新增 |

## 2. 定义域（15 秒可跑的质量门禁 = 常驻回归）

1. **静态门禁** `flutter analyze`：0 error / 无新增 warning。
2. **单测+widget 回归** `flutter test`：全绿，覆盖解析器/状态机/关键页面 widget。
3. **架构边界回归** `test/architecture/import_guard_test.dart`：0 违规（已存在，WS-3）。
4. **关键路径 widget 回归**（新增，覆盖每个域至少 1 页）：`test/quality/` 下按域。
   每页断言：正常渲染 + 无参/空态不崩 + 返回不黑屏 + 前进目标存在。
5. **提交门禁**：上述全绿 + `git diff` 仅限约定文件 + 无 `splash/login` 认证入口被误改。

## 3. 流程（本轮执行）

- **体检波**：5 个域并行只读审计 → 全量问题清单（P0–P3 + file:line + 根因）。
- **修复波**：按严重度派发修复，每修必配测试。
- **常驻化**：把「关键路径 widget 回归」纳入 `test/quality/`，随 CI/提交自动执行。

## 4. 状态

| 阶段 | 状态 |
|------|------|
| 体检波（5 域审计） | 进行中 |
| 修复波 | 待体检清单 |
| 常驻回归门禁 | 待建 |

*本文件为常驻产物：每次迭代在此追加/核对，保证「全盘体检 + 回归」可持续。*
