@echo off
REM ====================================================================
REM  TVision wrapper - 전체 빌드 스크립트 (Win32 + Win64 DLL + Delphi demo)
REM  사전 요구사항:
REM    - vcpkg (D:\OpenSource\vcpkg 경로 또는 VCPKG_ROOT 환경변수)
REM    - Visual Studio 2022 + CMake
REM    - Delphi 13 (dcc64)
REM ====================================================================
setlocal

if "%VCPKG_ROOT%"=="" set VCPKG_ROOT=D:\OpenSource\vcpkg
set TOOLCHAIN=%VCPKG_ROOT%\scripts\buildsystems\vcpkg.cmake

echo === Installing tvision via vcpkg ===
"%VCPKG_ROOT%\vcpkg.exe" install tvision:x64-windows-static-md tvision:x86-windows-static-md
if errorlevel 1 goto :error

pushd "%~dp0wrapper"

echo === Configure x64 ===
cmake -S . -B build\x64 -G "Visual Studio 17 2022" -A x64 ^
    -DCMAKE_TOOLCHAIN_FILE="%TOOLCHAIN%" ^
    -DVCPKG_TARGET_TRIPLET=x64-windows-static-md
if errorlevel 1 goto :popfail

echo === Build x64 ===
cmake --build build\x64 --config Release
if errorlevel 1 goto :popfail

echo === Configure x86 ===
cmake -S . -B build\x86 -G "Visual Studio 17 2022" -A Win32 ^
    -DCMAKE_TOOLCHAIN_FILE="%TOOLCHAIN%" ^
    -DVCPKG_TARGET_TRIPLET=x86-windows-static-md
if errorlevel 1 goto :popfail

echo === Build x86 ===
cmake --build build\x86 --config Release
if errorlevel 1 goto :popfail

popd

echo === Copy DLLs to delphi\bin ===
if not exist "%~dp0delphi\bin" mkdir "%~dp0delphi\bin"
copy /Y "%~dp0wrapper\build\x64\bin\Release\tvision64.dll" "%~dp0delphi\bin\" >nul
copy /Y "%~dp0wrapper\build\x86\bin\Release\tvision32.dll" "%~dp0delphi\bin\" >nul

echo === Build Delphi demos ===
for %%P in (TVisionDemo MMenuDemo TvAppDemo TvEditDemo TvPaletteDemo TvDirDemo TvHc AvsColor TvFormsDemo) do (
    "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\dcc64.exe" -B ^
        -E"%~dp0delphi\bin" ^
        -N"%~dp0delphi\source" ^
        -U"%~dp0delphi\source" ^
        -I"%~dp0delphi\source" ^
        "%~dp0delphi\examples\%%P\%%P.dpr"
    if errorlevel 1 goto :error
)
REM remove intermediate .dcu produced inside source
del /q "%~dp0delphi\source\*.dcu" 2>nul

REM ----- Original C++ samples (tvision-src/examples) -----------------
if exist "%~dp0tvision-src\CMakeLists.txt" (
    echo === Configure original C++ samples ===
    cmake -S "%~dp0tvision-src" -B "%~dp0tvision-src\build\x64" ^
        -G "Visual Studio 17 2022" -A x64 ^
        -DCMAKE_TOOLCHAIN_FILE="%TOOLCHAIN%" ^
        -DVCPKG_TARGET_TRIPLET=x64-windows-static-md ^
        -DTV_BUILD_EXAMPLES=ON ^
        -DCMAKE_CXX_FLAGS=/utf-8 ^
        -DCMAKE_C_FLAGS=/utf-8
    if errorlevel 1 goto :error

    echo === Build original C++ samples ===
    cmake --build "%~dp0tvision-src\build\x64" --config Release
    if errorlevel 1 goto :error

    if not exist "%~dp0tvision-src\bin" mkdir "%~dp0tvision-src\bin"
    copy /Y "%~dp0tvision-src\build\x64\Release\*.exe" "%~dp0tvision-src\bin\" >nul
)

echo.
echo === DONE ===
echo   x64 DLL       : %~dp0wrapper\build\x64\bin\Release\tvision64.dll
echo   x86 DLL       : %~dp0wrapper\build\x86\bin\Release\tvision32.dll
echo   Delphi demos  : %~dp0delphi\bin\*.exe
echo   Original C++  : %~dp0tvision-src\bin\*.exe
exit /b 0

:popfail
popd
:error
echo *** BUILD FAILED ***
exit /b 1
