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

# Garantir que módulos I2C estejam carregados
echo "📡 Carregando módulos I2C..."
sudo modprobe i2c-dev 2>/dev/null || true
sudo modprobe i2c-bcm2835 2>/dev/null || true

# Habilitar I2C no boot
echo "⚙️  Habilitando I2C no boot..."
if sudo raspi-config nonint do_i2c 0; then
    echo "✅ I2C habilitado via raspi-config"
else
    echo "⚠️  raspi-config falhou, tentando método alternativo..."
    # Método alternativo para sistemas mais novos
    for config_file in "/boot/firmware/config.txt" "/boot/config.txt"; do
        if [ -f "$config_file" ]; then
            echo "📝 Configurando I2C em $config_file"
            # Remover linhas existentes para evitar duplicação
            sudo sed -i '/^dtparam=i2c_arm=on/d' "$config_file"
            sudo sed -i '/^dtparam=i2c1=on/d' "$config_file"
            # Adicionar configuração I2C
            echo "dtparam=i2c_arm=on" | sudo tee -a "$config_file"
            echo "dtparam=i2c1=on" | sudo tee -a "$config_file"
            echo "✅ I2C configurado em $config_file"
            break
        fi
    done
fi

# Verificar se I2C está funcionando
echo "🔍 Verificando I2C..."

# Verificar dispositivos I2C
if ls /dev/i2c* 1> /dev/null 2>&1; then
    echo "✅ I2C habilitado com sucesso"
    echo "Dispositivos I2C disponíveis:"
    ls -la /dev/i2c*
    
    # Verificar módulos I2C carregados
    echo ""
    echo "🔍 Verificando módulos I2C carregados..."
    if lsmod | grep -q i2c; then
        echo "✅ Módulos I2C carregados:"
        lsmod | grep i2c
    else
        echo "⚠️  Módulos I2C não carregados"
    fi
    
    # Testar scanner I2C se disponível
    echo ""
    echo "🔍 Testando scanner I2C..."
    if command -v i2cdetect &> /dev/null; then
        echo "Executando: i2cdetect -y 1"
        if i2cdetect -y 1 2>/dev/null; then
            echo "✅ Scanner I2C executado com sucesso"
            echo "📊 Procure por dispositivos nos endereços 48-4B (ADS1115)"
        else
            echo "⚠️  Scanner I2C falhou - verifique permissões"
        fi
    else
        echo "⚠️  i2cdetect não disponível"
    fi
else
    echo "❌ I2C não está funcionando!"
    echo ""
    echo "🔧 Diagnóstico do problema:"
    
    # Verificar se raspi-config está disponível
    if command -v raspi-config &> /dev/null; then
        echo "✅ raspi-config disponível"
    else
        echo "❌ raspi-config não encontrado"
    fi
    
    # Verificar arquivos de configuração
    echo ""
    echo "📁 Verificando arquivos de configuração:"
    for config_file in "/boot/firmware/config.txt" "/boot/config.txt"; do
        if [ -f "$config_file" ]; then
            echo "✅ $config_file encontrado"
            if grep -q "dtparam=i2c_arm=on" "$config_file"; then
                echo "  ✅ I2C configurado em $config_file"
            else
                echo "  ❌ I2C NÃO configurado em $config_file"
            fi
        else
            echo "❌ $config_file não encontrado"
        fi
    done
    
    echo ""
    echo "🔄 SOLUÇÃO: Reinicie o sistema e execute novamente"
    echo "   sudo reboot"
    echo ""
    echo "Se o problema persistir, execute manualmente:"
    echo "   sudo raspi-config"
    echo "   → 3 Interface Options → I2C → Yes"
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
