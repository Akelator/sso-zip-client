@echo off
setlocal EnableExtensions EnableDelayedExpansion

cd /d "%~dp0"
set "zipName=ssa-zip.zip"
set "hasContent="
set "hadError=false"
set "errorId=0"
set "noZip=false"
set "root=%cd%"
set "tempList=%temp%\ssa_zip_pack_%random%%random%.txt"

rem =========================
rem IGNORE LIST
rem =========================
set "ignore[0]=%zipName%"
set "ignore[1]=ssa-zip.exe"
set "ignore[2]=ssa-zip-pack.bat"
set "ignore[3]=ssa-zip-unpack.bat"
set "ignoreMax=3"

if exist "%tempList%" del /F /Q "%tempList%"

rem 1) Construir lista de archivos a comprimir, aplicando ignores
for /R %%F in (*) do (
    set "full=%%~fF"
    set "rel=!full:%root%\=!"
    call :isIgnored "!rel!"
    echo [DEBUG] rel=!rel! ^| isIgnored=!isIgnored!
    if /I "!isIgnored!"=="false" (
        >>"%tempList%" echo !rel!
        set "hasContent=1"
    )
)

if not defined hasContent (
    echo [ERROR] There are no files to synchronize.
    set "errorId=2"
    set "hadError=true"
    goto :end
)

rem 2) Si no existe el zip, salir
if not exist "%zipName%" (
    set "noZip=true"
)

rem 3) Pedir password oculta
if not "%~1"=="" (
    set "zipPass=%~1"
) else (
    for /f "usebackq delims=" %%P in (`powershell -NoProfile -Command "$p = Read-Host 'password' -AsSecureString; $b = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($p); try { [Runtime.InteropServices.Marshal]::PtrToStringAuto($b) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b) }"`) do set "zipPass=%%P"
    echo.
)
echo.

if /I "%noZip%"=="true" call :createZip

rem 4) Validar la contraseña antes de escribir nada
7z t "%zipName%" -p"%zipPass%" -bb0 -bd >nul 2>&1
set "testExitCode=%errorlevel%"

if not "%testExitCode%"=="0" (
    echo [ERROR] Incorrect password.
    set "errorId=3"
    set "hadError=true"
    goto :end
)

rem 5) Borrar contenido interno del zip
7z d "%zipName%" * -r -p"%zipPass%" -y -bb0 -bd >nul 2>&1
set "deleteExitCode=%errorlevel%"

if not "%deleteExitCode%"=="0" (
    echo [ERROR] Old ZIP content could not be deleted.
    set "errorId=4"
    set "hadError=true"
    goto :end
)

rem 6) Añadir solo los archivos no ignorados
7z a "%zipName%" @"%tempList%" -scsDOS -p"%zipPass%" -mem=AES256 -y -bb0
set "addExitCode=%errorlevel%"

if not "%addExitCode%"=="0" (
    echo [ERROR] New content could not be added to ZIP.
    set "errorId=5"
    set "hadError=true"
    goto :end
)

rem 7) Borrar archivos no ignorados
for /R %%F in (*) do (
    set "full=%%~fF"
    set "rel=!full:%root%\=!"
    call :isIgnored "!rel!"
    if /I "!isIgnored!"=="false" del /F /Q "%%~fF"
)

rem 8) Borrar carpetas no ignoradas, de abajo hacia arriba
for /f "delims=" %%D in ('dir /AD /B /S ^| sort /R') do (
    set "full=%%~fD"
    set "rel=!full:%root%\=!"
    call :isIgnored "!rel!"
    if /I "!isIgnored!"=="false" rd /S /Q "%%~fD" 2>nul
)

:end
if exist "%tempList%" del /F /Q "%tempList%" >nul 2>&1
echo.
if /I "%hadError%"=="false" echo ===== ZIP WAS UPDATED =====
@REM pause
exit /b %errorId%

:isIgnored
set "candidate=%~1"
set "isIgnored=false"

if not defined candidate exit /b 0

for /L %%I in (0,1,%ignoreMax%) do (
    set "item=!ignore[%%I]!"
    if defined item (
        rem Coincidencia exacta
        if /I "!candidate!"=="!item!" set "isIgnored=true"

        rem Está dentro de una carpeta ignorada
        if /I "!isIgnored!"=="false" (
            echo(!candidate!| findstr /I /B /L /C:"!item!\" >nul && set "isIgnored=true")
        )
    )
)

exit /b 0

:createZip
set "seedFile=__ssa_zip_init__.tmp"

rem Crear archivo temporal vacio
break > "%seedFile%"

rem Crear el ZIP protegido con una entrada semilla
7z a "%zipName%" "%seedFile%" -tzip -p"%zipPass%" -mem=AES256 -y -bb0 -bd >nul 2>&1
set "createExitCode=%errorlevel%"

if exist "%seedFile%" del /F /Q "%seedFile%"

if not "%createExitCode%"=="0" (
    echo [ERROR] ZIP file could not be created.
    set "errorId=6"
    set "hadError=true"
    goto :end
)

rem Vaciar el ZIP borrando la entrada semilla
7z d "%zipName%" "%seedFile%" -p"%zipPass%" -y -bb0 -bd >nul 2>&1
set "emptyExitCode=%errorlevel%"

if not "%emptyExitCode%"=="0" (
    echo [ERROR] Empty protected ZIP could not be initialized.
    set "errorId=7"
    set "hadError=true"
    goto :end
)

exit /b