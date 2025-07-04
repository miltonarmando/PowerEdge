#!/bin/bash

# Script de diagnóstico I2C para PowerEdge
# Execute se tiver problemas com I2C

echo "🔍 Diagnóstico I2C - PowerEdge"
echo "=============================="

# Verificar sistema
echo "📋 Informações do sistema:"
echo "  OS: $(uname -a)"
echo "  User: $(whoami)"
echo "  Groups: $(groups)"

echo ""
echo "🔍 Verificando dispositivos I2C:"
if ls /dev/i2c* 1> /dev/null 2>&1; then
    echo "✅ Dispositivos I2C encontrados:"
    ls -la /dev/i2c*
else
    echo "❌ Nenhum dispositivo I2C encontrado"
fi

echo ""
echo "🔍 Verificando módulos I2C:"
if lsmod | grep -q i2c; then
    echo "✅ Módulos I2C carregados:"
    lsmod | grep i2c
else
    echo "❌ Módulos I2C não carregados"
    echo "🔧 Tentando carregar módulos..."
    sudo modprobe i2c-dev
    sudo modprobe i2c-bcm2835
    if lsmod | grep -q i2c; then
        echo "✅ Módulos carregados com sucesso"
    else
        echo "❌ Falha ao carregar módulos"
    fi
fi

echo ""
echo "🔍 Verificando configuração do boot:"
for config_file in "/boot/firmware/config.txt" "/boot/config.txt"; do
    if [ -f "$config_file" ]; then
        echo "📁 $config_file:"
        if grep -q "dtparam=i2c_arm=on" "$config_file"; then
            echo "  ✅ dtparam=i2c_arm=on encontrado"
        else
            echo "  ❌ dtparam=i2c_arm=on NÃO encontrado"
        fi
        if grep -q "dtparam=i2c1=on" "$config_file"; then
            echo "  ✅ dtparam=i2c1=on encontrado"
        else
            echo "  ❌ dtparam=i2c1=on NÃO encontrado"
        fi
    fi
done

echo ""
echo "🔍 Testando scanner I2C:"
if command -v i2cdetect &> /dev/null; then
    echo "Executando: i2cdetect -y 1"
    if i2cdetect -y 1 2>/dev/null; then
        echo ""
        echo "✅ Scanner executado! Procure por:"
        echo "  - Endereços 48-4B: ADS1115"
        echo "  - Se vazio: verifique conexões hardware"
    else
        echo "❌ Scanner falhou - problema de permissões"
    fi
else
    echo "❌ i2cdetect não disponível"
    echo "🔧 Instale com: sudo apt install i2c-tools"
fi

echo ""
echo "🔍 Verificando permissões:"
if groups | grep -q i2c; then
    echo "✅ Usuário está no grupo i2c"
else
    echo "❌ Usuário NÃO está no grupo i2c"
    echo "🔧 Execute: sudo usermod -a -G i2c $USER"
    echo "   Depois reinicie o sistema"
fi

echo ""
echo "🔍 Verificando GPIO:"
if [ -d "/sys/class/gpio" ]; then
    echo "✅ GPIO disponível"
else
    echo "❌ GPIO não disponível"
fi

echo ""
echo "📋 Resumo e soluções:"
echo "===================="

# Verificar se I2C está funcionando
if ls /dev/i2c* 1> /dev/null 2>&1 && lsmod | grep -q i2c; then
    echo "✅ I2C está funcionando!"
    echo "🔌 Próximo passo: verificar conexões do ADS1115"
    echo "   VDD → 3.3V (Pin 1)"
    echo "   GND → GND (Pin 6)"
    echo "   SCL → GPIO 3 (Pin 5)"
    echo "   SDA → GPIO 2 (Pin 3)"
    echo "   ADDR → GND (endereço 0x48)"
else
    echo "❌ I2C não está funcionando completamente"
    echo ""
    echo "🔧 Soluções em ordem:"
    echo "1. sudo raspi-config → Interface Options → I2C → Yes"
    echo "2. sudo reboot"
    echo "3. Execute este script novamente"
    echo "4. Se persistir, execute: ./setup_python.sh"
fi

echo ""
echo "🆘 Se ainda tiver problemas:"
echo "   - Verifique se está usando Raspberry Pi OS oficial"
echo "   - Teste com outro ADS1115"
echo "   - Verifique soldas/conexões"
echo "   - Consulte a documentação em docs/FAQ.md"
