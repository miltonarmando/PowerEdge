#!/bin/bash

# Verificação rápida do PowerEdge
echo "🔋 PowerEdge - Verificação Rápida"
echo "================================="

# Verificar arquivos principais
echo "📁 Verificando arquivos principais..."
required_files=(
    "app/run.py"
    "app/config.py"
    "static/index.html"
    "requirements.txt"
    "install.sh"
    "diagnose_i2c.sh"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file FALTANDO"
    fi
done

# Verificar Python
echo ""
echo "🐍 Verificando Python..."
if command -v python3 &> /dev/null; then
    echo "✅ Python 3: $(python3 --version)"
else
    echo "❌ Python 3 não encontrado"
fi

# Verificar pip
if command -v pip3 &> /dev/null; then
    echo "✅ pip3 disponível"
else
    echo "❌ pip3 não encontrado"
fi

# Verificar sistema
echo ""
echo "🖥️  Informações do sistema:"
echo "   Arquitetura: $(uname -m)"
echo "   Sistema: $(uname -s)"
echo "   Usuário: $(whoami)"

# Verificar se é Raspberry Pi
echo ""
echo "🔍 Detecção de hardware:"
if grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
    echo "✅ Raspberry Pi detectado - Modo PRODUÇÃO"
else
    echo "🎮 Sistema x86_64 - Modo SIMULAÇÃO"
fi

# Verificar grupos do usuário
echo ""
echo "👥 Grupos do usuário:"
groups | tr ' ' '\n' | sort | sed 's/^/   /'

# Verificar I2C
echo ""
echo "🔌 Status I2C:"
if ls /dev/i2c* 1> /dev/null 2>&1; then
    echo "✅ Dispositivos I2C encontrados:"
    ls -la /dev/i2c* | sed 's/^/   /'
else
    echo "❌ Nenhum dispositivo I2C encontrado"
fi

# Verificar se já existe ambiente virtual
echo ""
echo "📦 Ambiente virtual:"
if [ -d "venv" ]; then
    echo "✅ Ambiente virtual existe"
    if [ -f "venv/bin/activate" ]; then
        echo "✅ Script de ativação encontrado"
    else
        echo "❌ Script de ativação não encontrado"
    fi
else
    echo "❌ Ambiente virtual não encontrado"
fi

echo ""
echo "🚀 Próximos passos:"
echo "   1. Execute: ./install.sh"
echo "   2. Após instalação: ./run.sh"
echo "   3. Acesse: http://localhost:5000"
echo ""
echo "Para diagnóstico I2C detalhado:"
echo "   ./diagnose_i2c.sh"
