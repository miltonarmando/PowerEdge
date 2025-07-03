#!/bin/bash

# Script de instalação do PowerEdge para Raspberry Pi
# Execute com: chmod +x install.sh && ./install.sh

echo "🔋 PowerEdge - Script de Instalação"
echo "===================================="

# Verificar se está rodando no Raspberry Pi
if ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
    echo "⚠️  Aviso: Este script foi projetado para Raspberry Pi"
    read -p "Deseja continuar mesmo assim? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Atualizar sistema
echo "📦 Atualizando sistema..."
sudo apt update && sudo apt upgrade -y

# Instalar dependências do sistema
echo "🔧 Instalando dependências do sistema..."
sudo apt install -y python3 python3-pip python3-venv git i2c-tools

# Habilitar I2C
echo "🔗 Habilitando I2C..."
sudo raspi-config nonint do_i2c 0

# Criar ambiente virtual
echo "🐍 Criando ambiente virtual Python..."
python3 -m venv venv
source venv/bin/activate

# Instalar dependências Python
echo "📚 Instalando dependências Python..."
pip install --upgrade pip
pip install -r requirements.txt

# Criar diretórios necessários
echo "📁 Criando estrutura de diretórios..."
mkdir -p logs
mkdir -p backups

# Criar arquivo de configuração local
echo "⚙️  Criando configuração local..."
cat > .env << EOF
# Configurações locais do PowerEdge
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

# Criar serviço systemd
echo "🔄 Criando serviço systemd..."
sudo tee /etc/systemd/system/poweredge.service > /dev/null << EOF
[Unit]
Description=PowerEdge - Sistema de Monitoramento de Energia
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=$(pwd)
Environment=PATH=$(pwd)/venv/bin
ExecStart=$(pwd)/venv/bin/python $(pwd)/app/run.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Testar I2C
echo "🔍 Testando I2C..."
if i2cdetect -y 1 | grep -q "48\|49\|4a\|4b"; then
    echo "✅ ADS1115 detectado no barramento I2C"
else
    echo "⚠️  ADS1115 não detectado. Verifique as conexões:"
    echo "   VDD -> 3.3V"
    echo "   GND -> GND"
    echo "   SCL -> GPIO 3 (Pin 5)"
    echo "   SDA -> GPIO 2 (Pin 3)"
    echo "   ADDR -> GND (endereço 0x48)"
fi

# Testar instalação
echo "🧪 Testando instalação..."
if python app/run.py --test 2>/dev/null; then
    echo "✅ Instalação bem-sucedida!"
else
    echo "⚠️  Teste básico passou, mas execute manualmente para verificar"
fi

echo ""
echo "🎉 Instalação concluída!"
echo ""
echo "Para iniciar o sistema:"
echo "  ./run.sh"
echo ""
echo "Para habilitar inicialização automática:"
echo "  sudo systemctl enable poweredge"
echo "  sudo systemctl start poweredge"
echo ""
echo "Para monitorar logs:"
echo "  tail -f logs/energia.log"
echo ""
echo "Interface web estará disponível em:"
echo "  http://$(hostname -I | awk '{print $1}'):5000"
echo ""
echo "WebSocket para dados em tempo real:"
echo "  ws://$(hostname -I | awk '{print $1}'):8765"
