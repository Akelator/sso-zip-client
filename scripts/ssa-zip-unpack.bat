@echo off
setlocal EnableExtensions EnableDelayedExpansion

cd /d "%~dp0"
set "zipName=ssa-zip.zip"
set "errorId=0"
set "root=%cd%"

rem =========================
rem IGNORE LIST
rem =========================
set "ignore[0]=%zipName%"
set "ignore[1]=ssa-zip.exe"
set "ignore[2]=ssa-zip-pack.bat"
set "ignore[3]=ssa-zip-unpack.bat"
set "ignoreMax=3"

rem 1) Check ZIP exists
if not exist "%zipName%" (
    echo [ERROR] ZIP file not found.
    set "errorId=8"
    goto :end
)

rem 2) Check destination folder is empty, ignoring allowed items
set "hasBlockingContent=false"

for /R %%F in (*) do (
    set "full=%%~fF"
    set "rel=!full:%root%\=!"
    call :isIgnored "!rel!"
    if /I "!isIgnored!"=="false" set "hasBlockingContent=true"
)

for /f "delims=" %%D in ('dir /AD /B /S 2^>nul') do (
    set "full=%%~fD"
    set "rel=!full:%root%\=!"
    call :isIgnored "!rel!"
    if /I "!isIgnored!"=="false" set "hasBlockingContent=true"
)

if /I "%hasBlockingContent%"=="true" (
    echo [ERROR] Destination folder is not empty.
    set "errorId=9"
    goto :end
)

rem 3) Ask hidden password
if not "%~1"=="" (
    set "zipPass=%~1"
) else (
    for /f "usebackq delims=" %%P in (`powershell -NoProfile -Command "$p = Read-Host 'password' -AsSecureString; $b = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($p); try { [Runtime.InteropServices.Marshal]::PtrToStringAuto($b) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b) }"`) do set "zipPass=%%P"
    echo.
)
echo.

rem 4) Validate password
7z t "%zipName%" -p"%zipPass%" -bb0 -bd >nul 2>&1
set "testExitCode=%errorlevel%"

if not "%testExitCode%"=="0" (
    echo [ERROR] Incorrect password.
    set "errorId=3"
    goto :end
)

rem 5) Extract preserving folders, silently
7z x "%zipName%" -o"%root%" -p"%zipPass%" -y -bb0
set "extractExitCode=%errorlevel%"

if not "%extractExitCode%"=="0" (
    echo [ERROR] ZIP content could not be extracted.
    set "errorId=10"
    goto :end
)

echo ===== ZIP WAS EXTRACTED =====

:end
echo.
@REM pause
exit /b %errorId%

:isIgnored
set "candidate=%~1"
set "isIgnored=false"

if not defined candidate exit /b 0

for /L %%I in (0,1,%ignoreMax%) do (
    set "item=!ignore[%%I]!"
    if defined item (
        if /I "!candidate!"=="!item!" set "isIgnored=true"
        if /I "!isIgnored!"=="false" (
            echo(!candidate!| findstr /I /B /L /C:"!item!\" >nul && set "isIgnored=true"
        )
    )
)

exit /b 0