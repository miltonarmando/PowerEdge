#!/bin/bash

# PowerEdge v2.0 - Script de Execução
# Execute este script para iniciar o sistema

echo "🔋 PowerEdge v2.0 - Sistema de Monitoramento de Energia"
echo "======================================================"

# Verificar se está no diretório correto
if [ ! -f "app/run.py" ]; then
    echo "❌ Execute este script a partir do diretório raiz do PowerEdge"
    exit 1
fi

# Função para detectar sistema operacional
detect_os() {
    if grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
        echo "raspberry"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

OS=$(detect_os)
echo "🖥️  Sistema detectado: $OS"

# Ativar ambiente virtual se existir
if [ -d "venv" ]; then
    echo "🐍 Ativando ambiente virtual..."
    if [ "$OS" = "windows" ]; then
        source venv/Scripts/activate
    else
        source venv/bin/activate
    fi
else
    echo "⚠️  Ambiente virtual não encontrado. Usando Python global."
fi

# Verificar dependências
echo "📦 Verificando dependências..."
python -c "import flask, websockets" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "❌ Dependências não instaladas. Execute:"
    echo "   pip install -r requirements.txt"
    exit 1
fi

# Criar diretórios necessários
mkdir -p logs
mkdir -p backups

# Verificar I2C no Raspberry Pi
if [ "$OS" = "raspberry" ]; then
    echo "🔍 Verificando I2C..."
    if ls /dev/i2c* 1> /dev/null 2>&1; then
        echo "✅ I2C disponível"
        if command -v i2cdetect >/dev/null 2>&1; then
            echo "📡 Scanneando dispositivos I2C..."
            i2cdetect -y 1 | grep -q "48\|49\|4a\|4b" && echo "✅ ADS1115 detectado" || echo "⚠️  ADS1115 não detectado"
        fi
    else
        echo "⚠️  I2C não está habilitado. Execute:"
        echo "   sudo raspi-config"
        echo "   Interface Options > I2C > Enable"
    fi
fi

echo ""
echo "🚀 Iniciando PowerEdge..."
echo "📊 Interface web: http://$(hostname -I | awk '{print $1}' 2>/dev/null || echo 'localhost'):5000"
echo "🔌 WebSocket: ws://$(hostname -I | awk '{print $1}' 2>/dev/null || echo 'localhost'):8765"
echo ""
echo "Pressione Ctrl+C para parar"
echo ""

# Iniciar aplicação
cd app
python run.py
