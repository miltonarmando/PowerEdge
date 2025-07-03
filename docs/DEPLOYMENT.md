# PowerEdge - Guia de Implantação e Deploy

## 📋 Índice
- [Visão Geral](#visão-geral)
- [Deploy em Produção](#deploy-em-produção)
- [Deploy para Demonstração](#deploy-para-demonstração)
- [Deploy em Desenvolvimento](#deploy-em-desenvolvimento)
- [Configuração de Rede](#configuração-de-rede)
- [Monitoramento e Manutenção](#monitoramento-e-manutenção)
- [Troubleshooting](#troubleshooting)

## 🎯 Visão Geral

Este guia aborda diferentes cenários de deploy do PowerEdge, desde ambiente de produção completo até demonstrações e desenvolvimento.

### Cenários de Deploy
- **🏭 Produção**: Raspberry Pi com hardware completo
- **🧪 Demonstração**: Qualquer computador para apresentações
- **💻 Desenvolvimento**: Ambiente local para desenvolvedores
- **☁️ Cloud/VPS**: Deploy remoto para acesso externo

## 🏭 Deploy em Produção

### 📋 Pré-requisitos
- Raspberry Pi 4B (4GB RAM recomendado)
- MicroSD 32GB+ (Classe 10)
- ADS1115 ADC configurado
- Sensores de tensão instalados
- Conexão de rede estável

### 🔧 1. Preparação do Hardware

#### Sistema Operacional
```bash
# Baixar Raspberry Pi OS Lite
# Gravar no SD card com Raspberry Pi Imager
# Habilitar SSH antes do boot

# Primeiro boot - configuração básica
sudo raspi-config
# → Interface Options → I2C → Enable
# → Advanced Options → Expand Filesystem
# → System Options → Boot/Auto Login → Console Autologin
```

#### Conexões I2C
```
ADS1115          Raspberry Pi
-------          ------------
VDD     ───────→ 3.3V (Pin 1)
GND     ───────→ GND (Pin 6)  
SCL     ───────→ GPIO 3 (Pin 5)
SDA     ───────→ GPIO 2 (Pin 3)
ADDR    ───────→ GND (0x48)
```

### 🚀 2. Instalação Automatizada

```bash
# Clonar repositório
git clone https://github.com/seu-usuario/PowerEdge.git
cd PowerEdge

# Tornar scripts executáveis
chmod +x *.sh

# Instalação completa (automática)
./install.sh
```

### ⚙️ 3. Configuração Manual (Alternativa)

```bash
# 1. Configurar ambiente Python
./setup_python.sh

# 2. Reiniciar para aplicar configurações I2C
sudo reboot

# 3. Instalar dependências
pip install -r requirements.txt

# 4. Testar hardware
python -c "
import board
import busio
import adafruit_ads1x15.ads1115 as ADS
print('Hardware ADS1115 detectado com sucesso!')
"
```

### 🔄 4. Execução em Produção

```bash
# Execução simples
python app/run.py

# Execução com logs
python app/run.py 2>&1 | tee poweredge.log

# Execução em background
nohup python app/run.py > poweredge.log 2>&1 &
```

### 🔧 5. Configuração como Serviço (systemd)

```bash
# Criar arquivo de serviço
sudo nano /etc/systemd/system/poweredge.service
```

```ini
[Unit]
Description=PowerEdge Energy Monitoring System
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/PowerEdge
ExecStart=/usr/bin/python3 /home/pi/PowerEdge/app/run.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

```bash
# Ativar e iniciar serviço
sudo systemctl daemon-reload
sudo systemctl enable poweredge.service
sudo systemctl start poweredge.service

# Verificar status
sudo systemctl status poweredge.service

# Ver logs
sudo journalctl -u poweredge.service -f
```

## 🧪 Deploy para Demonstração

### 💻 Qualquer Computador (Windows/Linux/Mac)

```bash
# 1. Clonar repositório
git clone https://github.com/seu-usuario/PowerEdge.git
cd PowerEdge

# 2. Instalar Python 3.8+
# Windows: Baixar de python.org
# Linux: sudo apt install python3 python3-pip
# Mac: brew install python3

# 3. Instalar dependências (sem hardware)
pip install flask flask-socketio

# 4. Executar em modo simulação
python app/run.py
```

### 🎬 Script de Demonstração Completa

```bash
# Executar demonstração interativa
python demo.py
```

**Saída esperada:**
```
🚀 PowerEdge Demo v2.0
====================

✅ Servidor iniciado em modo simulação
✅ Interface web: http://localhost:5000
✅ WebSocket: ws://localhost:8765
✅ API REST: http://localhost:5000/api/

🧪 Testando funcionalidades...
   → API Status: OK
   → WebSocket: Conectado
   → Dados simulados: OK
   → Interface: Carregada

📊 Sistema pronto para demonstração!
```

### 📱 Demo Remoto (Para Apresentações)

```bash
# 1. Deploy em VPS/Cloud
# 2. Configurar firewall
sudo ufw allow 5000
sudo ufw allow 8765

# 3. Executar com IP público
python app/run.py --host=0.0.0.0

# 4. Acessar via: http://SEU-IP:5000
```

## 💻 Deploy em Desenvolvimento

### 🔧 Ambiente Local Completo

```bash
# 1. Fork do repositório
git fork https://github.com/usuario-original/PowerEdge.git
git clone https://github.com/seu-usuario/PowerEdge.git
cd PowerEdge

# 2. Criar ambiente virtual
python -m venv venv

# Linux/Mac
source venv/bin/activate

# Windows
venv\Scripts\activate

# 3. Instalar dependências de desenvolvimento
pip install -r requirements.txt
pip install pytest black flake8  # Ferramentas de dev

# 4. Configurar IDE (VS Code recomendado)
code .
```

### 🧪 Configuração para Testes

```bash
# Executar em modo debug
export FLASK_ENV=development  # Linux/Mac
set FLASK_ENV=development     # Windows

python app/run.py
```

### 🔄 Hot Reload para Desenvolvimento

```python
# Adicionar no app/run.py para desenvolvimento
if __name__ == '__main__':
    app.run(
        host='127.0.0.1',
        port=5000,
        debug=True,        # Hot reload ativado
        use_reloader=True  # Reinicia automaticamente
    )
```

## 🌐 Configuração de Rede

### 🏠 Rede Local (LAN)

```python
# app/config.py - Configurar IP para rede local
HOST = '0.0.0.0'  # Aceita conexões de qualquer IP
PORT = 5000
WEBSOCKET_PORT = 8765
```

```bash
# Descobrir IP do Raspberry Pi
hostname -I

# Acessar de outros dispositivos
# http://192.168.1.XXX:5000
```

### 🔧 Configuração de Firewall

```bash
# Ubuntu/Debian
sudo ufw allow 5000
sudo ufw allow 8765

# CentOS/RHEL
sudo firewall-cmd --permanent --add-port=5000/tcp
sudo firewall-cmd --permanent --add-port=8765/tcp
sudo firewall-cmd --reload
```

### 🌍 Acesso Externo (Internet)

#### Opção 1: Port Forwarding no Router
```
Router Config:
External Port 8080 → Internal IP:5000
External Port 8765 → Internal IP:8765
```

#### Opção 2: Túnel SSH (Desenvolvimento)
```bash
# No servidor remoto
ssh -R 8080:localhost:5000 usuario@servidor-remoto.com

# Acessar via: http://servidor-remoto.com:8080
```

#### Opção 3: Reverse Proxy (Nginx)
```nginx
# /etc/nginx/sites-available/poweredge
server {
    listen 80;
    server_name seu-dominio.com;
    
    location / {
        proxy_pass http://localhost:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    location /socket.io/ {
        proxy_pass http://localhost:8765;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

## 📊 Monitoramento e Manutenção

### 🔍 Logs e Debugging

```bash
# Ver logs em tempo real
tail -f poweredge.log

# Logs do sistema (se usando systemd)
sudo journalctl -u poweredge.service -f

# Logs estruturados
grep "ERROR" poweredge.log
grep "WARNING" poweredge.log
```

### 📈 Monitoramento de Performance

```bash
# CPU e memória
htop

# Uso de disco
df -h

# Processos Python
ps aux | grep python

# Conexões de rede
netstat -tulpn | grep :5000
```

### 🔄 Backup e Restore

```bash
# Backup do banco de dados
cp energy_monitoring.db backup_$(date +%Y%m%d).db

# Backup completo
tar -czf poweredge_backup_$(date +%Y%m%d).tar.gz \
    --exclude='.git' \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    PowerEdge/

# Restore
tar -xzf poweredge_backup_20231215.tar.gz
```

### 🔧 Atualizações

```bash
# Atualizar código
git pull origin main

# Atualizar dependências
pip install -r requirements.txt --upgrade

# Reiniciar serviço
sudo systemctl restart poweredge.service
```

## 🚨 Troubleshooting

### ❌ Problemas Comuns

#### 1. Hardware ADS1115 não detectado
```bash
# Verificar I2C
sudo i2cdetect -y 1
# Deve mostrar dispositivo em 0x48

# Verificar conexões
# - VDD → 3.3V (não 5V!)
# - GND → GND
# - SCL → GPIO 3
# - SDA → GPIO 2

# Testar manualmente
python -c "
import board, busio
import adafruit_ads1x15.ads1115 as ADS
i2c = busio.I2C(board.SCL, board.SDA)
ads = ADS.ADS1115(i2c)
print('ADS1115 OK!')
"
```

#### 2. Erro de dependências
```bash
# Reinstalar dependências
pip uninstall -r requirements.txt -y
pip install -r requirements.txt

# Verificar versão Python
python --version
# Deve ser 3.8+
```

#### 3. Porta ocupada
```bash
# Verificar processo usando porta 5000
sudo lsof -i :5000

# Matar processo
sudo kill -9 PID

# Ou usar porta alternativa
python app/run.py --port=5001
```

#### 4. Interface não carrega
```bash
# Verificar arquivos estáticos
ls -la static/
# Deve conter: index.html, style.css, script.js

# Verificar permissões
chmod 644 static/*
```

#### 5. WebSocket não conecta
```bash
# Testar WebSocket manualmente
python -c "
import websocket
ws = websocket.create_connection('ws://localhost:8765')
print('WebSocket OK!')
ws.close()
"

# Verificar firewall
sudo ufw status
```

### 🔧 Comandos de Diagnóstico

```bash
# Status completo do sistema
./diagnostic.sh
```

```bash
#!/bin/bash
# diagnostic.sh
echo "=== PowerEdge Diagnostic ==="
echo "Date: $(date)"
echo
echo "1. System Info:"
uname -a
echo
echo "2. Python Version:"
python --version
echo
echo "3. I2C Devices:"
sudo i2cdetect -y 1 2>/dev/null || echo "I2C not available"
echo
echo "4. PowerEdge Process:"
ps aux | grep -v grep | grep python
echo
echo "5. Network Ports:"
netstat -tulpn | grep -E ':(5000|8765)'
echo
echo "6. Disk Space:"
df -h
echo
echo "7. Memory Usage:"
free -h
echo "=== End Diagnostic ==="
```

### 📞 Suporte

#### Logs para Suporte
```bash
# Gerar relatório completo
{
    echo "=== PowerEdge Error Report ==="
    echo "Date: $(date)"
    echo "System: $(uname -a)"
    echo "Python: $(python --version)"
    echo
    echo "=== Last 50 lines of log ==="
    tail -50 poweredge.log
    echo
    echo "=== Hardware Test ==="
    python -c "
    try:
        import board, busio
        import adafruit_ads1x15.ads1115 as ADS
        print('Hardware: OK')
    except Exception as e:
        print(f'Hardware: ERROR - {e}')
    "
} > error_report_$(date +%Y%m%d_%H%M%S).txt
```

---

**PowerEdge Deploy Guide v2.0** - Deploy profissional para todos os ambientes.
