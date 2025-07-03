# PowerEdge v2.0 - Guia de Instalação e Configuração Completo

Este guia fornece instruções detalhadas para instalação, configuração e uso do sistema PowerEdge em diferentes ambientes.

## 📋 Índice

- [Requisitos do Sistema](#-requisitos-do-sistema)
- [Instalação Rápida](#-instalação-rápida)
- [Instalação Detalhada](#-instalação-detalhada)
- [Configuração de Hardware](#-configuração-de-hardware)
- [Configuração de Software](#-configuração-de-software)
- [Modo Simulação vs Produção](#-modo-simulação-vs-produção)
- [Solução de Problemas](#-solução-de-problemas)
- [Configurações Avançadas](#-configurações-avançadas)

---

## 🖥️ Requisitos do Sistema

### Hardware Mínimo

#### **Para Produção (Monitoramento Real):**
```
✅ Raspberry Pi 3B+ ou superior (4B recomendado)
✅ MicroSD 16GB Classe 10 ou superior
✅ Fonte 5V/3A oficial Raspberry Pi
✅ ADS1115 ADC 16-bit I2C
✅ Sensores de tensão (4x)
✅ Divisores de tensão (se necessário)
✅ Cabos jumper e protoboard
✅ Case para proteção (recomendado)
```

#### **Para Simulação/Desenvolvimento:**
```
✅ Qualquer computador (Windows/Linux/Mac)
✅ Python 3.7+ instalado
✅ 2GB RAM mínimo
✅ 1GB espaço em disco
✅ Conexão com internet (para instalação)
```

### Software

#### **Sistema Operacional:**
- **Produção**: Raspberry Pi OS Lite/Desktop (64-bit recomendado)
- **Simulação**: Windows 10+, macOS 10.14+, Ubuntu 18.04+

#### **Dependências:**
- Python 3.7 ou superior
- pip (gerenciador de pacotes Python)
- Git (para clonagem do repositório)

---

## ⚡ Instalação Rápida

### Para Raspberry Pi (Produção)

```bash
# 1. Clone o repositório
git clone https://github.com/seu-usuario/PowerEdge.git
cd PowerEdge

# 2. Execute a instalação automática
chmod +x setup_python.sh install.sh
./setup_python.sh
sudo reboot

# 3. Após reinicialização
./install.sh

# 4. Inicie o sistema
./run.sh
```

### Para Desenvolvimento/Simulação

```bash
# 1. Clone o repositório
git clone https://github.com/seu-usuario/PowerEdge.git
cd PowerEdge

# 2. Crie ambiente virtual
python -m venv venv
source venv/bin/activate  # No Windows: venv\Scripts\activate

# 3. Instale dependências
pip install -r requirements.txt

# 4. Execute em modo simulação
python app/run.py
```

---

## 🔧 Instalação Detalhada

### Passo 1: Preparação do Raspberry Pi

#### 1.1 Instalação do SO
```bash
# Use Raspberry Pi Imager para gravar a imagem
# Recomendado: Raspberry Pi OS Lite (64-bit)
# Habilite SSH durante a gravação se necessário
```

#### 1.2 Primeira Configuração
```bash
# Atualize o sistema
sudo apt update && sudo apt upgrade -y

# Configure localização e teclado
sudo raspi-config
# 5 Localisation Options > L1 Locale
# 5 Localisation Options > L3 Keyboard
```

#### 1.3 Habilitar I2C e SSH
```bash
sudo raspi-config
# 3 Interface Options > I2C > Yes
# 3 Interface Options > SSH > Yes (se necessário)
sudo reboot
```

### Passo 2: Configuração do Ambiente Python

#### 2.1 Execute o Script de Configuração
```bash
cd PowerEdge
./setup_python.sh
```

#### 2.2 Verificação Manual (Alternativa)
```bash
# Verificar versão Python
python3 --version  # Deve ser 3.7+

# Instalar ferramentas essenciais
sudo apt install -y python3-dev python3-pip python3-venv git i2c-tools

# Verificar I2C
ls /dev/i2c*  # Deve mostrar /dev/i2c-1
sudo i2cdetect -y 1  # Scanner I2C
```

### Passo 3: Instalação do PowerEdge

#### 3.1 Instalação Automática
```bash
./install.sh
```

#### 3.2 Instalação Manual (Passo a Passo)
```bash
# Criar ambiente virtual
python3 -m venv venv
source venv/bin/activate

# Instalar dependências
pip install --upgrade pip
pip install -r requirements.txt

# Criar estrutura de diretórios
mkdir -p logs backups

# Configurar variáveis de ambiente
cp .env.example .env  # Se existir
nano .env  # Editar configurações
```

### Passo 4: Configuração do Serviço Systemd

#### 4.1 Criar Serviço (Automático no install.sh)
```bash
sudo nano /etc/systemd/system/poweredge.service
```

#### 4.2 Conteúdo do Serviço
```ini
[Unit]
Description=PowerEdge - Sistema de Monitoramento de Energia
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/PowerEdge
Environment=PATH=/home/pi/PowerEdge/venv/bin
ExecStart=/home/pi/PowerEdge/venv/bin/python /home/pi/PowerEdge/app/run.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

#### 4.3 Habilitar Serviço
```bash
sudo systemctl daemon-reload
sudo systemctl enable poweredge
sudo systemctl start poweredge
```

---

## 🔌 Configuração de Hardware

### Esquema de Conexões

#### ADS1115 para Raspberry Pi
```
ADS1115    Raspberry Pi        Descrição
-------    ------------        ----------
VDD     -> 3.3V (Pin 1)       Alimentação
GND     -> GND (Pin 6)        Terra
SCL     -> GPIO 3 (Pin 5)     Clock I2C
SDA     -> GPIO 2 (Pin 3)     Data I2C
ADDR    -> GND                Endereço 0x48
```

#### Canais do ADS1115
```
Canal   Fonte           Tensão Esperada    Observações
-----   -----           ---------------    -----------
A0      Rede Elétrica   220V (dividida)    Use divisor 100:1
A1      Energia Solar   24V (dividida)     Use divisor 10:1
A2      Gerador         12V (dividida)     Use divisor 5:1
A3      UPS/Bateria     12V (dividida)     Use divisor 5:1
```

### Divisores de Tensão

#### Para Rede Elétrica (220V → 3.3V)
```
R1 = 100kΩ (para 220V)
R2 = 1.5kΩ  (para 3.3V max)
Relação: 1:67 (220V → 3.28V)
```

#### Para Solar/Gerador/UPS (12-24V → 3.3V)
```
R1 = 10kΩ   (para 24V)
R2 = 2.2kΩ  (para 3.3V max)
Relação: 1:5.5 (24V → 4.4V, usar com cuidado)

Alternativa segura:
R1 = 22kΩ   (para 24V)
R2 = 3.3kΩ  (para 3.3V max)
Relação: 1:7.7 (24V → 3.1V)
```

### Verificação de Hardware

#### Teste I2C
```bash
# Verificar dispositivos I2C
sudo i2cdetect -y 1

# Saída esperada (ADS1115 no endereço 0x48):
#      0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
# 40: -- -- -- -- -- -- -- -- 48 -- -- -- -- -- -- --
```

#### Teste de Tensão
```bash
# Com sistema rodando, verificar logs
tail -f logs/energia.log

# Deve mostrar leituras de tensão:
# [2025-07-02 10:30:15] REDE - ATIVA - 220.5V
# [2025-07-02 10:30:16] SOLAR - ATIVA - 24.2V
```

---

## ⚙️ Configuração de Software

### Arquivo de Configuração (.env)

#### Criar Arquivo
```bash
nano .env
```

#### Configurações Padrão
```bash
# Configurações do Banco de Dados
DATABASE_PATH=energia.db

# Configurações de Rede
FLASK_HOST=0.0.0.0
FLASK_PORT=5000
WEBSOCKET_HOST=0.0.0.0
WEBSOCKET_PORT=8765

# Configurações de Monitoramento
LIMIAR_TENSAO=0.8
INTERVALO_LEITURA=1.0

# Configurações de Log
LOG_LEVEL=INFO
LOG_FILE=logs/energia.log
```

### Configuração Avançada (config.py)

#### Personalizar Fontes
```python
# Em app/config.py
FONTES_CONFIG = {
    "rede": {
        "canal": 0, 
        "nome": "Rede Elétrica", 
        "cor": "#4ecdc4",
        "icone": "🏠",
        "prioridade": 1,
        "fator_conversao": 67.0,  # Para divisor de tensão
        "limiar_personalizado": 200.0  # Volts
    },
    "solar": {
        "canal": 1,
        "nome": "Energia Solar",
        "cor": "#45b7d1",
        "icone": "☀️",
        "prioridade": 2,
        "fator_conversao": 7.7,
        "limiar_personalizado": 20.0
    }
    # ... continuar para outras fontes
}
```

#### Configurações do ADS1115
```python
# Gain (sensibilidade)
ADS_GAIN = 1        # ±4.096V (padrão)
# ADS_GAIN = 2/3    # ±6.144V
# ADS_GAIN = 2      # ±2.048V

# Taxa de amostragem
ADS_DATA_RATE = 128  # 128 SPS (padrão)
# ADS_DATA_RATE = 250  # Mais rápido
# ADS_DATA_RATE = 64   # Mais preciso
```

---

## 🎮 Modo Simulação vs Produção

### Modo Simulação (Desenvolvimento)

#### Quando é Ativado:
- Hardware não disponível (bibliotecas não instaladas)
- ADS1115 não conectado
- Executando em PC/Mac
- Flag `--simulate` (se implementada)

#### Características:
```python
# Valores simulados realistas
SIMULATION_VALUES = {
    "rede": 220.0,     # ±10%
    "solar": 24.0,     # ±10%
    "gerador": 12.5,   # ±10%
    "ups": 12.0        # ±10%
}

# Estados dinâmicos
- Variação aleatória de tensão
- Eventos de falha ocasionais
- Timestamps reais
- Todos os recursos da API funcionais
```

#### Vantagens:
- ✅ Desenvolvimento sem hardware
- ✅ Testes automatizados
- ✅ Demonstrações
- ✅ Debug de funcionalidades

### Modo Produção (Hardware Real)

#### Quando é Ativado:
- Raspberry Pi com bibliotecas instaladas
- ADS1115 detectado no I2C
- Sensores conectados
- Sistema em operação real

#### Características:
```python
# Leituras reais do hardware
hardware_reading = ads.read_voltage(channel)
converted_voltage = hardware_reading * conversion_factor

# Estados baseados em medições reais
if converted_voltage > THRESHOLD:
    status = "ATIVA"
else:
    status = "FALHA"
```

#### Vantagens:
- ✅ Monitoramento real
- ✅ Dados precisos
- ✅ Alertas confiáveis
- ✅ Histórico válido

### Transição Automática

O sistema detecta automaticamente qual modo usar:

```python
try:
    import board, busio, adafruit_ads1x15
    # Hardware disponível
    HARDWARE_AVAILABLE = True
    print("🔧 Modo PRODUÇÃO ativado")
    
except ImportError:
    # Hardware não disponível
    HARDWARE_AVAILABLE = False
    print("🎮 Modo SIMULAÇÃO ativado")
```

---

## 🐛 Solução de Problemas

### Problemas Comuns de Hardware

#### I2C Não Funciona
```bash
# Verificar se I2C está habilitado
sudo raspi-config
# 3 Interface Options > I2C > Yes

# Verificar módulos carregados
lsmod | grep i2c

# Deve mostrar: i2c_bcm2835

# Verificar dispositivos
ls /dev/i2c*
# Deve mostrar: /dev/i2c-1
```

#### ADS1115 Não Detectado
```bash
# Scanner I2C
sudo i2cdetect -y 1

# Se não aparecer 0x48:
1. Verificar conexões VDD, GND, SCL, SDA
2. Verificar se ADDR está em GND (endereço 0x48)
3. Verificar se cabo está funcionando
4. Testar com outro ADS1115
```

#### Leituras Incorretas
```bash
# Verificar logs
tail -f logs/energia.log

# Problemas comuns:
1. Divisor de tensão incorreto
2. Conexões soltas
3. Interferência elétrica
4. Calibração necessária
```

### Problemas de Software

#### Dependências Não Instaladas
```bash
# Reinstalar ambiente virtual
rm -rf venv
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

#### Permissões I2C
```bash
# Adicionar usuário ao grupo i2c
sudo usermod -a -G i2c $USER
sudo reboot

# Verificar grupos
groups
# Deve incluir: i2c
```

#### Porta Já Em Uso
```bash
# Verificar processos usando as portas
sudo netstat -tulpn | grep :5000
sudo netstat -tulpn | grep :8765

# Matar processo se necessário
sudo kill -9 PID
```

### Problemas de Rede

#### Interface Web Não Acessível
```bash
# Verificar IP do Raspberry Pi
hostname -I

# Verificar firewall (se habilitado)
sudo ufw status

# Testar conectividade
ping IP_DO_RASPBERRY
```

#### WebSocket Não Conecta
```bash
# Verificar se serviço está rodando
sudo systemctl status poweredge

# Verificar logs em tempo real
sudo journalctl -u poweredge -f

# Testar WebSocket manualmente
telnet IP_DO_RASPBERRY 8765
```

---

## 🔧 Configurações Avançadas

### Performance e Otimização

#### Configurações do Sistema
```bash
# Aumentar swap se necessário (apenas para desenvolvimento)
sudo dphys-swapfile swapoff
sudo nano /etc/dphys-swapfile
# CONF_SWAPSIZE=1024
sudo dphys-swapfile setup
sudo dphys-swapfile swapon
```

#### Otimizações Python
```python
# Em app/config.py - para sistemas com pouca RAM
import gc

# Configurações de performance
INTERVALO_LEITURA = 2.0  # Reduzir frequência se necessário
WEBSOCKET_PING_INTERVAL = 30  # Ping WebSocket menos frequente
LOG_LEVEL = "WARNING"  # Reduzir logs

# Limpeza automática de memória
def cleanup_memory():
    gc.collect()
```

### Backup e Recuperação

#### Backup Automático
```bash
# Criar script de backup
nano scripts/backup.sh
```

```bash
#!/bin/bash
# Script de backup do PowerEdge

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="backups"
DATABASE="energia.db"

# Criar backup do banco
if [ -f "$DATABASE" ]; then
    cp "$DATABASE" "$BACKUP_DIR/energia_backup_$DATE.db"
    echo "Backup criado: energia_backup_$DATE.db"
fi

# Manter apenas últimos 30 backups
ls -t $BACKUP_DIR/energia_backup_*.db | tail -n +31 | xargs rm -f
```

#### Cron para Backup Automático
```bash
# Editar crontab
crontab -e

# Adicionar linha (backup diário às 2h da manhã)
0 2 * * * /home/pi/PowerEdge/scripts/backup.sh
```

### Monitoramento e Alertas

#### Configurar Logs Estruturados
```python
# Em app/config.py
LOGGING_CONFIG = {
    'version': 1,
    'formatters': {
        'detailed': {
            'format': '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        },
        'json': {
            'format': '{"time":"%(asctime)s","level":"%(levelname)s","message":"%(message)s"}'
        }
    },
    'handlers': {
        'file': {
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': 'logs/energia.log',
            'maxBytes': 10485760,  # 10MB
            'backupCount': 5,
            'formatter': 'detailed'
        }
    }
}
```

#### Integração com Sistemas Externos
```python
# Exemplo de webhook para alertas
def send_alert(source, status, voltage):
    webhook_url = "https://your-webhook.com/alert"
    payload = {
        "source": source,
        "status": status,
        "voltage": voltage,
        "timestamp": datetime.now().isoformat()
    }
    
    try:
        requests.post(webhook_url, json=payload, timeout=5)
    except Exception as e:
        logger.error(f"Erro ao enviar alerta: {e}")
```

### Segurança

#### Configurar HTTPS (Opcional)
```bash
# Gerar certificado autoassinado
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes
```

```python
# Em app/run.py - habilitar HTTPS
if __name__ == "__main__":
    app.run(
        host=FLASK_HOST,
        port=FLASK_PORT,
        ssl_context=('cert.pem', 'key.pem'),  # Habilitar HTTPS
        debug=False
    )
```

#### Autenticação Básica (Opcional)
```python
from flask_httpauth import HTTPBasicAuth

auth = HTTPBasicAuth()

users = {
    "admin": "sua_senha_segura"
}

@auth.verify_password
def verify_password(username, password):
    if username in users and users[username] == password:
        return username

@app.route("/")
@auth.login_required
def index():
    return send_from_directory("../static", "index.html")
```

---

## 📚 Recursos Adicionais

### Scripts Úteis

#### Teste de Sistema Completo
```bash
# Criar script de teste
nano scripts/test_system.sh
```

```bash
#!/bin/bash
# Teste completo do sistema PowerEdge

echo "🧪 Teste Completo do PowerEdge"
echo "=============================="

# Testar I2C
echo "📡 Testando I2C..."
sudo i2cdetect -y 1 | grep 48 && echo "✅ ADS1115 detectado" || echo "❌ ADS1115 não encontrado"

# Testar Python
echo "🐍 Testando ambiente Python..."
python3 -c "import flask, websockets; print('✅ Dependências OK')" || echo "❌ Dependências com problema"

# Testar conectividade
echo "🌐 Testando conectividade..."
curl -s http://localhost:5000/status > /dev/null && echo "✅ API respondendo" || echo "❌ API não respondendo"

echo "✅ Teste concluído!"
```

### Documentação da API

#### Endpoints Detalhados
```bash
# GET /status - Status completo do sistema
curl -X GET http://localhost:5000/status

# GET /eventos - Lista de eventos com filtros
curl -X GET "http://localhost:5000/eventos?limite=10&fonte=rede"

# POST /eventos - Criar evento manual
curl -X POST http://localhost:5000/eventos \
  -H "Content-Type: application/json" \
  -d '{"fonte":"rede","tipo":"TESTE","tensao":220.5}'
```

---

**PowerEdge v2.0** - Guia de Instalação e Configuração Completo
Desenvolvido com ❤️ para Raspberry Pi e ambientes de desenvolvimento
