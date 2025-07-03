# PowerEdge - Guia de Arquitetura e Separação de Código

## 📋 Índice
- [Visão Geral](#visão-geral)
- [Separação de Ambiente](#separação-de-ambiente)
- [Estrutura do Projeto](#estrutura-do-projeto)
- [Detecção Automática de Hardware](#detecção-automática-de-hardware)
- [Código de Simulação vs Produção](#código-de-simulação-vs-produção)
- [Fluxo de Execução](#fluxo-de-execução)
- [Configurações por Ambiente](#configurações-por-ambiente)
- [Testes e Desenvolvimento](#testes-e-desenvolvimento)

## 🎯 Visão Geral

O PowerEdge foi projetado com **arquitetura híbrida** que permite execução tanto em **ambiente de produção** (Raspberry Pi com hardware real) quanto em **ambiente de simulação** (qualquer computador para demonstração).

### Principais Características
- **Detecção Automática**: O sistema detecta automaticamente se está rodando em hardware real ou simulado
- **Código Unificado**: O mesmo código base serve para produção e demonstração
- **Separação Clara**: Funções específicas claramente identificadas para cada ambiente
- **Fallback Inteligente**: Se hardware não disponível, ativa automaticamente modo simulado

## 🔄 Separação de Ambiente

### 🏭 Ambiente de Produção
**Quando usar**: Raspberry Pi com hardware ADS1115 conectado
```
Hardware Detectado: ✅ ADS1115 disponível
Modo: PRODUÇÃO
Dados: Leituras reais dos sensores
```

### 🧪 Ambiente de Simulação
**Quando usar**: Desenvolvimento, demonstração, testes
```
Hardware Detectado: ❌ ADS1115 não disponível
Modo: SIMULAÇÃO
Dados: Valores simulados realistas
```

## 📁 Estrutura do Projeto

```
PowerEdge/
├── app/                    # Código principal
│   ├── run.py             # Aplicação principal (híbrida)
│   └── config.py          # Configurações (híbrida)
├── static/                # Interface web
│   ├── index.html         # Interface unificada
│   ├── style.css          # Estilos modernos
│   └── script.js          # JavaScript para ambos ambientes
├── demo.py                # Script de demonstração pura
├── requirements.txt       # Dependências para ambos ambientes
├── setup_python.sh        # Setup do ambiente Python
├── install.sh            # Instalação completa (produção)
├── run.sh / run.bat      # Scripts de execução
└── docs/                 # Documentação
    ├── INSTALLATION.md   # Guia de instalação
    ├── DEVELOPER.md      # Guia do desenvolvedor
    └── ARCHITECTURE.md   # Este arquivo
```

## 🔍 Detecção Automática de Hardware

### Localização: `app/config.py`

```python
def detectar_hardware():
    """
    Detecta automaticamente se o hardware ADS1115 está disponível.
    
    Returns:
        bool: True se ADS1115 disponível (PRODUÇÃO)
              False se não disponível (SIMULAÇÃO)
    """
    try:
        import board
        import busio
        import adafruit_ads1x15.ads1115 as ADS
        from adafruit_ads1x15.analog_in import AnalogIn
        
        # Tenta criar instância do ADS1115
        i2c = busio.I2C(board.SCL, board.SDA)
        ads = ADS.ADS1115(i2c)
        
        # Teste rápido de leitura
        chan = AnalogIn(ads, ADS.P0)
        _ = chan.voltage
        
        return True  # Hardware detectado - MODO PRODUÇÃO
        
    except Exception as e:
        print(f"Hardware ADS1115 não detectado: {e}")
        return False  # Hardware não detectado - MODO SIMULAÇÃO
```

### Como Funciona
1. **Tentativa de Import**: Importa bibliotecas específicas do hardware
2. **Criação de Instância**: Tenta criar objeto ADS1115
3. **Teste de Leitura**: Executa leitura rápida para validar hardware
4. **Resultado**: `True` = Produção, `False` = Simulação

## 💾 Código de Simulação vs Produção

### 🏭 Código de Produção

#### Localização: `app/run.py` - Função `ler_energia_real()`
```python
def ler_energia_real():
    """
    Lê dados reais dos sensores conectados ao ADS1115.
    
    AMBIENTE: PRODUÇÃO APENAS
    Hardware: Raspberry Pi + ADS1115
    """
    global ads, canais_adc
    
    try:
        fontes = {}
        for fonte, canal in canais_adc.items():
            # Leitura real do hardware
            tensao = canal.voltage
            disponivel = tensao > CONFIGURACAO[fonte]['threshold']
            
            fontes[fonte] = {
                'tensao': round(tensao, 2),
                'disponivel': disponivel,
                'timestamp': datetime.now().isoformat()
            }
            
        return fontes
        
    except Exception as e:
        logger.error(f"Erro lendo sensores reais: {e}")
        return None
```

**Características do Código de Produção:**
- ✅ Acessa hardware real (ADS1115)
- ✅ Leituras diretas dos sensores
- ✅ Tratamento de erros de hardware
- ✅ Valores precisos e reais

### 🧪 Código de Simulação

#### Localização: `app/run.py` - Função `simular_leitura()`
```python
def simular_leitura():
    """
    Simula leituras de energia para demonstração e desenvolvimento.
    
    AMBIENTE: SIMULAÇÃO APENAS
    Hardware: Qualquer computador (sem hardware específico)
    """
    import random
    import time
    
    # Base de valores realistas por fonte
    valores_base = {
        'rede': {'base': 220.0, 'variacao': 10.0, 'disponibilidade': 0.85},
        'solar': {'base': 180.0, 'variacao': 30.0, 'disponibilidade': 0.70},
        'gerador': {'base': 240.0, 'variacao': 15.0, 'disponibilidade': 0.60},
        'ups': {'base': 12.6, 'variacao': 2.0, 'disponibilidade': 0.90}
    }
    
    fontes = {}
    for fonte, config in valores_base.items():
        # Simula disponibilidade baseada em probabilidade
        disponivel = random.random() < config['disponibilidade']
        
        if disponivel:
            # Gera tensão com variação realista
            tensao = config['base'] + random.uniform(
                -config['variacao'], config['variacao']
            )
        else:
            # Fonte indisponível = tensão baixa
            tensao = random.uniform(0, 50)
        
        fontes[fonte] = {
            'tensao': round(tensao, 2),
            'disponivel': tensao > CONFIGURACAO[fonte]['threshold'],
            'timestamp': datetime.now().isoformat()
        }
    
    return fontes
```

**Características do Código de Simulação:**
- ✅ Não precisa de hardware específico
- ✅ Valores realistas e variáveis
- ✅ Simula falhas e flutuações
- ✅ Baseado em probabilidades

### 🔄 Função Híbrida - Seleção Automática

#### Localização: `app/run.py` - Função `ler_energia()`
```python
def ler_energia():
    """
    Função híbrida que seleciona automaticamente entre 
    leitura real ou simulada baseado no hardware detectado.
    
    AMBIENTE: HÍBRIDO (Produção + Simulação)
    """
    if MODO_SIMULACAO:
        return simular_leitura()  # Hardware não disponível
    else:
        return ler_energia_real()  # Hardware disponível
```

## 🔄 Fluxo de Execução

### 1. Inicialização
```
app/run.py START
    ↓
detectar_hardware()
    ↓
MODO_SIMULACAO = True/False
    ↓
Inicializar Flask + WebSocket
```

### 2. Monitoramento Contínuo
```
Loop Principal:
    ↓
ler_energia()
    ↓
if MODO_SIMULACAO:
    simular_leitura()
else:
    ler_energia_real()
    ↓
Processar dados
    ↓
Salvar no banco
    ↓
Enviar via WebSocket
```

### 3. Interface Web
```
Frontend (static/):
    ↓
Conecta WebSocket
    ↓
Recebe dados (real ou simulado)
    ↓
Atualiza interface
    ↓
Usuário vê mesma interface
```

## ⚙️ Configurações por Ambiente

### Arquivo: `app/config.py`

```python
# Configurações compartilhadas (ambos ambientes)
CONFIGURACAO = {
    'rede': {
        'nome': 'Rede Elétrica',
        'threshold': 200.0,      # V
        'prioridade': 1
    },
    'solar': {
        'nome': 'Energia Solar',
        'threshold': 150.0,      # V
        'prioridade': 2
    },
    'gerador': {
        'nome': 'Gerador',
        'threshold': 200.0,      # V
        'prioridade': 3
    },
    'ups': {
        'nome': 'UPS/Bateria',
        'threshold': 11.0,       # V (12V nominal)
        'prioridade': 4
    }
}

# Configurações específicas de produção
if not MODO_SIMULACAO:
    # Configurações do ADS1115
    GANHO_ADC = 1
    TAXA_AMOSTRAGEM = 860
    
# Configurações específicas de simulação
if MODO_SIMULACAO:
    # Parâmetros de simulação
    INTERVALO_SIMULACAO = 2.0  # segundos
    VARIACAO_MAXIMA = 0.3      # 30%
```

## 🧪 Testes e Desenvolvimento

### Script de Demonstração: `demo.py`
```python
"""
Script dedicado APENAS para demonstração e testes.
NÃO é usado em produção.

Testa:
- API REST
- WebSocket
- Exportação de dados
- Funcionalidades da interface
"""
```

**Uso:**
```bash
# Executar demonstração
python demo.py
```

### Scripts de Execução

#### Produção (Linux): `run.sh`
```bash
#!/bin/bash
# Script para ambiente de produção
cd "$(dirname "$0")"
python app/run.py
```

#### Desenvolvimento (Windows): `run.bat`
```cmd
@echo off
cd /d "%~dp0"
python app/run.py
```

## 📝 Identificação de Código por Seção

### 🏭 Código EXCLUSIVO de Produção
- `ler_energia_real()` - Leitura de hardware real
- Imports específicos (board, busio, adafruit_ads1x15)
- Configuração de pinos I2C
- Tratamento de erros de hardware

### 🧪 Código EXCLUSIVO de Simulação
- `simular_leitura()` - Geração de dados simulados
- Valores base para simulação
- Algoritmos de variação aleatória
- Simulação de falhas

### 🔄 Código HÍBRIDO (Ambos)
- `ler_energia()` - Seletor automático
- Interface web completa (`static/`)
- API REST e WebSocket
- Banco de dados e logging
- Configurações gerais

### 🛠️ Código de SETUP/UTILITÁRIOS
- `setup_python.sh` - Configuração do ambiente
- `install.sh` - Instalação completa
- `demo.py` - Demonstração pura
- Scripts de execução

## 🎯 Resumo para Desenvolvedores

### ✅ Como Identificar o Ambiente
1. **Variável Global**: `MODO_SIMULACAO` (True/False)
2. **Log de Inicialização**: Mostra "Modo simulação ativado" ou "Hardware detectado"
3. **Teste Manual**: Verificar se `import board` funciona

### ✅ Como Adicionar Código Específico
```python
# Para código específico de produção
if not MODO_SIMULACAO:
    # Código que precisa de hardware real

# Para código específico de simulação  
if MODO_SIMULACAO:
    # Código que simula funcionalidade

# Para código híbrido
# Use as funções existentes que já fazem a seleção
```

### ✅ Como Testar Ambos Ambientes
```bash
# Testar simulação (qualquer computador)
python app/run.py

# Testar produção (só no Raspberry Pi)
# Hardware será detectado automaticamente
python app/run.py
```

---

**Arquitetura PowerEdge v2.0** - Sistema híbrido inteligente para produção e desenvolvimento.
