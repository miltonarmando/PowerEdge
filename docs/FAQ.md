# PowerEdge - FAQ e Troubleshooting

## 📋 Índice
- [Perguntas Frequentes (FAQ)](#perguntas-frequentes-faq)
- [Problemas de Hardware](#problemas-de-hardware)
- [Problemas de Software](#problemas-de-software)
- [Problemas de Rede](#problemas-de-rede)
- [Problemas de Interface](#problemas-de-interface)
- [Configuração e Setup](#configuração-e-setup)
- [Performance e Otimização](#performance-e-otimização)

## ❓ Perguntas Frequentes (FAQ)

### 🤔 Q1: Como sei se estou rodando em modo simulação ou produção?
**R:** O sistema detecta automaticamente. Verifique o log de inicialização:
```bash
# Modo Produção
"Hardware ADS1115 detectado. Modo produção ativado."

# Modo Simulação  
"Hardware ADS1115 não detectado. Modo simulação ativado."
```

### 🤔 Q2: Posso rodar o sistema sem Raspberry Pi?
**R:** Sim! O PowerEdge funciona em **qualquer computador** (Windows, Linux, Mac) em modo simulação para demonstrações e desenvolvimento.

### 🤔 Q3: Como adicionar mais fontes de energia?
**R:** Edite `app/config.py`:
```python
CONFIGURACAO = {
    # Fontes existentes...
    'nova_fonte': {
        'nome': 'Nova Fonte',
        'threshold': 100.0,
        'prioridade': 5
    }
}
```

### 🤔 Q4: Os dados simulados são realistas?
**R:** Sim! A simulação usa:
- Valores base realistas por tipo de fonte
- Variação natural (±10-30V para AC, ±2V para DC)
- Probabilidades de disponibilidade baseadas na realidade
- Flutuações temporais

### 🤔 Q5: Como exportar dados históricos?
**R:** Use a interface web:
1. Vá para "Histórico" → "Exportar"
2. Selecione período e fontes
3. Clique "Exportar CSV"
4. Arquivo salvo automaticamente

### 🤔 Q6: Posso acessar de outros dispositivos na rede?
**R:** Sim, configure o IP:
```bash
# Descobrir IP do Raspberry Pi
hostname -I

# Acessar de outros dispositivos
# http://192.168.1.XXX:5000
```

### 🤔 Q7: Como fazer backup dos dados?
**R:** 
```bash
# Backup do banco de dados
cp energy_monitoring.db backup_$(date +%Y%m%d).db

# Backup completo
tar -czf poweredge_backup.tar.gz PowerEdge/
```

### 🤔 Q8: O sistema funciona offline?
**R:** Sim! Todos os recursos funcionam localmente:
- Interface web local
- Banco de dados SQLite local
- Não precisa de internet

### 🤔 Q9: Como alterar a frequência de leitura?
**R:** Edite `app/config.py`:
```python
INTERVALO_LEITURA = 5.0  # segundos entre leituras
```

### 🤔 Q10: Suporta múltiplos usuários simultâneos?
**R:** Sim! Interface web e WebSocket suportam múltiplas conexões simultâneas.

## ⚡ Problemas de Hardware

### ❌ Erro: "ADS1115 não detectado"

**Sintomas:**
- Sistema inicia em modo simulação sempre
- Log mostra "Hardware ADS1115 não detectado"

**Soluções:**

1. **Verificar I2C habilitado:**
```bash
sudo raspi-config
# → Interface Options → I2C → Enable
sudo reboot
```

2. **Verificar conexões físicas:**
```
ADS1115    Raspberry Pi
VDD   →    3.3V (Pin 1) ⚠️ NÃO 5V!
GND   →    GND (Pin 6)
SCL   →    GPIO 3 (Pin 5)
SDA   →    GPIO 2 (Pin 3)
ADDR  →    GND (endereço 0x48)
```

3. **Testar I2C:**
```bash
# Verificar dispositivos I2C
sudo i2cdetect -y 1
# Deve mostrar "48" na tabela

# Se não aparecer:
sudo apt update
sudo apt install i2c-tools
```

4. **Testar ADS1115 manualmente:**
```bash
python3 -c "
import board
import busio
import adafruit_ads1x15.ads1115 as ADS
try:
    i2c = busio.I2C(board.SCL, board.SDA)
    ads = ADS.ADS1115(i2c)
    print('✅ ADS1115 OK!')
except Exception as e:
    print(f'❌ Erro: {e}')
"
```

### ❌ Erro: "Leituras instáveis ou incorretas"

**Sintomas:**
- Valores oscilam muito
- Leituras claramente incorretas

**Soluções:**

1. **Verificar alimentação:**
```bash
# Verificar tensão do Pi
vcgencmd measure_volts
# Deve mostrar ~1.2V (não a tensão de entrada)

# Usar fonte oficial 5V/3A
```

2. **Verificar cabos:**
- Usar cabos curtos (<30cm)
- Evitar interferência eletromagnética
- Soldar conexões se possível

3. **Configurar ganho do ADC:**
```python
# app/config.py
GANHO_ADC = 1  # Para tensões até 4.096V
# GANHO_ADC = 2/3  # Para tensões até 6.144V
```

4. **Adicionar filtros:**
```python
# app/run.py - na função ler_energia_real()
# Média móvel simples
historico = []
for fonte, canal in canais_adc.items():
    tensao = canal.voltage
    historico.append(tensao)
    if len(historico) > 5:
        historico.pop(0)
    tensao_filtrada = sum(historico) / len(historico)
```

### ❌ Erro: "ModuleNotFoundError: No module named 'board'"

**Sintomas:**
- Erro ao importar biblioteca do hardware

**Soluções:**

1. **Instalar bibliotecas do CircuitPython:**
```bash
pip install adafruit-circuitpython-ads1x15
pip install adafruit-blinka
```

2. **Verificar se está no Raspberry Pi:**
```bash
# Este erro é normal em computadores que não são Pi
# Sistema automaticamente ativa modo simulação
```

## 💻 Problemas de Software

### ❌ Erro: "Port 5000 already in use"

**Sintomas:**
- Sistema não inicia
- Erro de porta ocupada

**Soluções:**

1. **Verificar processo usando porta:**
```bash
sudo lsof -i :5000
sudo kill -9 PID_DO_PROCESSO
```

2. **Usar porta alternativa:**
```bash
# Temporário
python app/run.py --port=5001

# Permanente - editar app/config.py
PORT = 5001
```

3. **Parar todos os processos Python:**
```bash
sudo pkill -f python
```

### ❌ Erro: "Database locked"

**Sintomas:**
- Erro ao salvar dados
- Interface não atualiza histórico

**Soluções:**

1. **Verificar permissões:**
```bash
chmod 666 energy_monitoring.db
chmod 777 . # diretório do banco
```

2. **Fechar conexões pendentes:**
```bash
sudo lsof energy_monitoring.db
sudo kill PID_DO_PROCESSO
```

3. **Reparar banco de dados:**
```bash
sqlite3 energy_monitoring.db ".recover" | sqlite3 energy_monitoring_new.db
mv energy_monitoring.db energy_monitoring_old.db
mv energy_monitoring_new.db energy_monitoring.db
```

### ❌ Erro: Python dependencies

**Sintomas:**
- ModuleNotFoundError
- ImportError

**Soluções:**

1. **Reinstalar dependências:**
```bash
pip uninstall -r requirements.txt -y
pip install -r requirements.txt
```

2. **Verificar versão Python:**
```bash
python --version
# Deve ser 3.8 ou superior
```

3. **Usar ambiente virtual:**
```bash
python -m venv venv
source venv/bin/activate  # Linux/Mac
# ou
venv\Scripts\activate     # Windows
pip install -r requirements.txt
```

## 🌐 Problemas de Rede

### ❌ "Não consigo acessar de outros dispositivos"

**Sintomas:**
- Interface abre só no localhost
- Outros dispositivos não conseguem conectar

**Soluções:**

1. **Configurar host para aceitar conexões externas:**
```python
# app/run.py
app.run(host='0.0.0.0', port=5000)
```

2. **Verificar firewall:**
```bash
# Ubuntu/Debian
sudo ufw allow 5000
sudo ufw allow 8765

# Verificar status
sudo ufw status
```

3. **Descobrir IP correto:**
```bash
# No Raspberry Pi
hostname -I
ip addr show

# Acessar de outros dispositivos
# http://IP_DO_PI:5000
```

### ❌ "WebSocket não conecta"

**Sintomas:**
- Interface carrega mas dados não atualizam
- Console mostra erro de WebSocket

**Soluções:**

1. **Verificar porta WebSocket:**
```bash
netstat -tulpn | grep 8765
```

2. **Testar WebSocket manualmente:**
```python
import websocket
try:
    ws = websocket.create_connection('ws://localhost:8765')
    print('✅ WebSocket OK!')
    ws.close()
except Exception as e:
    print(f'❌ WebSocket erro: {e}')
```

3. **Verificar JavaScript no navegador:**
```javascript
// Console do navegador (F12)
console.log('WebSocket status:', window.websocket?.readyState);
```

## 🖥️ Problemas de Interface

### ❌ "Página não carrega ou fica em branco"

**Sintomas:**
- Navegador mostra página vazia
- Erro 404 ou 500

**Soluções:**

1. **Verificar arquivos estáticos:**
```bash
ls -la static/
# Deve conter: index.html, style.css, script.js

# Verificar permissões
chmod 644 static/*
```

2. **Verificar logs do Flask:**
```bash
python app/run.py
# Ver mensagens de erro no terminal
```

3. **Testar diferentes navegadores:**
- Chrome/Chromium
- Firefox
- Safari

4. **Limpar cache do navegador:**
```
Ctrl+F5 (força refresh)
ou
F12 → Application → Storage → Clear Storage
```

### ❌ "Dados não atualizam em tempo real"

**Sintomas:**
- Interface estática
- Valores não mudam

**Soluções:**

1. **Verificar JavaScript no console:**
```
F12 → Console → Verificar erros
```

2. **Verificar conexão WebSocket:**
```javascript
// No console do navegador
window.websocket.readyState
// 1 = conectado, 3 = desconectado
```

3. **Forçar reconexão:**
```
F5 (refresh da página)
```

### ❌ "Interface não responsiva no mobile"

**Sintomas:**
- Layout quebrado no celular
- Elementos sobrepostos

**Soluções:**

1. **Verificar viewport:**
```html
<!-- Deve estar presente no index.html -->
<meta name="viewport" content="width=device-width, initial-scale=1.0">
```

2. **Forçar refresh no mobile:**
```
Segurar refresh + Clear cache
```

## ⚙️ Configuração e Setup

### ❌ "Script install.sh falha"

**Sintomas:**
- Erro durante instalação automática

**Soluções:**

1. **Verificar permissões:**
```bash
chmod +x install.sh setup_python.sh
```

2. **Executar passo a passo:**
```bash
# Em vez de ./install.sh, executar:
./setup_python.sh
sudo reboot
pip install -r requirements.txt
```

3. **Verificar logs de erro:**
```bash
./install.sh 2>&1 | tee install.log
cat install.log
```

### ❌ "Erro de permissões no Raspberry Pi"

**Sintomas:**
- Permission denied
- Não consegue acessar GPIO/I2C

**Soluções:**

1. **Adicionar usuário aos grupos:**
```bash
sudo usermod -a -G i2c,spi,gpio pi
# ou seu usuário atual:
sudo usermod -a -G i2c,spi,gpio $USER

# Logout e login novamente
```

2. **Verificar grupos:**
```bash
groups
# Deve mostrar: i2c spi gpio
```

## 🚀 Performance e Otimização

### 🐌 "Sistema lento ou travando"

**Sintomas:**
- Interface demorada
- Leituras atrasadas

**Soluções:**

1. **Verificar uso de recursos:**
```bash
htop
# Verificar CPU e RAM

df -h
# Verificar espaço em disco
```

2. **Otimizar frequência de leitura:**
```python
# app/config.py
INTERVALO_LEITURA = 5.0  # Aumentar intervalo
```

3. **Limpar banco de dados antigo:**
```python
# Manter só últimos 30 dias
python -c "
import sqlite3
from datetime import datetime, timedelta
conn = sqlite3.connect('energy_monitoring.db')
cutoff = datetime.now() - timedelta(days=30)
conn.execute('DELETE FROM eventos WHERE timestamp < ?', (cutoff,))
conn.commit()
conn.close()
print('Banco limpo!')
"
```

### 💾 "Muito uso de memória"

**Sintomas:**
- RAM alta
- Sistema swap ativo

**Soluções:**

1. **Verificar vazamentos de memória:**
```bash
ps aux | grep python
# Verificar se uso de RAM cresce continuamente
```

2. **Reiniciar periodicamente:**
```bash
# Adicionar no crontab
0 4 * * * sudo systemctl restart poweredge.service
```

3. **Configurar swap (se necessário):**
```bash
sudo dphys-swapfile swapoff
sudo nano /etc/dphys-swapfile
# CONF_SWAPSIZE=2048
sudo dphys-swapfile setup
sudo dphys-swapfile swapon
```

## 🆘 Scripts de Diagnóstico

### 🔍 Diagnóstico Completo

```bash
#!/bin/bash
# diagnostic_complete.sh

echo "🔍 PowerEdge Complete Diagnostic"
echo "================================"
echo

echo "📅 Date: $(date)"
echo "🖥️  System: $(uname -a)"
echo "🐍 Python: $(python3 --version)"
echo

echo "🔌 Hardware Check:"
echo "  I2C Status:"
if command -v i2cdetect > /dev/null; then
    sudo i2cdetect -y 1 2>/dev/null | grep -E '[0-9a-f]{2}' && echo "  ✅ I2C devices found" || echo "  ❌ No I2C devices"
else
    echo "  ❌ i2c-tools not installed"
fi

echo "  ADS1115 Test:"
python3 -c "
try:
    import board, busio
    import adafruit_ads1x15.ads1115 as ADS
    i2c = busio.I2C(board.SCL, board.SDA)
    ads = ADS.ADS1115(i2c)
    print('  ✅ ADS1115 accessible')
except ImportError:
    print('  ⚠️  ADS1115 libraries not installed (simulation mode)')
except Exception as e:
    print(f'  ❌ ADS1115 error: {e}')
"

echo
echo "🌐 Network Check:"
echo "  Local IPs:"
hostname -I | tr ' ' '\n' | grep -E '^[0-9]+\.' | sed 's/^/    /'

echo "  Port Status:"
netstat -tulpn 2>/dev/null | grep -E ':(5000|8765)' | sed 's/^/    /' || echo "    ❌ PowerEdge not running"

echo
echo "📁 Files Check:"
echo "  Required files:"
for file in "app/run.py" "app/config.py" "static/index.html" "requirements.txt"; do
    if [ -f "$file" ]; then
        echo "    ✅ $file"
    else
        echo "    ❌ $file missing"
    fi
done

echo
echo "💾 System Resources:"
echo "  Memory:"
free -h | sed 's/^/    /'
echo "  Disk:"
df -h / | sed 's/^/    /'

echo
echo "📊 PowerEdge Status:"
if pgrep -f "python.*run.py" > /dev/null; then
    echo "  ✅ PowerEdge running"
    echo "  Process info:"
    ps aux | grep -v grep | grep "python.*run.py" | sed 's/^/    /'
else
    echo "  ❌ PowerEdge not running"
fi

echo
echo "📝 Recent Logs:"
if [ -f "poweredge.log" ]; then
    echo "  Last 10 lines:"
    tail -10 poweredge.log | sed 's/^/    /'
else
    echo "  ❌ No log file found"
fi

echo
echo "🔍 Diagnostic complete!"
```

---

**PowerEdge FAQ & Troubleshooting v2.0** - Soluções para todos os problemas comuns.
