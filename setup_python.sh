#!/bin/bash

# Script para configurar ambiente Python no Raspberry Pi
# Execute este script ANTES da instalação principal

echo "🐍 Configuração do Ambiente Python para PowerEdge"
echo "================================================="

# Verificar versão do Python
python_version=$(python3 --version 2>&1)
echo "Versão do Python: $python_version"

if [[ ! "$python_version" =~ "Python 3" ]]; then
    echo "❌ Python 3 é necessário!"
    exit 1
fi

# Instalar pip se não estiver instalado
if ! command -v pip3 &> /dev/null; then
    echo "📦 Instalando pip..."
    sudo apt update
    sudo apt install -y python3-pip
fi

# Instalar desenvolvimento e ferramentas de sistema
echo "🔧 Instalando ferramentas de desenvolvimento..."
sudo apt install -y \
    python3-dev \
    python3-venv \
    build-essential \
    git \
    i2c-tools \
    libi2c-dev

# Configurar permissões I2C para usuário pi
echo "🔐 Configurando permissões I2C..."
sudo usermod -a -G i2c pi

# Habilitar I2C no boot
echo "⚙️  Habilitando I2C no boot..."
sudo raspi-config nonint do_i2c 0

# Verificar se I2C está funcionando
echo "🔍 Verificando I2C..."
if ls /dev/i2c* 1> /dev/null 2>&1; then
    echo "✅ I2C habilitado com sucesso"
    echo "Dispositivos I2C disponíveis:"
    ls -la /dev/i2c*
else
    echo "⚠️  I2C pode não estar configurado corretamente"
    echo "Reinicie o sistema e execute novamente"
fi

# Verificar GPIO
echo "🔌 Verificando GPIO..."
if [ -d "/sys/class/gpio" ]; then
    echo "✅ GPIO disponível"
else
    echo "⚠️  GPIO pode não estar acessível"
fi

echo ""
echo "✅ Configuração básica concluída!"
echo ""
echo "⚠️  IMPORTANTE: Reinicie o sistema antes de prosseguir:"
echo "   sudo reboot"
echo ""
echo "Após a reinicialização, execute:"
echo "   ./install.sh"
