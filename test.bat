@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1

set "ROOT_DIR=%~dp0"
set "API_DIR=%ROOT_DIR%api"
set "VENV_DIR=%API_DIR%\venv"
set "REQUIREMENTS=%API_DIR%\requirements.txt"

echo.
echo ══════════════════════════════════════════
echo   StrokeGuard MVP — Testes
echo ══════════════════════════════════════════
echo.

:: --- Python -----------------------------------------------------------
set "PYTHON="
where python >nul 2>&1
if %errorlevel% equ 0 (
    set "PYTHON=python"
) else (
    where python3 >nul 2>&1
    if %errorlevel% equ 0 (
        set "PYTHON=python3"
    )
)

if "%PYTHON%"=="" (
    echo   [ERRO] Python nao encontrado. Instale Python 3.10+ e tente novamente.
    pause
    exit /b 1
)

for /f "tokens=*" %%v in ('%PYTHON% -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"') do set "PY_VERSION=%%v"
for /f "tokens=*" %%v in ('%PYTHON% -c "import sys; print(sys.version_info.major)"') do set "PY_MAJOR=%%v"
for /f "tokens=*" %%v in ('%PYTHON% -c "import sys; print(sys.version_info.minor)"') do set "PY_MINOR=%%v"

if !PY_MAJOR! lss 3 (
    echo   [ERRO] Python !PY_VERSION! detectado. E necessario Python 3.10 ou superior.
    pause
    exit /b 1
)
if !PY_MAJOR! equ 3 if !PY_MINOR! lss 10 (
    echo   [ERRO] Python !PY_VERSION! detectado. E necessario Python 3.10 ou superior.
    pause
    exit /b 1
)
echo   [OK] Python !PY_VERSION! encontrado

:: --- Virtual environment ----------------------------------------------
if not exist "%VENV_DIR%\Scripts\activate.bat" (
    echo.
    echo   Criando ambiente virtual em api\venv\...
    %PYTHON% -m venv "%VENV_DIR%"
    echo   [OK] Ambiente virtual criado
) else (
    echo   [OK] Ambiente virtual ja existe
)

call "%VENV_DIR%\Scripts\activate.bat"
echo   [OK] Ambiente virtual ativado

:: --- Dependencies -----------------------------------------------------
echo.
echo   Instalando dependencias...
pip install --upgrade pip --quiet >nul 2>&1
pip install -r "%REQUIREMENTS%" --quiet
echo   [OK] Dependencias instaladas

:: --- Pre-flight checks ------------------------------------------------
if not exist "%API_DIR%\model\modelo_treinado.pkl" (
    echo.
    echo   [AVISO] Modelo nao encontrado em api\model\modelo_treinado.pkl
    echo   [AVISO] Alguns testes podem ser ignorados (skip).
)

if not exist "%ROOT_DIR%data\healthcare-dataset-stroke-data.csv" (
    echo   [AVISO] Dataset nao encontrado em data\. Alguns testes podem ser ignorados (skip).
)

:: --- Run tests --------------------------------------------------------
echo.
echo ══════════════════════════════════════════
echo   Executando PyTest
echo ══════════════════════════════════════════
echo.

cd /d "%API_DIR%"
"%VENV_DIR%\Scripts\pytest.exe" test_model.py -v
set "EXIT_CODE=%errorlevel%"

echo.
if !EXIT_CODE! equ 0 (
    echo   [OK] Todos os testes passaram!
) else (
    echo   [ERRO] Alguns testes falharam (exit code: !EXIT_CODE!)
)

endlocal
pause
exit /b %EXIT_CODE%
