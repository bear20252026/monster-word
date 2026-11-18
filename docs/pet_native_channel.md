# 桌面宠物原生通道契约（Windows）

> 第四轮审计 M18（2026-11-18）补录。宠物窗口跑在**第二个 Flutter engine** 上，
> 与主应用不共享内存，所有跨窗口交互都经本 MethodChannel。改任一侧前先读本契约。

## 通道

- 名称：`monster_word/pet_window`
- 编解码：`StandardMethodCodec`
- **同名通道在两个 engine 各注册一份 handler**，按方法名分工（见下）。Dart 侧两处声明：
  - 主应用：`lib/core/infrastructure/pet_window_service.dart`（`PetWindowService.channel`）
  - 宠物窗口：`lib/pet_main.dart`（`petWindowChannel`）

## 主窗口侧 handler（`windows/runner/flutter_window.cpp`）

主应用 Dart → 原生，控制宠物窗口开关：

| 方法 | 参数 | 返回 | 语义 |
|---|---|---|---|
| `toggle` | `[days:int, personality:String?]`，`days` 缺省占位 `-1` | `bool`（操作后是否可见） | 开/关宠物窗口。`days`=累计签到天数（决定形态与肚皮），`personality`=性格枚举名（lively/calm/stubborn）。宠物 engine 读不到主应用状态，只能靠启动参数带过去（P2-3）。 |
| `isVisible` | 无 | `bool` | 当前宠物窗口是否开着（页面初始化对齐 UI 用）。 |

### 原生 → 主应用 Dart（主动推送）

| 方法 | 参数 | 语义 |
|---|---|---|
| `petVisibilityChanged` | `bool visible` | 宠物窗口可见性变化（开/关/宠物自己关闭）时原生主动 `InvokeMethod` 推送。审计 C6：设置页订阅后开关状态即时对齐真实窗口，不再只靠 initState 读一次。Dart 侧 `PetWindowService.visibilityChanges`（broadcast 流）消费，`listenVisibilityEvents()` 幂等安装 handler。 |

## 宠物窗口侧 handler（`windows/runner/pet_host.cpp`）

宠物窗口 Dart → 原生，宠物自己发起的窗口操作：

| 方法 | 参数 | 返回 | 语义 |
|---|---|---|---|
| `moveBy` | `[dx:double, dy:double]`（物理像素） | `void` | 按位移移动窗口。Dart 侧逻辑位移乘 `devicePixelRatio` 后传入。原生 `ClampToVirtualScreen` 钳制到虚拟屏（审计 R23：防拖出所有显示器外），再 `SetWindowPos(HWND_TOPMOST, SWP_NOSIZE\|SWP_NOACTIVATE\|SWP_NOSENDCHANGING)`。 |
| `openApp` | 无 | `void` | 双击宠物 → 还原并前置主窗口（`ShowWindow(SW_RESTORE)` + `SetForegroundWindow`）。 |
| `close` | 无 | `void` | 右键宠物 → 关掉自己。**不在通道回调里直接销毁窗口**，投递 `WM_CLOSE` 走正常消息循环；`OnDestroy` 清 `g_pet_window` 指针并 `NotifyVisibility(false)`（审计 C6）。 |

未识别方法返回 `NotImplemented`。

## 启动参数（原生 → 宠物 engine）

宠物 engine 经 `DartProject::set_dart_entrypoint("petMain")` 启动，
`set_dart_entrypoint_arguments` 传 `days=12`、`personality=calm` 这类键值对；
Dart 侧 `PetLaunchArgs.parse` 解析（`lib/pet_main.dart`）。

## 硬约束（改动前必读）

1. `petMain` 必须带 `@pragma('vm:entry-point')`，否则 AOT 裁掉；且必须被 `lib/main.dart` 引用（export），否则整个文件不进 app.so。
2. 宠物 engine **未注册插件**（`RegisterPlugins` 只对主 engine 调用）——不能碰 shared_preferences / 音频 / 网络。要加数据只能走启动参数，或在 `pet_host.cpp` 给该 engine 也注册插件。
3. 宠物窗口不套 Scaffold/Material，背景才透明（DWM 玻璃透出桌面）。
4. 非 Windows 平台 `PetWindowService` 一律返回 false / 空流，不碰通道。
