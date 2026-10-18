#include "flutter_window.h"

#include <optional>
#include <string>

#include "flutter/generated_plugin_registrant.h"
#include "pet_host.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // 桌面宠物窗口：开 / 关，返回操作后是否可见。
  // 宠物住在**独立的顶层窗口**里（见 pet_host.h 的说明），这里只是开关。
  pet_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "monster_word/pet_window",
      &flutter::StandardMethodCodec::GetInstance());
  pet_channel_->SetMethodCallHandler([](const flutter::MethodCall<flutter::EncodableValue>& call,
                                        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    if (call.method_name() == "toggle") {
      // 可选参数：累计签到天数（宠物窗口跑另一个 engine，读不到主应用状态）。
      int days = -1;
      if (const auto* args = std::get_if<flutter::EncodableList>(call.arguments());
          args != nullptr && !args->empty()) {
        if (const auto* value = std::get_if<int32_t>(&(*args)[0])) {
          days = *value;
        }
      }
      result->Success(flutter::EncodableValue(pet_host::Toggle(days)));
      return;
    }
    if (call.method_name() == "isVisible") {
      result->Success(flutter::EncodableValue(pet_host::IsVisible()));
      return;
    }
    result->NotImplemented();
  });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }
  pet_channel_ = nullptr;

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
