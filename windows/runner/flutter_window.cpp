#include "flutter_window.h"

#include <optional>
#include <cstring>
#include <shobjidl.h>
#include <wrl/client.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <string>
#include <vector>

#include "flutter/generated_plugin_registrant.h"

namespace {
std::wstring Wide(const std::string& value) {
  if (value.empty()) return {};
  const int size = MultiByteToWideChar(CP_UTF8, 0, value.data(),
                                      static_cast<int>(value.size()), nullptr, 0);
  if (size <= 0) return {};
  std::wstring output(size, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, value.data(),
                      static_cast<int>(value.size()), output.data(), size);
  return output;
}

std::string Utf8(const std::wstring& value) {
  if (value.empty()) return {};
  const int size = WideCharToMultiByte(CP_UTF8, 0, value.data(),
                                      static_cast<int>(value.size()), nullptr, 0,
                                      nullptr, nullptr);
  if (size <= 0) return {};
  std::string output(size, '\0');
  WideCharToMultiByte(CP_UTF8, 0, value.data(), static_cast<int>(value.size()),
                      output.data(), size, nullptr, nullptr);
  return output;
}

std::string StringArg(const flutter::EncodableMap& args, const char* key) {
  const auto it = args.find(flutter::EncodableValue(key));
  if (it == args.end()) return {};
  const auto* value = std::get_if<std::string>(&it->second);
  return value ? *value : std::string();
}

// This dialog only selects a path. Dart creates an exclusive new copy afterward.
// Never ask Windows to confirm replacement of an existing report.
void SelectExportPath(
    HWND owner, const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (call.method_name() != "select") {
    result->NotImplemented();
    return;
  }
  const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
  if (!args) {
    result->Error("arguments", "Missing export dialog arguments");
    return;
  }
  Microsoft::WRL::ComPtr<IFileSaveDialog> dialog;
  HRESULT hr = CoCreateInstance(CLSID_FileSaveDialog, nullptr,
      CLSCTX_INPROC_SERVER, IID_PPV_ARGS(dialog.GetAddressOf()));
  if (FAILED(hr)) {
    result->Error("dialog", "Unable to open Save As");
    return;
  }
  FILEOPENDIALOGOPTIONS options = 0;
  hr = dialog->GetOptions(&options);
  if (SUCCEEDED(hr)) {
    hr = dialog->SetOptions(
        (options & ~FOS_OVERWRITEPROMPT) | FOS_FORCEFILESYSTEM |
        FOS_PATHMUSTEXIST | FOS_NOTESTFILECREATE);
  }
  if (FAILED(hr)) {
    result->Error("dialog", "Unable to disable overwrite confirmation");
    return;
  }
  const auto extension = Wide(StringArg(*args, "extension"));
  const auto pattern = L"*." + extension;
  const COMDLG_FILTERSPEC filter = {
      extension == L"pdf" ? L"PDF Document" : L"Excel Workbook",
      pattern.c_str()};
  dialog->SetFileTypes(1, &filter);
  dialog->SetDefaultExtension(extension.c_str());
  const auto suggested = Wide(StringArg(*args, "suggestedName"));
  dialog->SetFileName(suggested.c_str());
  dialog->SetTitle(L"Save As");
  dialog->SetOkButtonLabel(L"Download");
  const auto directory = Wide(StringArg(*args, "initialDirectory"));
  if (!directory.empty()) {
    Microsoft::WRL::ComPtr<IShellItem> folder;
    if (SUCCEEDED(SHCreateItemFromParsingName(directory.c_str(), nullptr,
                                               IID_PPV_ARGS(folder.GetAddressOf())))) {
      dialog->SetFolder(folder.Get());
    }
  }
  hr = dialog->Show(owner);
  if (hr == HRESULT_FROM_WIN32(ERROR_CANCELLED)) {
    result->Success();
    return;
  }
  Microsoft::WRL::ComPtr<IShellItem> selected;
  if (FAILED(hr) || FAILED(dialog->GetResult(selected.GetAddressOf()))) {
    result->Error("dialog", "Unable to select export path");
    return;
  }
  PWSTR raw_path = nullptr;
  if (FAILED(selected->GetDisplayName(SIGDN_FILESYSPATH, &raw_path))) {
    result->Error("dialog", "Unable to read export path");
    return;
  }
  const std::string selected_path = Utf8(raw_path);
  CoTaskMemFree(raw_path);
  result->Success(flutter::EncodableValue(selected_path));
}
}  // namespace

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
  export_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "ncsc/export_save_as",
      &flutter::StandardMethodCodec::GetInstance());
  export_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        SelectExportPath(GetHandle(), call, std::move(result));
      });
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
  export_channel_.reset();
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
