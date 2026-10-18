#include "pet_host.h"

#include <dwmapi.h>
#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <optional>
#include <string>
#include <utility>

#include "win32_window.h"

namespace {

// 宠物窗口尺寸（逻辑像素；Create 会按 DPI 缩放）。
constexpr int kPetWindowWidth = 220;
constexpr int kPetWindowHeight = 280;

// 距工作区边缘的留白。
constexpr int kScreenMargin = 12;

HWND g_main_window = nullptr;

// ---------------------------------------------------------------------------
// 透明：两件事一起做才有「只剩怪兽浮在桌面上」的效果
// ---------------------------------------------------------------------------
//
// 1. `DwmExtendFrameIntoClientArea(-1,-1,-1,-1)` —— 把整块客户区变成「玻璃」，
//    等价于 VPet 的 `<WindowChrome GlassFrameThickness="-1" />`。
// 2. `SetWindowCompositionAttribute(WCA_ACCENT_POLICY, ACCENT_ENABLE_TRANSPARENTGRADIENT,
//    GradientColor = 0)` —— 把玻璃的底色刷成全透明。
//
// 只做 1 不做 2：部分机器上玻璃会带一层淡淡的磨砂底色，看起来像「半透明黑框」。
// 这个 API 没有正式文档（Win7 起存在，Win10/11 稳定），flutter_acrylic 的
// `WindowEffect.transparent` 用的就是它。取不到就只保留 DWM 那条路，不崩。
enum ACCENT_STATE : DWORD {
  kAccentDisabled = 0,
  kAccentTransparentGradient = 2,
};

struct ACCENT_POLICY {
  ACCENT_STATE AccentState;
  DWORD AccentFlags;
  DWORD GradientColor;
  DWORD AnimationId;
};

enum WINDOWCOMPOSITIONATTRIB : DWORD {
  kWcaAccentPolicy = 19,
};

struct WINDOWCOMPOSITIONATTRIBDATA {
  WINDOWCOMPOSITIONATTRIB Attrib;
  PVOID pvData;
  SIZE_T cbData;
};

using SetWindowCompositionAttributeFn = BOOL(WINAPI*)(HWND, WINDOWCOMPOSITIONATTRIBDATA*);

void ApplyTransparency(HWND hwnd, bool on) {
  MARGINS margins;
  margins.cxLeftWidth = on ? -1 : 0;
  margins.cxRightWidth = on ? -1 : 0;
  margins.cyTopHeight = on ? -1 : 0;
  margins.cyBottomHeight = on ? -1 : 0;
  ::DwmExtendFrameIntoClientArea(hwnd, &margins);

  HMODULE user32 = ::GetModuleHandleW(L"user32.dll");
  if (user32 == nullptr) {
    return;
  }
  auto set_composition_attribute = reinterpret_cast<SetWindowCompositionAttributeFn>(
      ::GetProcAddress(user32, "SetWindowCompositionAttribute"));
  if (set_composition_attribute == nullptr) {
    return;
  }

  ACCENT_POLICY policy{};
  policy.AccentState = on ? kAccentTransparentGradient : kAccentDisabled;
  policy.AccentFlags = 0;
  policy.GradientColor = 0;  // ARGB = 0x00000000：全透明
  policy.AnimationId = 0;

  WINDOWCOMPOSITIONATTRIBDATA data{};
  data.Attrib = kWcaAccentPolicy;
  data.pvData = &policy;
  data.cbData = sizeof(policy);
  set_composition_attribute(hwnd, &data);
}

// 放到当前显示器工作区的右下角（多屏时取窗口所在那块）。
void PlaceBottomRight(HWND hwnd) {
  RECT rect{};
  if (!::GetWindowRect(hwnd, &rect)) {
    return;
  }
  const int width = rect.right - rect.left;
  const int height = rect.bottom - rect.top;

  HMONITOR monitor = ::MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
  MONITORINFO info{};
  info.cbSize = sizeof(info);
  if (!::GetMonitorInfoW(monitor, &info)) {
    return;
  }
  const int x = info.rcWork.right - width - kScreenMargin;
  const int y = info.rcWork.bottom - height - kScreenMargin;
  ::SetWindowPos(hwnd, HWND_TOPMOST, x, y, 0, 0, SWP_NOSIZE | SWP_NOACTIVATE);
}

double ArgAsDouble(const flutter::EncodableValue& value) {
  if (const auto* d = std::get_if<double>(&value)) {
    return *d;
  }
  if (const auto* i = std::get_if<int32_t>(&value)) {
    return static_cast<double>(*i);
  }
  if (const auto* l = std::get_if<int64_t>(&value)) {
    return static_cast<double>(*l);
  }
  return 0.0;
}

// ---------------------------------------------------------------------------
// 宠物窗口：一个顶层窗口 + 它自己的 Flutter engine
// ---------------------------------------------------------------------------
class PetWindow : public Win32Window {
 public:
  explicit PetWindow(flutter::DartProject project) : project_(std::move(project)) {}

  ~PetWindow() override = default;

  PetWindow(const PetWindow&) = delete;
  PetWindow& operator=(const PetWindow&) = delete;

 protected:
  bool OnCreate() override {
    if (!Win32Window::OnCreate()) {
      return false;
    }

    RECT frame = GetClientArea();
    controller_ = std::make_unique<flutter::FlutterViewController>(
        frame.right - frame.left, frame.bottom - frame.top, project_);
    if (!controller_->engine() || !controller_->view()) {
      return false;
    }

    SetChildContent(controller_->view()->GetNativeWindow());
    ApplyTransparency(GetHandle(), true);
    PlaceBottomRight(GetHandle());

    // 宠物自己发起的窗口操作（拖动 / 关掉自己 / 打开主应用）。
    channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        controller_->engine()->messenger(), "monster_word/pet_window",
        &flutter::StandardMethodCodec::GetInstance());
    channel_->SetMethodCallHandler([this](const flutter::MethodCall<flutter::EncodableValue>& call,
                                          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
      const std::string& method = call.method_name();
      if (method == "moveBy") {
        double dx = 0;
        double dy = 0;
        if (const auto* args = std::get_if<flutter::EncodableList>(call.arguments()); args != nullptr && args->size() == 2) {
          dx = ArgAsDouble((*args)[0]);
          dy = ArgAsDouble((*args)[1]);
        }
        RECT rect{};
        if (::GetWindowRect(GetHandle(), &rect)) {
          ::SetWindowPos(GetHandle(), HWND_TOPMOST, rect.left + static_cast<int>(dx),
                         rect.top + static_cast<int>(dy), 0, 0,
                         SWP_NOSIZE | SWP_NOACTIVATE | SWP_NOSENDCHANGING);
        }
        result->Success(flutter::EncodableValue());
        return;
      }
      if (method == "openApp") {
        if (g_main_window != nullptr) {
          ::ShowWindow(g_main_window, SW_RESTORE);
          ::SetForegroundWindow(g_main_window);
        }
        result->Success(flutter::EncodableValue());
        return;
      }
      if (method == "close") {
        // 不在通道回调里直接销毁窗口：投递 WM_CLOSE，走正常消息循环。
        ::PostMessage(GetHandle(), WM_CLOSE, 0, 0);
        result->Success(flutter::EncodableValue());
        return;
      }
      result->NotImplemented();
    });

    // 首帧就绪后再显示，避免闪一下白底。
    controller_->engine()->SetNextFrameCallback([this]() { Show(); });
    controller_->ForceRedraw();
    return true;
  }

  void OnDestroy() override {
    channel_ = nullptr;
    controller_ = nullptr;
    Win32Window::OnDestroy();
  }

  LRESULT MessageHandler(HWND hwnd, UINT const message, WPARAM const wparam, LPARAM const lparam) noexcept override {
    if (controller_) {
      std::optional<LRESULT> result = controller_->HandleTopLevelWindowProc(hwnd, message, wparam, lparam);
      if (result) {
        return *result;
      }
    }
    return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
  }

 private:
  flutter::DartProject project_;
  std::unique_ptr<flutter::FlutterViewController> controller_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

std::unique_ptr<PetWindow> g_pet_window;

}  // namespace

namespace pet_host {

void SetMainWindow(HWND hwnd) {
  g_main_window = hwnd;
}

bool IsVisible() {
  return g_pet_window != nullptr;
}

bool Toggle(int days) {
  if (g_pet_window != nullptr) {
    // Destroy 会走 OnDestroy → 释放 engine；析构里再 Destroy 一次是安全的空操作。
    g_pet_window->Destroy();
    g_pet_window = nullptr;
    return false;
  }

  flutter::DartProject project(L"data");
  // 独立 entrypoint：lib/pet_main.dart 的 petMain（带 @pragma('vm:entry-point')）。
  project.set_dart_entrypoint("petMain");
  // 与主窗口一致：Impeller(OpenGLES) 在部分 GPU 上首帧挂起，回退 Skia。
  project.set_impeller_switch(flutter::ImpellerSwitch::Disabled);
  // 两个 engine 不共享内存：宠物需要的状态只能这样带过去。
  if (days >= 0) {
    project.set_dart_entrypoint_arguments({"days=" + std::to_string(days)});
  }

  auto window = std::make_unique<PetWindow>(project);
  // WS_POPUP = 无标题栏/无边框；两个扩展样式 = 不进任务栏 + 置顶。
  if (!window->Create(L"Monster Word Pet", Win32Window::Point(10, 10),
                      Win32Window::Size(kPetWindowWidth, kPetWindowHeight), WS_POPUP,
                      WS_EX_TOOLWINDOW | WS_EX_TOPMOST)) {
    return false;
  }
  g_pet_window = std::move(window);
  return true;
}

}  // namespace pet_host
