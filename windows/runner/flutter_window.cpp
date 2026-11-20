#include "flutter_window.h"

#include <optional>
#include <cstring>

#include "flutter/generated_plugin_registrant.h"

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

  // Preserve the normal Windows frame and controls, with no caption logo.
  const HWND hwnd = GetHandle();
  SetWindowLongPtr(hwnd, GWL_EXSTYLE,
                   GetWindowLongPtr(hwnd, GWL_EXSTYLE) | WS_EX_DLGMODALFRAME);
  SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED);
  BYTE and_mask[128];
  BYTE xor_mask[128] = {};
  std::memset(and_mask, 0xff, sizeof(and_mask));
  caption_icon_ = CreateIcon(nullptr, 32, 32, 1, 1, and_mask, xor_mask);
  if (caption_icon_) {
    SendMessage(hwnd, WM_SETICON, ICON_SMALL,
                reinterpret_cast<LPARAM>(caption_icon_));
  }

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
  if (caption_icon_) {
    DestroyIcon(caption_icon_);
    caption_icon_ = nullptr;
  }
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

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
    case WM_GETMINMAXINFO: {
      auto* info = reinterpret_cast<MINMAXINFO*>(lparam);
      const double scale = GetDpiForWindow(hwnd) / 96.0;
      info->ptMinTrackSize.x = static_cast<LONG>(1000 * scale);
      info->ptMinTrackSize.y = static_cast<LONG>(620 * scale);
      return 0;
    }
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
