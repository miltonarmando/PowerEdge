# PowerEdge v2.0 - Sistema Avançado de Monitoramento de Energia

Sistema de monitoramento em tempo real para múltiplas fontes de energia usando Raspberry Pi com interface UX moderna e avançada.

## 🚀 Novidades da Versão 2.0

### Interface Moderna
- **Design System Avançado**: Interface completamente redesenhada com design moderno
- **Sidebar Responsiva**: Navegação intuitiva com sidebar colapsável
- **Dashboard Interativo**: Overview completo com cards de status em tempo real
- **Tema Claro**: Design profissional com sistema de cores consistente
- **Responsivo**: Adaptação automática para dispositivos móveis

### Funcionalidades Avançadas
- **4 Fontes de Energia**: Rede, Solar, Gerador e **UPS/Bateria** (NOVO!)
- **Notificações em Tempo Real**: Sistema de alertas visuais
- **Exportação de Dados**: Exportar histórico em formato CSV
- **Estatísticas Avançadas**: Gráficos de disponibilidade (planejado)
- **Configurações Dinâmicas**: Ajuste de parâmetros em tempo real

### Melhorias Técnicas
- **WebSocket Otimizado**: Reconexão automática e controle de estado
- **Arquitetura Modular**: Código JavaScript orientado a objetos
- **Performance**: Carregamento otimizado e cache inteligente
- **Acessibilidade**: Interface amigável e navegação por teclado

## 📊 Características

### Monitoramento
- **4 Fontes de Energia**:
  - 🏠 Rede Elétrica (Prioridade 1)
  - ☀️ Energia Solar (Prioridade 2)  
  - ⚡ Gerador (Prioridade 3)
  - 🔋 UPS/Bateria (Prioridade 4)

### Interfaces
- **WebSocket**: Dados em tempo real (ws://ip:8765)
- **API REST**: Consulta de eventos e status
- **Interface Web**: Dashboard moderno e responsivo

### Dados
- **Banco SQLite**: Histórico de eventos persistente
- **Logs Estruturados**: Sistema de logging avançado
- **Exportação**: CSV com filtros customizáveis

## 🔧 Hardware Necessário

- Raspberry Pi 4B (recomendado) ou 3B+
- ADS1115 ADC (16-bit, I2C)
- Sensores de tensão para cada fonte
- Divisores de tensão (se necessário)
- Cabos jumper e protoboard

### Conexões I2C
```
ADS1115 -> Raspberry Pi
VDD     -> 3.3V (Pin 1)
GND     -> GND (Pin 6)
SCL     -> GPIO 3 (Pin 5)
SDA     -> GPIO 2 (Pin 3)
ADDR    -> GND (endereço 0x48)
```

### Canais do ADS1115
- **A0**: Rede Elétrica
- **A1**: Energia Solar
- **A2**: Gerador
- **A3**: UPS/Bateria

## 🛠️ Instalação

### 1. Preparação do Sistema
```bash
# Clone o repositório
git clone <repo-url>
cd PowerEdge

# Torne os scripts executáveis
chmod +x setup_python.sh install.sh

# Configure o ambiente Python
./setup_python.sh

# Reinicie após configurar I2C
sudo reboot
```

### 2. Instalação Principal
```bash
# Execute a instalação completa
./install.sh
```

### 3. Configuração Manual (Alternativa)
```bash
# Instale dependências
pip install -r requirements.txt

# Configure I2C
sudo raspi-config
# Interface Options > I2C > Enable

# Execute o sistema
python app/run.py
```

## 🌐 API Endpoints

### Status e Monitoramento
- `GET /status` - Status atual de todas as fontes
- `GET /eventos` - Lista eventos com filtros
  - `?limite=100` - Limitar número de eventos
  - `?fonte=rede` - Filtrar por fonte específica
- `POST /eventos` - Criar evento manual

### WebSocket
- **URL**: `ws://ip:8765`
- **Dados**: JSON com status de todas as fontes em tempo real
- **Frequência**: Configurável (padrão: 1 segundo)

### Exemplo de Resposta da API
```json
{
  "status": "ok",
  "hardware_disponivel": true,
  "timestamp": "2025-07-02T10:30:00",
  "fontes": {
    "rede": {
      "tensao": 220.5,
      "estado": "ATIVA",
      "config": {
        "canal": 0,
        "nome": "Rede Elétrica",
        "cor": "#4ecdc4",
        "icone": "🏠",
        "prioridade": 1
      }
    }
  }
}
```

## ⚙️ Configuração

### Variáveis de Ambiente (.env)
```bash
DATABASE_PATH=energia.db
LOG_LEVEL=INFO
LOG_FILE=logs/energia.log
LIMIAR_TENSAO=0.8
INTERVALO_LEITURA=1.0
FLASK_HOST=0.0.0.0
FLASK_PORT=5000
WEBSOCKET_HOST=0.0.0.0
WEBSOCKET_PORT=8765
```

### Configurações do Hardware
Edite `app/config.py` para ajustar:
- Gain do ADS1115
- Taxa de amostragem
- Mapeamento de canais
- Limiares por fonte

## 🚀 Uso

### Inicialização Manual
```bash
# Execute diretamente
python app/run.py

# Ou use o script
./run.sh
```

### Serviço Systemd (Recomendado)
```bash
# Habilite inicialização automática
sudo systemctl enable poweredge
sudo systemctl start poweredge

# Verifique status
sudo systemctl status poweredge

# Monitore logs
sudo journalctl -u poweredge -f
```

### Acessos
- **Interface Web**: http://ip-raspberry:5000
- **WebSocket**: ws://ip-raspberry:8765
- **Logs**: `tail -f logs/energia.log`

## 📱 Interface Web

### Dashboard
- Overview geral do sistema
- Cards de status por fonte
- Eventos recentes
- Métricas de disponibilidade

### Fontes de Energia
- Monitoramento detalhado
- Status visual com cores
- Métricas em tempo real
- Ícones identificadores

### Histórico de Eventos
- Lista filtrada de eventos
- Busca por fonte e tipo
- Exportação para CSV
- Paginação automática

### Estatísticas
- Gráficos de disponibilidade
- Timeline de eventos
- Relatórios de uptime
- Análise de tendências

### Configurações
- Ajuste de limiares
- Configuração de notificações
- Informações do sistema
- Parâmetros de monitoramento

## 🔧 Estrutura do Projeto

```
PowerEdge/
├── app/
│   ├── run.py              # Aplicação principal
│   └── config.py           # Configurações e constantes
├── static/
│   ├── index.html          # Interface web moderna
│   ├── script.js           # JavaScript avançado (ES6+)
│   └── style.css           # Design system moderno
├── logs/                   # Arquivos de log
├── backups/                # Backups do banco
├── requirements.txt        # Dependências Python
├── setup_python.sh        # Script de configuração
├── install.sh             # Script de instalação
├── run.sh                 # Script de execução
└── README.md              # Este arquivo
```

## 🐛 Troubleshooting

### Hardware não detectado
```bash
# Verifique I2C
sudo i2cdetect -y 1

# Deve mostrar device no endereço 0x48
#      0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
# 40: -- -- -- -- -- -- -- -- 48 -- -- -- -- -- -- --
```

### WebSocket não conecta
```bash
# Verifique se a porta está aberta
netstat -tulpn | grep 8765

# Teste conexão
telnet localhost 8765
```

### Problemas de permissão
```bash
# Adicione usuário ao grupo i2c
sudo usermod -a -G i2c $USER

# Reinicie e verifique
groups
```

### Logs para debug
```bash
# Log em tempo real
tail -f logs/energia.log

# Log do serviço
sudo journalctl -u poweredge -f

# Verificar status do hardware
python -c "import board, busio; print('I2C OK')"
```

## 🎮 Ambiente Simulado e Demonstração

O PowerEdge v2.0 inclui um **sistema de simulação integrado** que permite testar e demonstrar todas as funcionalidades sem hardware físico.

### 🔄 Detecção Automática de Modo

O sistema detecta automaticamente se o hardware está disponível:

```python
# Detecção automática no código
try:
    import board, busio, adafruit_ads1x15
    HARDWARE_AVAILABLE = True
    print("✅ Hardware detectado - Modo PRODUÇÃO")
except ImportError:
    HARDWARE_AVAILABLE = False
    print("🎮 Hardware não encontrado - Modo SIMULAÇÃO")
```

### 📊 Dados Simulados Realistas

#### Valores Base por Fonte:
- 🏠 **Rede Elétrica**: 220V ± 10% (198V - 242V)
- ☀️ **Energia Solar**: 24V ± 10% (21.6V - 26.4V)  
- ⚡ **Gerador**: 12.5V ± 10% (11.25V - 13.75V)
- 🔋 **UPS/Bateria**: 12V ± 10% (10.8V - 13.2V)

#### Estados Dinâmicos:
- **ATIVA**: Tensão > limiar configurado
- **FALHA**: Tensão < limiar configurado  
- **ERRO**: Simulado raramente para testes

### 🚀 Como Executar Simulação

#### 1. Modo Simulação Automático
```bash
# Execute em qualquer sistema (Windows/Linux/Mac)
python app/run.py
# Saída: "AVISO: Hardware não disponível. Executando em modo simulação."
```

#### 2. Script de Demonstração Completa
```bash
# Demonstração interativa com todos os recursos
python demo.py

# Opções específicas
python demo.py --api-only     # Apenas testa API REST
python demo.py --ws-only      # Apenas testa WebSocket
python demo.py --host 192.168.1.100  # Teste remoto
```

#### 3. Interface Web Simulada
```bash
# Inicie o servidor
python app/run.py

# Acesse no navegador
http://localhost:5000
```

### 🎯 Recursos Disponíveis na Simulação

#### ✅ **Funcionalidades Completas:**
- Dashboard em tempo real com dados simulados
- WebSocket com atualizações automáticas (1s)
- API REST totalmente funcional
- Histórico de eventos simulados
- Exportação de dados CSV
- Sistema de notificações
- Todas as 4 fontes de energia
- Interface responsiva completa

#### 📱 **Indicadores Visuais:**
- **Status do Sistema**: "Modo Simulação" em vez de "Hardware"
- **Cards de Fonte**: Cores e ícones indicando simulação
- **Logs**: Marcação clara de dados simulados
- **API Response**: `"hardware_disponivel": false`

### 🔧 Personalização da Simulação

#### Editar Valores Base:
```python
# Em app/run.py - função simular_leitura()
base_values = {
    "rede": 127.0,      # Para sistema 127V (EUA)
    "solar": 48.0,      # Para sistema solar 48V
    "gerador": 13.8,    # Para gerador 12V carregado
    "ups": 24.0         # Para UPS industrial 24V
}
```

#### Ajustar Variabilidade:
```python
# Variação atual: ±10%
return base * (0.9 + random.random() * 0.2)

# Para ±5% (mais estável):
return base * (0.95 + random.random() * 0.1)

# Para ±20% (mais variável):
return base * (0.8 + random.random() * 0.4)
```

### 🧪 Script de Teste Avançado

O arquivo `demo.py` oferece testes automatizados:

```bash
# Teste completo do sistema
python demo.py

# Saída esperada:
🔋 PowerEdge v2.0 - Demonstração do Sistema
📊 Testando API Endpoints...
✅ GET /status - OK
✅ GET /eventos - OK  
✅ POST /eventos - OK
🔌 Testando WebSocket por 15 segundos...
✅ WebSocket conectado
📊 Dados recebidos: 3/4 fontes ativas
```

### 🌍 Casos de Uso da Simulação

#### **Desenvolvimento:**
- ✅ Desenvolver sem hardware caro
- ✅ Testar em Windows/Mac/Linux
- ✅ Debug de funcionalidades
- ✅ Validação de UI/UX

#### **Demonstração:**
- ✅ Apresentar para clientes/investidores
- ✅ Treinamento de usuários
- ✅ Validação de conceitos
- ✅ Prototipação rápida

#### **Testes:**
- ✅ Integração contínua (CI/CD)
- ✅ Teste de APIs sem hardware
- ✅ Validação de atualizações
- ✅ Teste de carga/performance

#### **Produção:**
- ✅ Fallback automático se hardware falhar
- ✅ Continuidade de serviço
- ✅ Debug remoto
- ✅ Modo de manutenção

## 📈 Melhorias Futuras

### v2.1 (Planejado)
- [ ] Gráficos interativos com Chart.js
- [ ] Alertas por email/SMS
- [ ] API de configuração dinâmica
- [ ] Backup automático do banco

### v2.2 (Planejado)
- [ ] Modo escuro
- [ ] PWA (Progressive Web App)
- [ ] Integração com Home Assistant
- [ ] Dashboard personalizado

### v3.0 (Visão)
- [ ] Machine Learning para predição
- [ ] Integração com inversor solar
- [ ] Controle automático de cargas
- [ ] App mobile nativo

## 📚 Documentação Completa

O PowerEdge inclui documentação abrangente para todos os casos de uso:

### 📖 Guias Principais
- **[INSTALLATION.md](INSTALLATION.md)** - Guia completo de instalação e configuração
- **[DEVELOPER.md](DEVELOPER.md)** - Documentação para desenvolvedores e API
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Arquitetura e separação de código
- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Deploy em produção, demonstração e desenvolvimento

### 🔧 Suporte e Troubleshooting
- **[FAQ.md](FAQ.md)** - Perguntas frequentes e soluções de problemas
- **[API.md](API.md)** - Documentação completa da API REST e WebSocket

### 🎯 Casos de Uso
- **Produção**: Raspberry Pi com hardware real → [DEPLOYMENT.md](DEPLOYMENT.md#deploy-em-produção)
- **Demonstração**: Qualquer computador → [DEPLOYMENT.md](DEPLOYMENT.md#deploy-para-demonstração)
- **Desenvolvimento**: Ambiente local → [DEVELOPER.md](DEVELOPER.md)
- **Integração**: API e WebSocket → [API.md](API.md)

### 🧪 Ambiente Simulado
O PowerEdge detecta automaticamente se está rodando em hardware real ou simulado:
- **Hardware detectado**: Modo produção com leituras reais
- **Sem hardware**: Modo simulação com dados realistas
- **Mesmo código**: Interface e funcionalidades idênticas
- **Detalhes**: Ver [ARCHITECTURE.md](ARCHITECTURE.md#separação-de-ambiente)

## 🚀 Quick Start

### Raspberry Pi (Produção)
```bash
git clone <repo-url>
cd PowerEdge
./install.sh
python app/run.py
```

### Qualquer PC (Demonstração)
```bash
git clone <repo-url>
cd PowerEdge
pip install flask flask-socketio
python app/run.py
```

Acesse: **http://localhost:5000**

## 🤝 Contribuindo

1. Fork o projeto
2. Crie uma branch para sua feature
3. Commit suas mudanças
4. Push para a branch
5. Abra um Pull Request

Consulte [DEVELOPER.md](DEVELOPER.md) para padrões de código e arquitetura.

## 📄 Licença

Este projeto está sob a licença MIT. Veja o arquivo `LICENSE` para mais detalhes.

## 👥 Suporte

- **🐛 Bugs**: Use o GitHub Issues
- **❓ Dúvidas**: Consulte [FAQ.md](FAQ.md) primeiro
- **💡 Sugestões**: GitHub Discussions
- **🔧 Problemas**: Ver [FAQ.md](FAQ.md#troubleshooting)

### Suporte por Categoria
- **Instalação**: [INSTALLATION.md](INSTALLATION.md)
- **Hardware**: [FAQ.md](FAQ.md#problemas-de-hardware)
- **API**: [API.md](API.md)
- **Deploy**: [DEPLOYMENT.md](DEPLOYMENT.md)

---

**PowerEdge v2.0** - Sistema Profissional de Monitoramento de Energia  
Desenvolvido com ❤️ para Raspberry Pi e demonstrações

📚 **Documentação completa disponível** | 🧪 **Modo simulação incluído** | 🔌 **API REST + WebSocket**
