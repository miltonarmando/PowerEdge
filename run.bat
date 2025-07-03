@echo off
REM PowerEdge v2.0 - Script de Execução para Windows
REM Execute este script para iniciar o sistema

echo 🔋 PowerEdge v2.0 - Sistema de Monitoramento de Energia
echo ======================================================

REM Verificar se está no diretório correto
if not exist "app\run.py" (
    echo ❌ Execute este script a partir do diretório raiz do PowerEdge
    pause
    exit /b 1
)

echo 🖥️  Sistema detectado: Windows

REM Ativar ambiente virtual se existir
if exist "venv\Scripts\activate.bat" (
    echo 🐍 Ativando ambiente virtual...
    call venv\Scripts\activate.bat
) else (
    echo ⚠️  Ambiente virtual não encontrado. Usando Python global.
)

REM Verificar dependências
echo 📦 Verificando dependências...
python -c "import flask, websockets" >nul 2>&1
if errorlevel 1 (
    echo ❌ Dependências não instaladas. Execute:
    echo    pip install -r requirements.txt
    pause
    exit /b 1
)

REM Criar diretórios necessários
if not exist "logs" mkdir logs
if not exist "backups" mkdir backups

echo.
echo 🚀 Iniciando PowerEdge...
echo 📊 Interface web: http://localhost:5000
echo 🔌 WebSocket: ws://localhost:8765
echo.
echo Pressione Ctrl+C para parar
echo.

REM Iniciar aplicação
cd app
python run.py
