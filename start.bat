@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1

set "ROOT_DIR=%~dp0"
set "API_DIR=%ROOT_DIR%api"
set "VENV_DIR=%API_DIR%\venv"
set "MODEL_FILE=%API_DIR%\model\modelo_treinado.pkl"
set "REQUIREMENTS=%API_DIR%\requirements.txt"

echo.
echo ══════════════════════════════════════════
echo   StrokeGuard MVP — Inicializacao
echo ══════════════════════════════════════════
echo.

:: --- Python (minimo 3.10; winget instala 3.11 se necessario) ------------
set "PYTHON="

call :resolve_python
if not defined PYTHON (
    echo   [AVISO] Python 3.10+ nao encontrado. Tentando instalar Python 3.11 via winget...
    where winget >nul 2>&1
    if !errorlevel! equ 0 (
        winget install -e --id Python.Python.3.11 --accept-package-agreements --accept-source-agreements
        call :resolve_python
    )
)
if not defined PYTHON (
    echo   [ERRO] Python 3.10+ nao encontrado. Instale manualmente em https://www.python.org/downloads/
    echo   Ou instale o Python Launcher e execute de novo.
    pause
    exit /b 1
)

for /f "tokens=*" %%v in ('"%PYTHON%" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"') do set "PY_VERSION=%%v"
for /f "tokens=*" %%v in ('"%PYTHON%" -c "import sys; print(sys.version_info.major)"') do set "PY_MAJOR=%%v"
for /f "tokens=*" %%v in ('"%PYTHON%" -c "import sys; print(sys.version_info.minor)"') do set "PY_MINOR=%%v"

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
goto :after_python_resolve

:resolve_python
set "PYTHON="
call :try_set_python python
if defined PYTHON exit /b 0
call :try_set_python python3
if defined PYTHON exit /b 0
where py >nul 2>&1
if !errorlevel! equ 0 (
    for %%V in (3.13 3.12 3.11 3.10) do (
        if not defined PYTHON (
            py -%%V -c "import sys; sys.exit(0 if sys.version_info>=(3,10) else 1)" 2>nul
            if !errorlevel! equ 0 (
                for /f "tokens=*" %%E in ('py -%%V -c "import sys; print(sys.executable)" 2^>nul') do set "PYTHON=%%E"
            )
        )
    )
)
if defined PYTHON exit /b 0
for %%P in (
    "%LocalAppData%\Programs\Python\Python313\python.exe"
    "%LocalAppData%\Programs\Python\Python312\python.exe"
    "%LocalAppData%\Programs\Python\Python311\python.exe"
    "%LocalAppData%\Programs\Python\Python310\python.exe"
) do (
    if not defined PYTHON (
        if exist %%~P (
            %%~P -c "import sys; sys.exit(0 if sys.version_info>=(3,10) else 1)" 2>nul
            if !errorlevel! equ 0 set "PYTHON=%%~P"
        )
    )
)
exit /b 0

:try_set_python
set "CAND=%~1"
where %CAND% >nul 2>&1
if not !errorlevel! equ 0 exit /b 0
%CAND% -c "import sys; sys.exit(0 if sys.version_info>=(3,10) else 1)" 2>nul
if not !errorlevel! equ 0 exit /b 0
for /f "tokens=*" %%E in ('%CAND% -c "import sys; print(sys.executable)" 2^>nul') do set "PYTHON=%%E"
exit /b 0

:after_python_resolve

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

:: --- Model check ------------------------------------------------------
if not exist "%MODEL_FILE%" (
    echo.
    echo   [AVISO] Modelo nao encontrado em api\model\modelo_treinado.pkl
    echo   [AVISO] Execute o notebook no Google Colab e copie o .pkl para api\model\
    echo   [AVISO] O servidor iniciara, mas predicoes nao funcionarao sem o modelo.
    echo.
)

:: --- Dataset check ----------------------------------------------------
if not exist "%ROOT_DIR%data\healthcare-dataset-stroke-data.csv" (
    echo   [AVISO] Dataset nao encontrado em data\. Os testes PyTest podem falhar.
)

:: --- Start server -----------------------------------------------------
echo.
echo ══════════════════════════════════════════
echo   Iniciando servidor Flask
echo ══════════════════════════════════════════
echo.
echo   URL: http://localhost:5000 (ou outra se 5000 estiver ocupada — veja * Running on abaixo)
echo   Para encerrar: Ctrl+C
echo.

cd /d "%API_DIR%"
"%VENV_DIR%\Scripts\python.exe" app.py

endlocal
pause
