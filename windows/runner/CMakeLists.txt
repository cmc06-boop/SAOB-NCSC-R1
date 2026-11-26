cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# Generate an independent Windows icon in the build directory.
# The original UI logo and checked-in default icon remain untouched.
set(NCSC_LOGO "${CMAKE_CURRENT_SOURCE_DIR}/../../assets/ncsc-logo-transparent.png")
set(NCSC_ICON_GENERATOR "${CMAKE_CURRENT_SOURCE_DIR}/resources/generate_ncsc_icon.ps1")
set(NCSC_APP_ICON "${CMAKE_CURRENT_BINARY_DIR}/ncsc_app_icon.ico")
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
  "${NCSC_LOGO}" "${NCSC_ICON_GENERATOR}")
execute_process(
  COMMAND powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass
    -File "${NCSC_ICON_GENERATOR}" -Source "${NCSC_LOGO}" -Destination "${NCSC_APP_ICON}"
  RESULT_VARIABLE NCSC_ICON_RESULT
)
if(NOT NCSC_ICON_RESULT STREQUAL "0" OR NOT EXISTS "${NCSC_APP_ICON}")
  message(FATAL_ERROR "Failed to generate the NCSC Windows application icon.")
endif()

# Keep the resource script in source control and configure only a build copy.
configure_file("Runner.rc" "${CMAKE_CURRENT_BINARY_DIR}/Runner.rc" @ONLY)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "${CMAKE_CURRENT_BINARY_DIR}/Runner.rc"
  "runner.exe.manifest"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the build version.
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")

# Disable Windows macros that collide with C++ standard library functions.
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

# Add dependency libraries and include directories. Add any application-specific
# dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib" "ole32.lib" "shell32.lib" "uuid.lib")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}" "${CMAKE_CURRENT_SOURCE_DIR}")

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)
