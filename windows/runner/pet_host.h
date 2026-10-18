#ifndef RUNNER_PET_HOST_H_
#define RUNNER_PET_HOST_H_

#include <windows.h>

// 桌面宠物窗口（Windows 独有）。
//
// ## 为什么必须是「另开一个顶层窗口」
//
// 置顶（TOPMOST）是**顶层窗口**才有的属性。应用内的浮层（子窗口/Overlay）无论
// 怎么画，都只能盖在本进程的窗口之上，永远压不住别的进程。所以「出了应用还能
// 看见」在 Win32 里只有一个答案：一个独立的顶层窗口。
//
// 而且这个窗口不能复用主窗口的 Flutter engine —— 一个 engine 只能服务一个
// FlutterView。所以宠物窗口跑**第二个 engine**，用独立 Dart entrypoint `petMain`。
//
// ## 窗口配置逐条对应 VPet 的 `VPet-Simulator.Windows/MainWindow.xaml`
//
//   VPet（C#/WPF）                          →  这里（Win32）
//   WindowStyle="None"                      →  WS_POPUP（无标题栏、无边框）
//   Background="{x:Null}"                   →  Dart 侧不画背景（Colors.transparent）
//   WindowChrome GlassFrameThickness="-1"   →  DwmExtendFrameIntoClientArea(-1,-1,-1,-1)
//   ShowInTaskbar="False"                   →  WS_EX_TOOLWINDOW（不进任务栏/Alt-Tab）
//   ResizeMode="NoResize"                   →  样式里没有 WS_THICKFRAME
//   Topmost（VPet 在代码里设）              →  HWND_TOPMOST
//
// ⚠️ VPet 是 C#/WPF，代码不能直接搬进 Flutter/Dart（运行时完全不同）。
//    能搬、也搬了的是**窗口配置语义** —— 上面这张表就是逐条对照的结果。
namespace pet_host {

// 主窗口句柄：宠物被双击时要把它拉到前台。
void SetMainWindow(HWND hwnd);

// 开 / 关宠物窗口。返回操作之后「是否可见」。
//
// |days| 是累计签到天数：宠物窗口跑在**另一个 engine** 上，读不到主应用的状态，
// 只能靠启动参数带过去（决定形态与肚皮）。< 0 表示不知道。
bool Toggle(int days);

// 当前是否已有宠物窗口。
bool IsVisible();

}  // namespace pet_host

#endif  // RUNNER_PET_HOST_H_
