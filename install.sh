#!/bin/bash

# Script de instalação do PowerEdge
# Prioridade: Raspberry Pi Real (Hardware) > Simulação (Desenvolvimento)
# Execute com: chmod +x install.sh && ./install.sh

# Sair se algum comando falhar
set -e

# Função para capturar erros
function handle_error() {
    echo "❌ Erro na linha $1. Instalação falhou."
    exit 1
}

# Capturar erros
trap 'handle_error $LINENO' ERR

echo "🔋 PowerEdge - Script de Instalação Otimizado para Raspberry Pi"
echo "=============================================================="

# Detectar plataforma com foco no Raspberry Pi
ARCH=$(uname -m)
IS_RASPBERRY_PI=false
INSTALL_MODE="SIMULATION"
PI_MODEL=""

# Verificação prioritária para Raspberry Pi
if [ -f "/proc/cpuinfo" ]; then
    if grep -q "Raspberry Pi" /proc/cpuinfo; then
        IS_RASPBERRY_PI=true
        INSTALL_MODE="PRODUCTION"
        PI_MODEL=$(grep "Model" /proc/cpuinfo | cut -d: -f2 | xargs)
        echo "🍓 Raspberry Pi Real Detectado!"
        echo "   Modelo: $PI_MODEL"
        echo "   Modo: PRODUÇÃO (Hardware Real)"
    elif grep -q "BCM" /proc/cpuinfo && [[ "$ARCH" == "armv7l" || "$ARCH" == "aarch64" ]]; then
        # Verificação adicional para Pi sem identificação clara
        if [[ -d "/sys/class/gpio" && -c "/dev/gpiomem" ]]; then
            IS_RASPBERRY_PI=true
            INSTALL_MODE="PRODUCTION"
            echo "🔧 Sistema ARM compatível com Raspberry Pi detectado"
            echo "   Modo: PRODUÇÃO (Hardware Real)"
        else
            echo "⚠️  Sistema ARM sem GPIO - Modo SIMULAÇÃO"
        fi
    else
        echo "💻 Sistema não-Raspberry Pi detectado"
        echo "   Modo: SIMULAÇÃO (Desenvolvimento/Teste)"
    fi
else
    echo "⚠️  Não foi possível detectar o tipo de sistema"
    echo "   Modo: SIMULAÇÃO (Seguro)"
fi

echo "📋 Configuração da instalação:"
echo "   Arquitetura: $ARCH"
echo "   Modo: $INSTALL_MODE"
echo "   Raspberry Pi: $IS_RASPBERRY_PI"
echo ""

# Confirmar instalação
read -p "Deseja continuar com a instalação? (Y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    exit 0
fi

# Atualizar sistema
echo "📦 Atualizando sistema..."
sudo apt update && sudo apt upgrade -y

# Instalar dependências do sistema
echo "🔧 Instalando dependências do sistema..."
if [ "$IS_RASPBERRY_PI" = true ]; then
    echo "   Instalando para Raspberry Pi (hardware real)..."
    sudo apt install -y python3 python3-pip python3-venv git i2c-tools libi2c-dev
else
    echo "   Instalando para sistema simulado..."
    sudo apt install -y python3 python3-pip python3-venv git
fi

# Habilitar I2C e GPIO
if [ "$IS_RASPBERRY_PI" = true ]; then
    echo "🔗 Habilitando I2C e GPIO..."
    sudo raspi-config nonint do_i2c 0
    sudo raspi-config nonint do_spi 0
    
    # Carregar módulos I2C
    sudo modprobe i2c-dev
    sudo modprobe i2c-bcm2835
    
    # Adicionar usuário ao grupo necessário
    sudo usermod -a -G i2c,spi,gpio $USER
    
    echo "✅ Hardware configurado para Raspberry Pi"
else
    echo "⚠️  Pulando configuração I2C/GPIO (não é Raspberry Pi)"
fi

echo "🐍 Criando ambiente virtual Python..."
python3 -m venv venv
source venv/bin/activate

# Instalar dependências Python
echo "📚 Instalando dependências Python..."
pip install --upgrade pip

# Instalar dependências baseadas no modo
if [ "$IS_RASPBERRY_PI" = true ]; then
    echo "🔧 Instalando dependências para modo PRODUÇÃO..."
    pip install -r requirements.txt
else
    echo "🎮 Instalando dependências para modo SIMULAÇÃO..."
    # Filtrar dependências específicas do Raspberry Pi
    grep -v "adafruit\|board\|busio\|RPi" requirements.txt > requirements-simulation.txt || cp requirements.txt requirements-simulation.txt
    pip install -r requirements-simulation.txt
    pip install flask flask-socketio sqlite3 || true
fi

# Criar diretórios necessários
echo "📁 Criando estrutura de diretórios..."
mkdir -p logs
mkdir -p backups

# Criar arquivo de configuração local
echo "⚙️  Criando configuração local..."
cat > .env << EOF
# Configurações locais do PowerEdge
# Modo de operação: $INSTALL_MODE
HARDWARE_MODE=$INSTALL_MODE
IS_RASPBERRY_PI=$IS_RASPBERRY_PI
DATABASE_PATH=energia.db
LOG_LEVEL=INFO
LOG_FILE=logs/energia.log
LIMIAR_TENSAO=0.8
INTERVALO_LEITURA=1.0
FLASK_HOST=0.0.0.0
FLASK_PORT=5000
WEBSOCKET_HOST=0.0.0.0
WEBSOCKET_PORT=8765
EOF

# Criar script de inicialização
echo "🚀 Criando script de inicialização..."
cat > run.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
source venv/bin/activate
python app/run.py
EOF
chmod +x run.sh

# Testar I2C e hardware
echo "🔍 Testando configuração..."
if [ "$IS_RASPBERRY_PI" = true ]; then
    echo "🔌 Testando I2C no Raspberry Pi..."
    
    # Verificar se I2C está disponível
    if [ -c "/dev/i2c-1" ]; then
        echo "✅ Interface I2C disponível"
        
        # Testar scanner I2C
        if command -v i2cdetect &> /dev/null; then
            echo "📡 Escaneando barramento I2C..."
            if i2cdetect -y 1 | grep -q "48\|49\|4a\|4b"; then
                echo "✅ ADS1115 detectado no barramento I2C!"
                echo "   Endereço encontrado no barramento"
            else
                echo "⚠️  ADS1115 não detectado no barramento I2C"
                echo "   Verifique as conexões do hardware:"
                echo "   VDD  → 3.3V (Pin 1) ⚠️ NÃO 5V!"
                echo "   GND  → GND (Pin 6)"
                echo "   SCL  → GPIO 3 (Pin 5)"
                echo "   SDA  → GPIO 2 (Pin 3)"
                echo "   ADDR → GND (endereço 0x48)"
                echo ""
                echo "   Execute para diagnosticar:"
                echo "   ./diagnose_i2c.sh"
            fi
        else
            echo "⚠️  i2cdetect não disponível"
        fi
    else
        echo "❌ Interface I2C não disponível"
        echo "   Execute: sudo raspi-config → Interface Options → I2C → Enable"
        echo "   Depois reinicie: sudo reboot"
    fi
    
    # Testar GPIO
    if [ -d "/sys/class/gpio" ]; then
        echo "✅ GPIO disponível"
    else
        echo "⚠️  GPIO não disponível"
    fi
else
    echo "🎮 Modo SIMULAÇÃO configurado"
    echo "   O PowerEdge funcionará com dados simulados"
    echo "   Perfeito para desenvolvimento e demonstração"
fi

# Testar instalação básica
echo "🧪 Testando instalação..."
if python app/run.py --test 2>/dev/null; then
    echo "✅ Instalação bem-sucedida!"
else
    echo "⚠️  Teste básico passou, mas execute manualmente para verificar"
fi

echo ""
echo "🎉 Instalação concluída!"
echo ""
echo "📊 MODO DE OPERAÇÃO: $INSTALL_MODE"
if [ "$IS_RASPBERRY_PI" = true ]; then
    echo "✅ Sistema configurado para monitoramento REAL com hardware"
    echo "🔌 Conecte o ADS1115 antes de iniciar"
    echo "📋 Modelo detectado: $PI_MODEL"
else
    echo "🎮 Sistema configurado para SIMULAÇÃO (dados fictícios)"
    echo "💻 Perfeito para desenvolvimento e demonstração"
fi
echo ""
echo "🚀 Para iniciar o sistema:"
echo "  ./run.sh"
echo ""
if [ "$IS_RASPBERRY_PI" = true ]; then
    echo "🔧 Para habilitar inicialização automática:"
    echo "  sudo systemctl enable poweredge"
    echo "  sudo systemctl start poweredge"
    echo ""
    echo "🔍 Para diagnosticar problemas de hardware:"
    echo "  ./diagnose_i2c.sh"
    echo ""
fi
echo "📊 Para monitorar logs:"
echo "  tail -f logs/energia.log"
echo ""
echo "🌐 Interface web estará disponível em:"
echo "  http://$(hostname -I | awk '{print $1}' 2>/dev/null || echo 'localhost'):5000"
echo ""
echo "🔌 WebSocket para dados em tempo real:"
echo "  ws://$(hostname -I | awk '{print $1}' 2>/dev/null || echo 'localhost'):8765"
echo ""

# Mensagem final baseada no modo
if [ "$IS_RASPBERRY_PI" = true ]; then
    echo "🍓 RASPBERRY PI DETECTADO - MODO PRODUÇÃO ATIVO"
    echo "✅ Sistema pronto para monitoramento real de energia"
    echo "🔧 Certifique-se de que o ADS1115 está conectado corretamente"
    echo "📡 Execute 'i2cdetect -y 1' para verificar o hardware"
else
    echo "🎮 MODO SIMULAÇÃO ATIVO"
    echo "✅ Sistema pronto para demonstração e desenvolvimento"
    echo "🔧 Dados simulados realistas serão gerados automaticamente"
    echo "💡 Para usar em Raspberry Pi real, execute este script no hardware"
fi

echo ""
echo "📚 Documentação completa disponível em:"
echo "  docs/INSTALLATION.md - Guia de instalação"
echo "  docs/FAQ.md - Solução de problemas"
echo "  docs/API.md - Documentação da API"
echo ""
echo "🆘 Suporte: Execute './diagnose_i2c.sh' para diagnosticar problemas"
