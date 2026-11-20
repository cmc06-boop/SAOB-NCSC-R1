$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw "Flutter is not on PATH. Install Flutter and reopen the terminal first. See README.md."
}
& flutter pub get
if ($LASTEXITCODE -ne 0) { throw "Dependency setup failed." }
& flutter analyze
if ($LASTEXITCODE -ne 0) { throw "Static analysis failed." }
& flutter test
if ($LASTEXITCODE -ne 0) { throw "Tests failed." }
& flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw "Windows build failed. Run flutter doctor -v and check the Windows toolchain." }
Write-Host "Windows app ready: $ProjectRoot\build\windows\x64\runner\Release"
Write-Host "Distribute the entire Release folder, including data and DLLs."
