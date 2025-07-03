# PowerEdge - Documentação da API

## 📋 Índice
- [Visão Geral](#visão-geral)
- [Autenticação](#autenticação)
- [Endpoints REST](#endpoints-rest)
- [WebSocket API](#websocket-api)
- [Modelos de Dados](#modelos-de-dados)
- [Códigos de Status](#códigos-de-status)
- [Exemplos de Uso](#exemplos-de-uso)
- [SDKs e Bibliotecas](#sdks-e-bibliotecas)

## 🎯 Visão Geral

A API do PowerEdge fornece acesso programático a todos os dados de monitoramento de energia em tempo real e histórico.

### Características
- **REST API**: Para consultas e configurações
- **WebSocket**: Para dados em tempo real
- **JSON**: Formato padrão de resposta
- **Sem autenticação**: Para uso local/interno
- **Cross-Origin**: CORS habilitado

### URLs Base
```
REST API:    http://localhost:5000/api/
WebSocket:   ws://localhost:8765/
Interface:   http://localhost:5000/
```

## 🔐 Autenticação

Atualmente **não há autenticação** - a API é aberta para uso local.

> ⚠️ **Aviso de Segurança**: Para deploy em produção com acesso externo, implemente autenticação adequada.

## 🌐 Endpoints REST

### 📊 GET /api/status
Retorna status atual de todas as fontes de energia.

**Resposta:**
```json
{
  "timestamp": "2023-12-15T10:30:00.000Z",
  "modo_simulacao": false,
  "fonte_ativa": "rede",
  "fontes": {
    "rede": {
      "nome": "Rede Elétrica",
      "tensao": 220.5,
      "disponivel": true,
      "prioridade": 1,
      "timestamp": "2023-12-15T10:30:00.000Z"
    },
    "solar": {
      "nome": "Energia Solar",
      "tensao": 165.2,
      "disponivel": true,
      "prioridade": 2,
      "timestamp": "2023-12-15T10:30:00.000Z"
    },
    "gerador": {
      "nome": "Gerador",
      "tensao": 0.0,
      "disponivel": false,
      "prioridade": 3,
      "timestamp": "2023-12-15T10:30:00.000Z"
    },
    "ups": {
      "nome": "UPS/Bateria",
      "tensao": 12.6,
      "disponivel": true,
      "prioridade": 4,
      "timestamp": "2023-12-15T10:30:00.000Z"
    }
  }
}
```

**Exemplo cURL:**
```bash
curl -X GET http://localhost:5000/api/status
```

### 📈 GET /api/eventos
Retorna histórico de eventos com paginação e filtros.

**Parâmetros Query:**
- `page` (int): Número da página (padrão: 1)
- `per_page` (int): Itens por página (padrão: 100, máx: 1000)
- `fonte` (string): Filtrar por fonte específica
- `data_inicio` (ISO date): Data de início
- `data_fim` (ISO date): Data de fim

**Resposta:**
```json
{
  "eventos": [
    {
      "id": 1,
      "fonte": "rede",
      "fonte_nome": "Rede Elétrica",
      "evento": "disponivel",
      "tensao": 220.5,
      "timestamp": "2023-12-15T10:30:00.000Z"
    },
    {
      "id": 2,
      "fonte": "solar",
      "fonte_nome": "Energia Solar", 
      "evento": "indisponivel",
      "tensao": 45.2,
      "timestamp": "2023-12-15T10:25:00.000Z"
    }
  ],
  "pagination": {
    "page": 1,
    "per_page": 100,
    "total": 2,
    "pages": 1
  }
}
```

**Exemplos cURL:**
```bash
# Todos os eventos (últimos 100)
curl -X GET http://localhost:5000/api/eventos

# Filtrar por fonte
curl -X GET "http://localhost:5000/api/eventos?fonte=rede"

# Filtrar por período
curl -X GET "http://localhost:5000/api/eventos?data_inicio=2023-12-01&data_fim=2023-12-15"

# Paginação
curl -X GET "http://localhost:5000/api/eventos?page=2&per_page=50"
```

### 📊 GET /api/estatisticas
Retorna estatísticas agregadas por período.

**Parâmetros Query:**
- `periodo` (string): "24h", "7d", "30d" (padrão: "24h")

**Resposta:**
```json
{
  "periodo": "24h",
  "timestamp": "2023-12-15T10:30:00.000Z",
  "estatisticas": {
    "rede": {
      "nome": "Rede Elétrica",
      "disponibilidade": 95.5,
      "tempo_ativo": "22h 55m",
      "tempo_inativo": "1h 5m",
      "tensao_media": 220.2,
      "tensao_min": 215.1,
      "tensao_max": 225.8,
      "total_eventos": 12
    },
    "solar": {
      "nome": "Energia Solar",
      "disponibilidade": 78.3,
      "tempo_ativo": "18h 47m",
      "tempo_inativo": "5h 13m",
      "tensao_media": 172.4,
      "tensao_min": 145.0,
      "tensao_max": 195.2,
      "total_eventos": 8
    }
  }
}
```

**Exemplo cURL:**
```bash
curl -X GET "http://localhost:5000/api/estatisticas?periodo=7d"
```

### ⚙️ GET /api/configuracao
Retorna configuração atual do sistema.

**Resposta:**
```json
{
  "modo_simulacao": false,
  "intervalo_leitura": 2.0,
  "configuracao_fontes": {
    "rede": {
      "nome": "Rede Elétrica",
      "threshold": 200.0,
      "prioridade": 1
    },
    "solar": {
      "nome": "Energia Solar",
      "threshold": 150.0,
      "prioridade": 2
    },
    "gerador": {
      "nome": "Gerador",
      "threshold": 200.0,
      "prioridade": 3
    },
    "ups": {
      "nome": "UPS/Bateria",
      "threshold": 11.0,
      "prioridade": 4
    }
  }
}
```

### 📥 POST /api/configuracao
Atualiza configuração do sistema.

**Body (JSON):**
```json
{
  "intervalo_leitura": 5.0,
  "configuracao_fontes": {
    "rede": {
      "threshold": 210.0
    }
  }
}
```

**Resposta:**
```json
{
  "status": "success",
  "message": "Configuração atualizada com sucesso",
  "configuracao_atualizada": {
    "intervalo_leitura": 5.0,
    "configuracao_fontes": {
      "rede": {
        "nome": "Rede Elétrica",
        "threshold": 210.0,
        "prioridade": 1
      }
    }
  }
}
```

### 📤 GET /api/exportar
Exporta dados em formato CSV.

**Parâmetros Query:**
- `formato` (string): "csv" (padrão)
- `data_inicio` (ISO date): Data de início
- `data_fim` (ISO date): Data de fim
- `fontes` (string): Lista separada por vírgula

**Resposta:**
```csv
timestamp,fonte,fonte_nome,evento,tensao
2023-12-15T10:30:00.000Z,rede,Rede Elétrica,disponivel,220.5
2023-12-15T10:25:00.000Z,solar,Energia Solar,indisponivel,45.2
```

**Exemplo cURL:**
```bash
curl -X GET "http://localhost:5000/api/exportar?fontes=rede,solar&data_inicio=2023-12-01" -o dados.csv
```

### ❤️ GET /api/health
Endpoint de saúde para monitoramento.

**Resposta:**
```json
{
  "status": "healthy",
  "timestamp": "2023-12-15T10:30:00.000Z",
  "uptime": "2h 15m 30s",
  "modo_simulacao": false,
  "versao": "2.0.0",
  "hardware_detectado": true,
  "banco_dados": "ok",
  "websocket": "ok"
}
```

## 🔌 WebSocket API

### Conexão
```javascript
const socket = new WebSocket('ws://localhost:8765');
```

### Eventos Recebidos

#### `dados_energia`
Dados em tempo real de todas as fontes.

```json
{
  "tipo": "dados_energia",
  "timestamp": "2023-12-15T10:30:00.000Z",
  "dados": {
    "rede": {
      "tensao": 220.5,
      "disponivel": true,
      "timestamp": "2023-12-15T10:30:00.000Z"
    },
    "solar": {
      "tensao": 165.2,
      "disponivel": true,
      "timestamp": "2023-12-15T10:30:00.000Z"
    },
    "gerador": {
      "tensao": 0.0,
      "disponivel": false,
      "timestamp": "2023-12-15T10:30:00.000Z"
    },
    "ups": {
      "tensao": 12.6,
      "disponivel": true,
      "timestamp": "2023-12-15T10:30:00.000Z"
    }
  },
  "fonte_ativa": "rede"
}
```

#### `mudanca_fonte`
Notificação de mudança da fonte ativa.

```json
{
  "tipo": "mudanca_fonte",
  "timestamp": "2023-12-15T10:30:00.000Z",
  "fonte_anterior": "rede",
  "fonte_nova": "solar",
  "motivo": "rede_indisponivel"
}
```

#### `alerta`
Alertas e notificações importantes.

```json
{
  "tipo": "alerta",
  "timestamp": "2023-12-15T10:30:00.000Z",
  "nivel": "warning",
  "titulo": "Fonte Indisponível",
  "mensagem": "Rede Elétrica ficou indisponível",
  "fonte": "rede"
}
```

### Exemplo JavaScript Cliente
```javascript
const socket = new WebSocket('ws://localhost:8765');

socket.onopen = function(event) {
    console.log('WebSocket conectado');
};

socket.onmessage = function(event) {
    const data = JSON.parse(event.data);
    
    switch(data.tipo) {
        case 'dados_energia':
            atualizarInterface(data.dados);
            break;
        case 'mudanca_fonte':
            mostrarNotificacao(`Mudou para: ${data.fonte_nova}`);
            break;
        case 'alerta':
            mostrarAlerta(data.nivel, data.mensagem);
            break;
    }
};

socket.onerror = function(error) {
    console.error('Erro WebSocket:', error);
};

socket.onclose = function(event) {
    console.log('WebSocket desconectado');
    // Implementar reconexão automática
    setTimeout(() => {
        conectarWebSocket();
    }, 5000);
};
```

## 📊 Modelos de Dados

### Fonte de Energia
```typescript
interface FonteEnergia {
  nome: string;           // Nome amigável
  tensao: number;         // Tensão atual em Volts
  disponivel: boolean;    // Se está disponível
  prioridade: number;     // Prioridade (1 = maior)
  threshold: number;      // Limite mínimo de tensão
  timestamp: string;      // ISO 8601 timestamp
}
```

### Evento
```typescript
interface Evento {
  id: number;            // ID único
  fonte: string;         // Chave da fonte (rede, solar, etc)
  fonte_nome: string;    // Nome amigável da fonte
  evento: string;        // Tipo: 'disponivel' | 'indisponivel'
  tensao: number;        // Tensão no momento do evento
  timestamp: string;     // ISO 8601 timestamp
}
```

### Status do Sistema
```typescript
interface StatusSistema {
  timestamp: string;           // Timestamp da consulta
  modo_simulacao: boolean;     // Se está em modo simulação
  fonte_ativa: string;         // Fonte atualmente ativa
  fontes: {                    // Status de todas as fontes
    [key: string]: FonteEnergia;
  };
}
```

## 📋 Códigos de Status

### Códigos HTTP
- `200 OK` - Sucesso
- `400 Bad Request` - Parâmetros inválidos
- `404 Not Found` - Recurso não encontrado
- `500 Internal Server Error` - Erro interno

### Códigos de Evento WebSocket
- `dados_energia` - Dados em tempo real
- `mudanca_fonte` - Mudança de fonte ativa
- `alerta` - Notificação importante
- `sistema` - Mensagens do sistema

### Níveis de Alerta
- `info` - Informação
- `warning` - Aviso
- `error` - Erro
- `critical` - Crítico

## 💡 Exemplos de Uso

### 🐍 Python Client
```python
import requests
import json
import websocket

class PowerEdgeClient:
    def __init__(self, base_url="http://localhost:5000"):
        self.base_url = base_url
        
    def get_status(self):
        """Obtém status atual."""
        response = requests.get(f"{self.base_url}/api/status")
        return response.json()
    
    def get_eventos(self, fonte=None, page=1, per_page=100):
        """Obtém histórico de eventos."""
        params = {'page': page, 'per_page': per_page}
        if fonte:
            params['fonte'] = fonte
            
        response = requests.get(f"{self.base_url}/api/eventos", params=params)
        return response.json()
    
    def get_estatisticas(self, periodo="24h"):
        """Obtém estatísticas."""
        response = requests.get(f"{self.base_url}/api/estatisticas", 
                              params={'periodo': periodo})
        return response.json()

# Uso
client = PowerEdgeClient()
status = client.get_status()
print(f"Fonte ativa: {status['fonte_ativa']}")

# WebSocket
def on_message(ws, message):
    data = json.loads(message)
    if data['tipo'] == 'dados_energia':
        print(f"Rede: {data['dados']['rede']['tensao']}V")

ws = websocket.WebSocketApp("ws://localhost:8765",
                           on_message=on_message)
ws.run_forever()
```

### 🟨 JavaScript/Node.js Client
```javascript
const axios = require('axios');
const WebSocket = require('ws');

class PowerEdgeClient {
    constructor(baseUrl = 'http://localhost:5000') {
        this.baseUrl = baseUrl;
    }
    
    async getStatus() {
        const response = await axios.get(`${this.baseUrl}/api/status`);
        return response.data;
    }
    
    async getEventos(fonte = null, page = 1, perPage = 100) {
        const params = { page, per_page: perPage };
        if (fonte) params.fonte = fonte;
        
        const response = await axios.get(`${this.baseUrl}/api/eventos`, { params });
        return response.data;
    }
    
    connectWebSocket() {
        const ws = new WebSocket('ws://localhost:8765');
        
        ws.on('message', (data) => {
            const message = JSON.parse(data);
            console.log('Received:', message.tipo);
        });
        
        return ws;
    }
}

// Uso
const client = new PowerEdgeClient();

(async () => {
    const status = await client.getStatus();
    console.log(`Fonte ativa: ${status.fonte_ativa}`);
    
    const ws = client.connectWebSocket();
})();
```

### 🦀 Rust Client
```rust
use reqwest;
use serde_json::Value;
use tokio_tungstenite::{connect_async, tungstenite::Message};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // REST API
    let client = reqwest::Client::new();
    let response = client
        .get("http://localhost:5000/api/status")
        .send()
        .await?;
    
    let status: Value = response.json().await?;
    println!("Fonte ativa: {}", status["fonte_ativa"]);
    
    // WebSocket
    let (ws_stream, _) = connect_async("ws://localhost:8765").await?;
    // ... processar mensagens
    
    Ok(())
}
```

## 📚 SDKs e Bibliotecas

### Bibliotecas Recomendadas

#### Python
```bash
pip install requests websocket-client
```

#### JavaScript/Node.js
```bash
npm install axios ws
```

#### Go
```bash
go get github.com/gorilla/websocket
```

#### Rust
```toml
[dependencies]
reqwest = { version = "0.11", features = ["json"] }
tokio-tungstenite = "0.20"
```

### Ferramentas de Teste

#### cURL Examples
```bash
# Status rápido
curl -s http://localhost:5000/api/status | jq .fonte_ativa

# Últimos 10 eventos
curl -s "http://localhost:5000/api/eventos?per_page=10" | jq .eventos

# Exportar dados do último mês
curl "http://localhost:5000/api/exportar?data_inicio=2023-11-01" -o dados.csv
```

#### WebSocket Test (wscat)
```bash
npm install -g wscat
wscat -c ws://localhost:8765
```

---

**PowerEdge API Documentation v2.0** - API completa para integração e desenvolvimento.
