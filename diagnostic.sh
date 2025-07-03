#!/bin/bash
# PowerEdge Diagnostic Script v2.0
# Diagnóstico completo do sistema PowerEdge

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Ícones
SUCCESS="✅"
ERROR="❌"
WARNING="⚠️"
INFO="ℹ️"
GEAR="⚙️"

echo -e "${PURPLE}🔍 PowerEdge Complete Diagnostic v2.0${NC}"
echo -e "${PURPLE}=======================================${NC}"
echo

# Informações básicas do sistema
echo -e "${BLUE}📋 System Information${NC}"
echo -e "Date: $(date)"
echo -e "User: $(whoami)"
echo -e "System: $(uname -a)"
echo -e "Python: $(python3 --version 2>/dev/null || echo 'Not found')"
echo

# Verificar arquivos essenciais
echo -e "${BLUE}📁 File Structure Check${NC}"
required_files=(
    "app/run.py"
    "app/config.py" 
    "static/index.html"
    "static/style.css"
    "static/script.js"
    "requirements.txt"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo -e "  ${SUCCESS} $file"
    else
        echo -e "  ${ERROR} $file ${RED}MISSING${NC}"
    fi
done

# Verificar diretórios
echo
echo -e "${BLUE}📂 Directory Structure${NC}"
for dir in "app" "static"; do
    if [ -d "$dir" ]; then
        echo -e "  ${SUCCESS} $dir/"
        ls -la "$dir" | grep -v "^total" | sed 's/^/    /'
    else
        echo -e "  ${ERROR} $dir/ ${RED}MISSING${NC}"
    fi
done

echo

# Verificar dependências Python
echo -e "${BLUE}🐍 Python Dependencies${NC}"
if command -v python3 > /dev/null; then
    echo -e "  ${SUCCESS} Python 3 installed: $(python3 --version)"
    
    # Verificar dependências principais
    deps=("flask" "flask-socketio")
    for dep in "${deps[@]}"; do
        if python3 -c "import $dep" 2>/dev/null; then
            version=$(python3 -c "import $dep; print(getattr($dep, '__version__', 'unknown'))" 2>/dev/null)
            echo -e "  ${SUCCESS} $dep ($version)"
        else
            echo -e "  ${ERROR} $dep ${RED}NOT INSTALLED${NC}"
        fi
    done
    
    # Verificar dependências de hardware (Raspberry Pi)
    hardware_deps=("board" "busio" "adafruit_ads1x15")
    echo -e "  ${INFO} Hardware dependencies (Raspberry Pi only):"
    for dep in "${hardware_deps[@]}"; do
        if python3 -c "import $dep" 2>/dev/null; then
            echo -e "    ${SUCCESS} $dep"
        else
            echo -e "    ${WARNING} $dep ${YELLOW}not available (simulation mode)${NC}"
        fi
    done
else
    echo -e "  ${ERROR} Python 3 ${RED}NOT INSTALLED${NC}"
fi

echo

# Verificar I2C (apenas em Linux)
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo -e "${BLUE}🔌 Hardware Check (Linux)${NC}"
    
    # Verificar I2C tools
    if command -v i2cdetect > /dev/null; then
        echo -e "  ${SUCCESS} i2c-tools installed"
        
        # Verificar dispositivos I2C
        echo -e "  ${INFO} I2C devices scan:"
        if sudo i2cdetect -y 1 2>/dev/null | grep -E '[0-9a-f]{2}' > /dev/null; then
            echo -e "    ${SUCCESS} I2C devices found:"
            sudo i2cdetect -y 1 2>/dev/null | grep -E '[0-9a-f]{2}' | sed 's/^/      /'
        else
            echo -e "    ${WARNING} No I2C devices detected"
        fi
    else
        echo -e "  ${WARNING} i2c-tools not installed"
        echo -e "    Install with: ${YELLOW}sudo apt install i2c-tools${NC}"
    fi
    
    # Testar ADS1115 especificamente
    echo -e "  ${INFO} ADS1115 specific test:"
    python3 -c "
try:
    import board, busio
    import adafruit_ads1x15.ads1115 as ADS
    from adafruit_ads1x15.analog_in import AnalogIn
    
    i2c = busio.I2C(board.SCL, board.SDA)
    ads = ADS.ADS1115(i2c)
    chan = AnalogIn(ads, ADS.P0)
    voltage = chan.voltage
    print(f'    ✅ ADS1115 OK - Test voltage: {voltage:.2f}V')
except ImportError:
    print('    ⚠️  ADS1115 libraries not installed (normal for non-Pi systems)')
except Exception as e:
    print(f'    ❌ ADS1115 error: {e}')
" 2>/dev/null
else
    echo -e "${BLUE}🔌 Hardware Check${NC}"
    echo -e "  ${INFO} Non-Linux system - Hardware checks skipped"
    echo -e "  ${INFO} System will run in simulation mode"
fi

echo

# Verificar rede e portas
echo -e "${BLUE}🌐 Network Check${NC}"

# IPs locais
echo -e "  ${INFO} Local IP addresses:"
if command -v hostname > /dev/null; then
    hostname -I 2>/dev/null | tr ' ' '\n' | grep -E '^[0-9]+\.' | sed 's/^/    /' || echo "    No IP found"
elif command -v ipconfig > /dev/null; then
    # Windows
    ipconfig | grep -E 'IPv4.*Address' | sed 's/^/    /'
else
    echo "    IP detection not available"
fi

# Verificar portas em uso
echo -e "  ${INFO} Port status check:"
ports=(5000 8765)
for port in "${ports[@]}"; do
    if command -v netstat > /dev/null; then
        if netstat -tuln 2>/dev/null | grep ":$port " > /dev/null; then
            echo -e "    ${ERROR} Port $port ${RED}ALREADY IN USE${NC}"
        else
            echo -e "    ${SUCCESS} Port $port available"
        fi
    elif command -v ss > /dev/null; then
        if ss -tuln 2>/dev/null | grep ":$port " > /dev/null; then
            echo -e "    ${ERROR} Port $port ${RED}ALREADY IN USE${NC}"
        else
            echo -e "    ${SUCCESS} Port $port available"
        fi
    else
        echo -e "    ${INFO} Port check tools not available"
        break
    fi
done

echo

# Verificar processo PowerEdge
echo -e "${BLUE}🚀 PowerEdge Process Check${NC}"
if pgrep -f "python.*run.py" > /dev/null; then
    echo -e "  ${SUCCESS} PowerEdge is running"
    echo -e "  ${INFO} Process details:"
    ps aux | grep -v grep | grep "python.*run.py" | sed 's/^/    /'
    
    # Testar conectividade
    echo -e "  ${INFO} Connectivity test:"
    if command -v curl > /dev/null; then
        if curl -s http://localhost:5000/api/health > /dev/null 2>&1; then
            echo -e "    ${SUCCESS} HTTP API responding"
        else
            echo -e "    ${ERROR} HTTP API not responding"
        fi
    else
        echo -e "    ${INFO} curl not available for connectivity test"
    fi
else
    echo -e "  ${WARNING} PowerEdge not running"
fi

echo

# Verificar logs
echo -e "${BLUE}📝 Log Files Check${NC}"
log_files=("poweredge.log" "app.log" "error.log")
found_logs=false

for log_file in "${log_files[@]}"; do
    if [ -f "$log_file" ]; then
        found_logs=true
        echo -e "  ${SUCCESS} $log_file found"
        echo -e "    Size: $(du -h $log_file | cut -f1)"
        echo -e "    Last modified: $(stat -c %y $log_file 2>/dev/null || stat -f %Sm $log_file 2>/dev/null)"
        echo -e "    Last 3 lines:"
        tail -3 "$log_file" | sed 's/^/      /'
    fi
done

if [ "$found_logs" = false ]; then
    echo -e "  ${INFO} No log files found"
fi

echo

# Verificar banco de dados
echo -e "${BLUE}💾 Database Check${NC}"
if [ -f "energy_monitoring.db" ]; then
    echo -e "  ${SUCCESS} Database file exists"
    echo -e "    Size: $(du -h energy_monitoring.db | cut -f1)"
    
    if command -v sqlite3 > /dev/null; then
        echo -e "  ${INFO} Database info:"
        echo -e "    Tables: $(sqlite3 energy_monitoring.db '.tables')"
        echo -e "    Record count: $(sqlite3 energy_monitoring.db 'SELECT COUNT(*) FROM eventos;' 2>/dev/null || echo 'Cannot read')"
    else
        echo -e "  ${INFO} sqlite3 not available for database analysis"
    fi
else
    echo -e "  ${WARNING} Database file not found (will be created on first run)"
fi

echo

# Verificar recursos do sistema
echo -e "${BLUE}📊 System Resources${NC}"

# Memória
if command -v free > /dev/null; then
    echo -e "  ${INFO} Memory usage:"
    free -h | sed 's/^/    /'
elif command -v vm_stat > /dev/null; then
    # macOS
    echo -e "  ${INFO} Memory usage (macOS):"
    vm_stat | head -4 | sed 's/^/    /'
else
    echo -e "  ${INFO} Memory info not available"
fi

# Disco
echo -e "  ${INFO} Disk usage:"
if command -v df > /dev/null; then
    df -h . | sed 's/^/    /'
else
    echo -e "    Disk info not available"
fi

# CPU Load (Linux)
if [ -f "/proc/loadavg" ]; then
    echo -e "  ${INFO} CPU load: $(cat /proc/loadavg | cut -d' ' -f1-3)"
fi

echo

# Teste rápido de funcionalidade
echo -e "${BLUE}🧪 Quick Functionality Test${NC}"

# Testar import do módulo principal
echo -e "  ${INFO} Testing main module import:"
python3 -c "
import sys
sys.path.insert(0, 'app')
try:
    import run
    print('    ✅ Main module imports successfully')
except Exception as e:
    print(f'    ❌ Import error: {e}')
" 2>/dev/null

# Testar configuração
echo -e "  ${INFO} Testing configuration:"
python3 -c "
import sys
sys.path.insert(0, 'app')
try:
    import config
    print('    ✅ Configuration loads successfully')
    print(f'    ℹ️  Simulation mode: {getattr(config, \"MODO_SIMULACAO\", \"Unknown\")}')
except Exception as e:
    print(f'    ❌ Configuration error: {e}')
" 2>/dev/null

echo

# Sugestões baseadas nos resultados
echo -e "${PURPLE}💡 Recommendations${NC}"

# Verificar se tem problemas críticos
if ! command -v python3 > /dev/null; then
    echo -e "  ${ERROR} Install Python 3.8+ first"
fi

if [ ! -f "app/run.py" ]; then
    echo -e "  ${ERROR} Missing core files - reinstall PowerEdge"
fi

if ! python3 -c "import flask" 2>/dev/null; then
    echo -e "  ${WARNING} Install dependencies: ${YELLOW}pip install -r requirements.txt${NC}"
fi

if pgrep -f "python.*run.py" > /dev/null; then
    if ! curl -s http://localhost:5000/api/health > /dev/null 2>&1; then
        echo -e "  ${WARNING} PowerEdge running but not responding - check logs"
    fi
else
    echo -e "  ${INFO} To start PowerEdge: ${GREEN}python app/run.py${NC}"
fi

echo -e "  ${INFO} For detailed troubleshooting, see: ${BLUE}FAQ.md${NC}"
echo -e "  ${INFO} For installation help, see: ${BLUE}INSTALLATION.md${NC}"

echo
echo -e "${GREEN}🔍 Diagnostic complete!${NC}"
echo -e "${INFO} For issues, include this output when asking for help."

# Salvar relatório
report_file="diagnostic_report_$(date +%Y%m%d_%H%M%S).txt"
echo
echo -e "${INFO} Saving diagnostic report to: ${YELLOW}$report_file${NC}"

# Re-run sem cores para o arquivo
{
    echo "PowerEdge Diagnostic Report"
    echo "=========================="
    echo "Date: $(date)"
    echo "System: $(uname -a)"
    echo "User: $(whoami)"
    echo "Python: $(python3 --version 2>/dev/null || echo 'Not found')"
    echo
    
    # Replicar informações principais sem cores
    echo "File Check:"
    for file in "${required_files[@]}"; do
        if [ -f "$file" ]; then
            echo "  ✓ $file"
        else
            echo "  ✗ $file MISSING"
        fi
    done
    
    echo
    echo "Python Dependencies:"
    deps=("flask" "flask-socketio")
    for dep in "${deps[@]}"; do
        if python3 -c "import $dep" 2>/dev/null; then
            echo "  ✓ $dep"
        else
            echo "  ✗ $dep NOT INSTALLED"
        fi
    done
    
    echo
    echo "Process Status:"
    if pgrep -f "python.*run.py" > /dev/null; then
        echo "  ✓ PowerEdge running"
        ps aux | grep -v grep | grep "python.*run.py"
    else
        echo "  ✗ PowerEdge not running"
    fi
    
    echo
    echo "System Resources:"
    if command -v free > /dev/null; then
        free -h
    fi
    df -h .
    
} > "$report_file"

echo -e "${SUCCESS} Report saved successfully!"
