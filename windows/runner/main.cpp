#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter_windows.h>
#include <windows.h>

#include <algorithm>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);

  // Use the primary monitor work area to pick a DPI-aware, centered startup
  // size so users don't need to manually resize on launch.
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  HMONITOR monitor = MonitorFromPoint(POINT{0, 0}, MONITOR_DEFAULTTOPRIMARY);
  MONITORINFO monitor_info{};
  monitor_info.cbSize = sizeof(MONITORINFO);
  if (monitor && GetMonitorInfo(monitor, &monitor_info)) {
    const int work_width_px = monitor_info.rcWork.right - monitor_info.rcWork.left;
    const int work_height_px = monitor_info.rcWork.bottom - monitor_info.rcWork.top;
    const UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
    const double scale_factor = dpi / 96.0;

    const int work_width_logical =
        static_cast<int>(work_width_px / scale_factor);
    const int work_height_logical =
        static_cast<int>(work_height_px / scale_factor);

    int target_width = static_cast<int>(work_width_logical * 0.9);
    target_width = std::clamp(target_width, 1100, 1600);
    int target_height = target_width * 9 / 16;

    const int max_height = static_cast<int>(work_height_logical * 0.9);
    if (target_height > max_height) {
      target_height = max_height;
      target_width = target_height * 16 / 9;
    }

    target_width = std::max(900, target_width);
    target_height = std::max(600, target_height);

    const int centered_x =
        static_cast<int>(monitor_info.rcWork.left / scale_factor) +
        (work_width_logical - target_width) / 2;
    const int centered_y =
        static_cast<int>(monitor_info.rcWork.top / scale_factor) +
        (work_height_logical - target_height) / 2;

    origin = Win32Window::Point(std::max(0, centered_x), std::max(0, centered_y));
    size = Win32Window::Size(static_cast<unsigned int>(target_width),
                             static_cast<unsigned int>(target_height));
  }

  if (!window.Create(L"athan_call_to_success", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
