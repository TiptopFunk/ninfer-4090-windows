@echo off
setlocal EnableExtensions
cd /d "%~dp0"

set "BUILD_DIR=%~dp0_build_yarn_sm89"
set "OUTPUT_DIR=%~dp0_runtime_yarn"
set "LOG_FILE=%~dp0build_yarn_windows.log"

echo NInfer Windows YaRN build > "%LOG_FILE%"
echo Source: %CD% >> "%LOG_FILE%"

set "VCVARS="
for %%V in (
  "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
  "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
  "C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvars64.bat"
  "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvars64.bat"
) do if not defined VCVARS if exist "%%~V" set "VCVARS=%%~V"

if not defined VCVARS (
  echo ERROR: Visual Studio 2022 C++ tools were not found.
  echo Install Desktop development with C++ and try again.
  pause
  exit /b 10
)
call "%VCVARS%" >> "%LOG_FILE%" 2>&1
if errorlevel 1 goto :failed

where nvcc >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
  echo ERROR: CUDA Toolkit 13.1 or newer was not found in PATH.
  pause
  exit /b 11
)
where cmake >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
  echo ERROR: CMake was not found. Add the Visual Studio CMake component.
  pause
  exit /b 12
)

echo [1/4] Preparing FFmpeg development files...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\Prepare-FFmpeg-Windows.ps1" -Destination "%~dp0ffmpeg" >> "%LOG_FILE%" 2>&1
if errorlevel 1 goto :failed

echo [2/4] Configuring RTX 4080/4090 sm_89 Release build...
cmake -S . -B "%BUILD_DIR%" -G Ninja ^
  -DCMAKE_BUILD_TYPE=Release ^
  -DCMAKE_CUDA_ARCHITECTURES=89 ^
  -DNINFER_ENABLE_AVX2=ON ^
  -DBUILD_TESTING=OFF ^
  -DNINFER_BUILD_BENCHMARKS=OFF >> "%LOG_FILE%" 2>&1
if errorlevel 1 goto :failed

echo [3/4] Compiling... this can take a while.
cmake --build "%BUILD_DIR%" --config Release --parallel >> "%LOG_FILE%" 2>&1
if errorlevel 1 goto :failed

echo [4/4] Creating runtime directory...
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"
copy /Y "%BUILD_DIR%\apps\ninfer-serve.exe" "%OUTPUT_DIR%\" >> "%LOG_FILE%" 2>&1
copy /Y "%BUILD_DIR%\apps\ninfer.exe" "%OUTPUT_DIR%\" >> "%LOG_FILE%" 2>&1
copy /Y "%BUILD_DIR%\apps\ninfer-perplexity.exe" "%OUTPUT_DIR%\" >> "%LOG_FILE%" 2>&1
copy /Y "%~dp0ffmpeg\bin\*.dll" "%OUTPUT_DIR%\" >> "%LOG_FILE%" 2>&1

"%OUTPUT_DIR%\ninfer-serve.exe" --help > "%OUTPUT_DIR%\help.txt" 2>&1
findstr /C:"--rope-scaling-factor" "%OUTPUT_DIR%\help.txt" >nul
if errorlevel 1 (
  echo ERROR: Build finished, but YaRN command-line support was not detected.
  pause
  exit /b 20
)

echo.
echo BUILD SUCCESSFUL
echo Runtime: %OUTPUT_DIR%
echo Log:     %LOG_FILE%
pause
exit /b 0

:failed
echo.
echo BUILD FAILED. See:
echo %LOG_FILE%
pause
exit /b 1
