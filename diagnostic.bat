@echo off
REM PowerEdge Diagnostic Script v2.0 - Windows Version
REM Diagnóstico completo do sistema PowerEdge para Windows

setlocal enabledelayedexpansion

echo.
echo 🔍 PowerEdge Complete Diagnostic v2.0 (Windows)
echo ===============================================
echo.

REM Informações básicas do sistema
echo 📋 System Information
echo Date: %date% %time%
echo User: %username%
echo System: %os%
python --version 2>nul || echo Python: Not found
echo.

REM Verificar arquivos essenciais
echo 📁 File Structure Check
set "files=app\run.py app\config.py static\index.html static\style.css static\script.js requirements.txt"

for %%f in (%files%) do (
    if exist "%%f" (
        echo   ✅ %%f
    ) else (
        echo   ❌ %%f MISSING
    )
)

echo.

REM Verificar diretórios
echo 📂 Directory Structure
for %%d in (app static) do (
    if exist "%%d" (
        echo   ✅ %%d\
        dir "%%d" /B | findstr /v "^$" | echo     %%d contents listed
    ) else (
        echo   ❌ %%d\ MISSING
    )
)

echo.

REM Verificar dependências Python
echo 🐍 Python Dependencies
python --version >nul 2>&1
if !errorlevel! equ 0 (
    echo   ✅ Python installed
    for %%p in (flask flask-socketio) do (
        python -c "import %%p" >nul 2>&1
        if !errorlevel! equ 0 (
            echo   ✅ %%p
        ) else (
            echo   ❌ %%p NOT INSTALLED
        )
    )
    
    echo   ℹ️  Hardware dependencies ^(Raspberry Pi only^):
    for %%h in (board busio adafruit_ads1x15) do (
        python -c "import %%h" >nul 2>&1
        if !errorlevel! equ 0 (
            echo     ✅ %%h
        ) else (
            echo     ⚠️  %%h not available ^(simulation mode^)
        )
    )
) else (
    echo   ❌ Python NOT INSTALLED
)

echo.

REM Verificar rede e portas
echo 🌐 Network Check
echo   ℹ️  Local IP addresses:
ipconfig | findstr /R /C:"IPv4.*Address"

echo   ℹ️  Port status check:
for %%p in (5000 8765) do (
    netstat -an | findstr ":%%p " >nul
    if !errorlevel! equ 0 (
        echo     ❌ Port %%p ALREADY IN USE
    ) else (
        echo     ✅ Port %%p available
    )
)

echo.

REM Verificar processo PowerEdge
echo 🚀 PowerEdge Process Check
tasklist | findstr /I python | findstr /I run.py >nul
if !errorlevel! equ 0 (
    echo   ✅ PowerEdge is running
    echo   ℹ️  Process details:
    tasklist | findstr /I python
    
    REM Testar conectividade (se curl disponível)
    curl --version >nul 2>&1
    if !errorlevel! equ 0 (
        curl -s http://localhost:5000/api/health >nul 2>&1
        if !errorlevel! equ 0 (
            echo     ✅ HTTP API responding
        ) else (
            echo     ❌ HTTP API not responding
        )
    ) else (
        echo     ℹ️  curl not available for connectivity test
    )
) else (
    echo   ⚠️  PowerEdge not running
)

echo.

REM Verificar logs
echo 📝 Log Files Check
set "log_found=0"
for %%l in (poweredge.log app.log error.log) do (
    if exist "%%l" (
        set "log_found=1"
        echo   ✅ %%l found
        for %%s in ("%%l") do echo     Size: %%~zs bytes
        echo     Last 3 lines:
        powershell "Get-Content '%%l' -Tail 3 | ForEach-Object { '      ' + $_ }"
    )
)

if !log_found! equ 0 (
    echo   ℹ️  No log files found
)

echo.

REM Verificar banco de dados
echo 💾 Database Check
if exist "energy_monitoring.db" (
    echo   ✅ Database file exists
    for %%s in ("energy_monitoring.db") do echo     Size: %%~zs bytes
    
    sqlite3 --version >nul 2>&1
    if !errorlevel! equ 0 (
        echo   ℹ️  Database info available ^(sqlite3 found^)
    ) else (
        echo   ℹ️  sqlite3 not available for database analysis
    )
) else (
    echo   ⚠️  Database file not found ^(will be created on first run^)
)

echo.

REM Verificar recursos do sistema
echo 📊 System Resources
echo   ℹ️  Memory usage:
wmic computersystem get TotalPhysicalMemory /value | findstr "="
wmic OS get FreePhysicalMemory /value | findstr "="

echo   ℹ️  Disk usage:
for %%d in (C:) do (
    for /f "tokens=3" %%a in ('dir %%d ^| findstr /C:"bytes free"') do echo     %%d %%a bytes free
)

echo.

REM Teste rápido de funcionalidade
echo 🧪 Quick Functionality Test
echo   ℹ️  Testing main module import:
python -c "import sys; sys.path.insert(0, 'app'); import run; print('    ✅ Main module imports successfully')" 2>nul || echo     ❌ Import error

echo   ℹ️  Testing configuration:
python -c "import sys; sys.path.insert(0, 'app'); import config; print('    ✅ Configuration loads successfully'); print('    ℹ️  Simulation mode:', getattr(config, 'MODO_SIMULACAO', 'Unknown'))" 2>nul || echo     ❌ Configuration error

echo.

REM Sugestões
echo 💡 Recommendations
python --version >nul 2>&1 || echo   ❌ Install Python 3.8+ first

if not exist "app\run.py" (
    echo   ❌ Missing core files - reinstall PowerEdge
)

python -c "import flask" >nul 2>&1 || echo   ⚠️  Install dependencies: pip install -r requirements.txt

tasklist | findstr /I python | findstr /I run.py >nul
if !errorlevel! equ 0 (
    curl -s http://localhost:5000/api/health >nul 2>&1 || echo   ⚠️  PowerEdge running but not responding - check logs
) else (
    echo   ℹ️  To start PowerEdge: python app\run.py
)

echo   ℹ️  For detailed troubleshooting, see: FAQ.md
echo   ℹ️  For installation help, see: INSTALLATION.md

echo.
echo 🔍 Diagnostic complete!
echo ℹ️  For issues, include this output when asking for help.

REM Salvar relatório
set "report_file=diagnostic_report_%date:~-4%%date:~3,2%%date:~0,2%_%time:~0,2%%time:~3,2%%time:~6,2%.txt"
set "report_file=%report_file: =0%"
set "report_file=%report_file::=%"

echo.
echo ℹ️  Saving diagnostic report to: %report_file%

REM Criar relatório (versão simplificada)
(
    echo PowerEdge Diagnostic Report - Windows
    echo ===================================
    echo Date: %date% %time%
    echo System: %os%
    echo User: %username%
    echo.
    echo File Check:
    for %%f in (%files%) do (
        if exist "%%f" (
            echo   ✓ %%f
        ) else (
            echo   ✗ %%f MISSING
        )
    )
    echo.
    echo Python Dependencies:
    for %%p in (flask flask-socketio) do (
        python -c "import %%p" >nul 2>&1
        if !errorlevel! equ 0 (
            echo   ✓ %%p
        ) else (
            echo   ✗ %%p NOT INSTALLED
        )
    )
    echo.
    echo Process Status:
    tasklist | findstr /I python | findstr /I run.py >nul
    if !errorlevel! equ 0 (
        echo   ✓ PowerEdge running
        tasklist | findstr /I python
    ) else (
        echo   ✗ PowerEdge not running
    )
) > "%report_file%"

echo ✅ Report saved successfully!

pause
