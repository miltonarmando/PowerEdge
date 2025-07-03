import asyncio
import threading
import json
import logging
import os
import random
import time
from contextlib import contextmanager
from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS
import websockets
import sqlite3
from datetime import datetime, timedelta
try:
    import board
    import busio
    import adafruit_ads1x15.ads1115 as ADS
    from adafruit_ads1x15.analog_in import AnalogIn
    HARDWARE_AVAILABLE = True
except ImportError:
    HARDWARE_AVAILABLE = False
    print("AVISO: Hardware não disponível. Executando em modo simulação.")

from config import *

# Configuração de logging
logging.basicConfig(
    level=getattr(logging, LOG_LEVEL),
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Configurar caminhos
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STATIC_DIR = os.path.join(BASE_DIR, 'static')

app = Flask(__name__, static_folder=STATIC_DIR, static_url_path='/static')
CORS(app)

# Inicialização do hardware (se disponível)
if HARDWARE_AVAILABLE:
    try:
        i2c = busio.I2C(board.SCL, board.SDA)
        ads = ADS.ADS1115(i2c, gain=ADS_GAIN, data_rate=ADS_DATA_RATE)
        
        fontes = {}
        for nome, config in FONTES_CONFIG.items():
            fontes[nome] = AnalogIn(ads, getattr(ADS, f'P{config["canal"]}'))
        
        logger.info("Hardware inicializado com sucesso")
    except Exception as e:
        logger.error(f"Erro ao inicializar hardware: {e}")
        HARDWARE_AVAILABLE = False
        fontes = {}
else:
    fontes = {}

estado_anterior = {nome: "ATIVA" for nome in FONTES_CONFIG.keys()}
LIMIAR = LIMIAR_TENSAO

# Variáveis para simulação avançada
simulacao_iniciada = datetime.now()
cenarios_simulacao = {
    'rede': {'ultimo_evento': datetime.now(), 'estado_forcado': None, 'duracao_evento': 0},
    'solar': {'ultimo_evento': datetime.now(), 'estado_forcado': None, 'duracao_evento': 0},
    'gerador': {'ultimo_evento': datetime.now(), 'estado_forcado': None, 'duracao_evento': 0},
    'ups': {'ultimo_evento': datetime.now(), 'estado_forcado': None, 'duracao_evento': 0}
}

# Contexto manager para conexão segura com SQLite
@contextmanager
def get_db_connection():
    conn = None
    try:
        conn = sqlite3.connect(DATABASE_PATH, timeout=10.0)
        conn.row_factory = sqlite3.Row
        yield conn
    except sqlite3.Error as e:
        logger.error(f"Erro no banco de dados: {e}")
        if conn:
            conn.rollback()
        raise
    finally:
        if conn:
            conn.close()

def determinar_estado_fonte(fonte, tensao):
    """Determina o estado de uma fonte baseado na tensão e tipo"""
    try:
        config = FONTES_CONFIG.get(fonte, {})
        threshold = config.get('threshold', 100.0)
        
        # Obter percentual de instabilidade configurado (padrão 70%)
        percentual_instabilidade = get_config_value('percentual_instabilidade', 70)
        limiar_instabilidade = threshold * (percentual_instabilidade / 100.0)
        
        if tensao >= threshold:
            return 'ATIVA'
        elif tensao >= limiar_instabilidade:
            return 'INSTAVEL'
        else:
            return 'FALHA'
    except:
        return 'ERRO'

# Alias para compatibilidade
def get_db():
    return get_db_connection()

# Inicialização do banco de dados
def init_database():
    try:
        with get_db_connection() as conn:
            # Tabela de eventos
            conn.execute("""
                CREATE TABLE IF NOT EXISTS eventos (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    fonte TEXT NOT NULL,
                    tipo TEXT NOT NULL,
                    tensao REAL,
                    data_hora TEXT NOT NULL,
                    UNIQUE(fonte, tipo, data_hora)
                )
            """)
            
            # Tabela de configurações persistentes
            conn.execute("""
                CREATE TABLE IF NOT EXISTS configuracoes (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    chave TEXT UNIQUE NOT NULL,
                    valor TEXT NOT NULL,
                    tipo TEXT DEFAULT 'string',
                    data_alteracao TEXT NOT NULL,
                    usuario TEXT DEFAULT 'sistema'
                )
            """)
            
            conn.execute("""
                CREATE INDEX IF NOT EXISTS idx_eventos_data_hora 
                ON eventos(data_hora DESC)
            """)
            
            conn.execute("""
                CREATE INDEX IF NOT EXISTS idx_configuracoes_chave 
                ON configuracoes(chave)
            """)
            
            conn.commit()
            logger.info("Banco de dados inicializado")
            
            # Inicializar configurações padrão se não existirem
            init_default_configurations(conn)
            
    except Exception as e:
        logger.error(f"Erro ao inicializar banco: {e}")

def init_default_configurations(conn):
    """Inicializa configurações padrão no banco se não existirem"""
    try:
        import json
        
        default_configs = {
            'intervalo_leitura': {'valor': str(INTERVALO_LEITURA), 'tipo': 'float'},
            'limiar_tensao_global': {'valor': '0.8', 'tipo': 'float'},
            'notificacoes_ativadas': {'valor': 'true', 'tipo': 'boolean'},
            'modo_debug': {'valor': 'false', 'tipo': 'boolean'},
            'thresholds_fontes': {'valor': json.dumps({
                'rede': FONTES_CONFIG['rede']['threshold'],
                'solar': FONTES_CONFIG['solar']['threshold'],
                'gerador': FONTES_CONFIG['gerador']['threshold'],
                'ups': FONTES_CONFIG['ups']['threshold']
            }), 'tipo': 'json'}
        }
        
        for chave, config in default_configs.items():
            conn.execute("""
                INSERT OR IGNORE INTO configuracoes (chave, valor, tipo, data_alteracao)
                VALUES (?, ?, ?, ?)
            """, (chave, config['valor'], config['tipo'], datetime.now().isoformat()))
        
        conn.commit()
        logger.info("Configurações padrão inicializadas")
        
    except Exception as e:
        logger.error(f"Erro ao inicializar configurações padrão: {e}")

def get_config_value(chave, default=None):
    """Obtém valor de configuração do banco de dados"""
    try:
        with get_db_connection() as conn:
            cursor = conn.execute(
                "SELECT valor, tipo FROM configuracoes WHERE chave = ?",
                (chave,)
            )
            row = cursor.fetchone()
            
            if row:
                valor, tipo = row
                
                # Converter para o tipo apropriado
                if tipo == 'float':
                    return float(valor)
                elif tipo == 'int':
                    return int(valor)
                elif tipo == 'boolean':
                    return valor.lower() in ('true', '1', 'yes')
                elif tipo == 'json':
                    import json
                    return json.loads(valor)
                else:
                    return valor
            
            return default
            
    except Exception as e:
        logger.error(f"Erro ao obter configuração {chave}: {e}")
        return default

def set_config_value(chave, valor, tipo='string', usuario='web'):
    """Define valor de configuração no banco de dados"""
    try:
        import json
        
        # Converter valor para string conforme o tipo
        if tipo == 'json':
            valor_str = json.dumps(valor)
        else:
            valor_str = str(valor)
            
        with get_db_connection() as conn:
            conn.execute("""
                INSERT OR REPLACE INTO configuracoes (chave, valor, tipo, data_alteracao, usuario)
                VALUES (?, ?, ?, ?, ?)
            """, (chave, valor_str, tipo, datetime.now().isoformat(), usuario))
            
            conn.commit()
            
        logger.info(f"Configuração {chave} atualizada para {valor} por {usuario}")
        return True
        
    except Exception as e:
        logger.error(f"Erro ao definir configuração {chave}: {e}")
        return False

def registrar_evento(fonte, tipo, tensao=None):
    try:
        agora = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        with get_db_connection() as conn:
            conn.execute(
                "INSERT OR IGNORE INTO eventos (fonte, tipo, tensao, data_hora) VALUES (?, ?, ?, ?)", 
                (fonte, tipo, tensao, agora)
            )
            conn.commit()
        logger.info(f"[{agora}] {fonte.upper()} - {tipo} - {tensao}V")
    except Exception as e:
        logger.error(f"Erro ao registrar evento: {e}")

def simular_leitura_avancada(nome):
    """
    Simulação avançada com cenários realistas de quedas de energia,
    flutuações e comportamentos dinâmicos baseados no tipo de fonte.
    """
    global cenarios_simulacao
    
    agora = datetime.now()
    cenario = cenarios_simulacao[nome]
    
    # Configurações específicas por fonte
    configs = {
        'rede': {
            'tensao_nominal': 220.0,
            'variacao_normal': 8.0,  # ±8V variação normal
            'prob_queda': 0.003,     # 0.3% chance de queda por leitura
            'duracao_queda_min': 5,  # 5 segundos mínimo
            'duracao_queda_max': 120, # 2 minutos máximo
            'tensao_queda': lambda: random.uniform(0, 50),  # Tensão durante queda
            'recuperacao_gradual': True
        },
        'solar': {
            'tensao_nominal': 180.0,
            'variacao_normal': 25.0,  # ±25V (dependente do sol)
            'prob_queda': 0.008,      # 0.8% chance de "nuvem" ou problema
            'duracao_queda_min': 10,
            'duracao_queda_max': 300, # 5 minutos
            'tensao_queda': lambda: random.uniform(20, 80),  # Redução parcial
            'recuperacao_gradual': True,
            'comportamento_hora': True  # Varia conforme hora do dia
        },
        'gerador': {
            'tensao_nominal': 240.0,
            'variacao_normal': 12.0,
            'prob_queda': 0.005,      # 0.5% chance de falha
            'duracao_queda_min': 3,
            'duracao_queda_max': 60,
            'tensao_queda': lambda: random.uniform(0, 30),  # Falha mais severa
            'recuperacao_gradual': False  # Liga/desliga mais abrupto
        },
        'ups': {
            'tensao_nominal': 12.6,   # Bateria 12V nominal
            'variacao_normal': 0.8,   # ±0.8V
            'prob_queda': 0.001,      # 0.1% chance de falha
            'duracao_queda_min': 2,
            'duracao_queda_max': 30,
            'tensao_queda': lambda: random.uniform(9.5, 11.0),  # Bateria baixa
            'recuperacao_gradual': True,
            'descarga_gradual': True  # Simula descarga da bateria
        }
    }
    
    config = configs[nome]
    
    # Verificar se há evento forçado em andamento
    if cenario['estado_forcado'] is not None:
        tempo_evento = (agora - cenario['ultimo_evento']).total_seconds()
        
        if tempo_evento >= cenario['duracao_evento']:
            # Finalizar evento
            cenario['estado_forcado'] = None
            logger.info(f"[SIMULAÇÃO] {nome}: Evento finalizado após {tempo_evento:.1f}s")
        else:
            # Continuar evento
            if cenario['estado_forcado'] == 'FALHA':
                tensao = config['tensao_queda']()
                # Adicionar variação pequena durante a falha
                tensao += random.uniform(-5, 5)
                return max(0, tensao)
    
    # Verificar se deve iniciar novo evento
    if cenario['estado_forcado'] is None and random.random() < config['prob_queda']:
        # Iniciar evento de queda
        cenario['estado_forcado'] = 'FALHA'
        cenario['ultimo_evento'] = agora
        cenario['duracao_evento'] = random.randint(
            config['duracao_queda_min'], 
            config['duracao_queda_max']
        )
        
        tensao = config['tensao_queda']()
        logger.warning(f"[SIMULAÇÃO] {nome}: Iniciando falha - {tensao:.1f}V por {cenario['duracao_evento']}s")
        return tensao
    
    # Operação normal - calcular tensão baseada no tipo de fonte
    tensao_base = config['tensao_nominal']
    
    # Comportamentos especiais
    if nome == 'solar' and config.get('comportamento_hora', False):
        # Simular variação solar baseada na hora
        hora = agora.hour
        if 6 <= hora <= 18:  # Período diurno
            fator_sol = 0.3 + 0.7 * (1 - abs(hora - 12) / 6)  # Pico ao meio-dia
            tensao_base *= fator_sol
        else:  # Período noturno
            tensao_base *= 0.1  # Solar quase zero à noite
    
    elif nome == 'ups' and config.get('descarga_gradual', False):
        # Simular descarga gradual da bateria (muito lenta)
        tempo_desde_inicio = (agora - simulacao_iniciada).total_seconds()
        fator_descarga = max(0.85, 1 - (tempo_desde_inicio / 86400))  # 15% em 24h
        tensao_base *= fator_descarga
    
    # Adicionar variação normal
    variacao = random.uniform(-config['variacao_normal'], config['variacao_normal'])
    tensao_final = tensao_base + variacao
    
    # Garantir valores mínimos realistas
    tensao_final = max(0, tensao_final)
    
    return tensao_final

def simular_leitura(nome):
    """Wrapper para compatibilidade - usa simulação avançada"""
    return simular_leitura_avancada(nome)

async def enviar_dados(websocket, path):
    logger.info(f"Nova conexão WebSocket: {websocket.remote_address}")
    try:
        while True:
            dados = {}
            for nome in FONTES_CONFIG.keys():
                try:
                    if HARDWARE_AVAILABLE and nome in fontes:
                        tensao = fontes[nome].voltage
                    else:
                        tensao = simular_leitura(nome)
                    
                    estado = determinar_estado_fonte(nome, tensao)

                    if estado != estado_anterior[nome]:
                        registrar_evento(nome, estado, tensao)
                        estado_anterior[nome] = estado

                    dados[nome] = {
                        "tensao": round(tensao, 2), 
                        "estado": estado,
                        "timestamp": datetime.now().isoformat()
                    }
                except Exception as e:
                    logger.error(f"Erro ao ler {nome}: {e}")
                    dados[nome] = {
                        "tensao": 0.0, 
                        "estado": "ERRO",
                        "timestamp": datetime.now().isoformat()
                    }

            await websocket.send(json.dumps(dados))
            await asyncio.sleep(INTERVALO_LEITURA)
    except websockets.exceptions.ConnectionClosed:
        logger.info("Conexão WebSocket fechada")
    except Exception as e:
        logger.error(f"Erro no WebSocket: {e}")

def iniciar_websocket():
    try:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        start_server = websockets.serve(enviar_dados, WEBSOCKET_HOST, WEBSOCKET_PORT)
        logger.info(f"WebSocket servidor iniciado em {WEBSOCKET_HOST}:{WEBSOCKET_PORT}")
        loop.run_until_complete(start_server)
        loop.run_forever()
    except Exception as e:
        logger.error(f"Erro ao iniciar WebSocket: {e}")

@app.route("/")
def index():
    return send_from_directory(STATIC_DIR, 'index.html')

@app.route("/test-notifications")
def test_notifications():
    return send_from_directory(BASE_DIR, 'test_notifications.html')

@app.route("/status", methods=["GET"])
def status():
    try:
        logger.info("=== INÍCIO /status ===")
        logger.info(f"FONTES_CONFIG.keys(): {list(FONTES_CONFIG.keys())}")
        logger.info(f"HARDWARE_AVAILABLE: {HARDWARE_AVAILABLE}")
        
        dados = {}
        for nome in FONTES_CONFIG.keys():
            logger.info(f"Processando fonte: {nome}")
            
            if HARDWARE_AVAILABLE and nome in fontes:
                tensao = fontes[nome].voltage
                logger.info(f"  Hardware - {nome}: {tensao}V")
            else:
                tensao = simular_leitura(nome)
                logger.info(f"  Simulação - {nome}: {tensao}V")
            
            estado = determinar_estado_fonte(nome, tensao)
            logger.info(f"  Estado - {nome}: {estado}")
            
            dados[nome] = {
                "tensao": round(tensao, 2),
                "estado": estado,
                "config": FONTES_CONFIG[nome]
            }
        
        logger.info(f"Dados finais: {dados}")
        
        result = {
            "status": "ok",
            "hardware_disponivel": HARDWARE_AVAILABLE,
            "fontes": dados,
            "timestamp": datetime.now().isoformat()
        }
        
        logger.info("=== FIM /status ===")
        return jsonify(result)
    except Exception as e:
        logger.error(f"Erro ao obter status: {e}")
        return jsonify({"error": str(e)}), 500

@app.route("/eventos", methods=["GET"])
def listar_eventos():
    try:
        limite = request.args.get('limite', 100, type=int)
        fonte_filtro = request.args.get('fonte')
        
        with get_db_connection() as conn:
            query = "SELECT * FROM eventos"
            params = []
            
            if fonte_filtro:
                query += " WHERE fonte = ?"
                params.append(fonte_filtro)
            
            query += " ORDER BY data_hora DESC LIMIT ?"
            params.append(limite)
            
            cursor = conn.execute(query, params)
            eventos = cursor.fetchall()
            
        return jsonify([
            {
                "id": evento["id"],
                "fonte": evento["fonte"],
                "tipo": evento["tipo"],
                "tensao": evento["tensao"],
                "data_hora": evento["data_hora"]
            }
            for evento in eventos
        ])
    except Exception as e:
        logger.error(f"Erro ao listar eventos: {e}")
        return jsonify({"error": str(e)}), 500

@app.route("/eventos", methods=["POST"])
def criar_evento():
    try:
        dados = request.get_json()
        if not dados:
            return jsonify({"error": "Dados JSON requeridos"}), 400
        
        fonte = dados.get("fonte")
        tipo = dados.get("tipo", "manual")
        tensao = dados.get("tensao")
        
        if not fonte:
            return jsonify({"error": "Campo 'fonte' é obrigatório"}), 400
        
        if fonte not in FONTES_CONFIG:
            return jsonify({"error": f"Fonte inválida. Opções: {list(FONTES_CONFIG.keys())}"}), 400
        
        registrar_evento(fonte, tipo, tensao)
        return jsonify({"status": "ok", "mensagem": "Evento criado com sucesso"})
    except Exception as e:
        logger.error(f"Erro ao criar evento: {e}")
        return jsonify({"error": str(e)}), 500

def calculate_uptime_stats(fonte_filtro, eventos):
    """
    Calculate uptime statistics based on filter and events.
    Returns uptime since last failure for filtered source or all sources.
    """
    now = datetime.now()
    
    if fonte_filtro:
        # Calculate uptime for specific source (time since last failure)
        failure_events = [e for e in eventos if e[0] == fonte_filtro and e[1] == 'FALHA']
        if failure_events:
            # Get the most recent failure
            last_failure = max(failure_events, key=lambda x: x[3])
            try:
                # Try different date formats
                last_failure_time = datetime.strptime(last_failure[3], '%Y-%m-%d %H:%M:%S')
            except ValueError:
                try:
                    last_failure_time = datetime.fromisoformat(last_failure[3].replace('Z', '+00:00'))
                except ValueError:
                    # Fallback to system uptime if date parsing fails
                    last_failure_time = simulacao_iniciada
            
            uptime_seconds = (now - last_failure_time).total_seconds()
        else:
            # No failures found, use system uptime
            uptime_seconds = (now - simulacao_iniciada).total_seconds()
        
        return {
            'uptime_seconds': uptime_seconds,
            'uptime_type': 'source',
            'source_name': fonte_filtro,
            'last_failure': last_failure[3] if failure_events else None
        }
    else:
        # Calculate uptime for all sources (time since ALL sources were down simultaneously)
        uptime_seconds, last_total_blackout = calculate_time_since_total_blackout(eventos)
        
        return {
            'uptime_seconds': uptime_seconds,
            'uptime_type': 'system',
            'last_total_blackout': last_total_blackout,
            'last_failure': None
        }

def calculate_time_since_total_blackout(eventos):
    """
    Calculate time since the last total blackout event.
    A total blackout is when ALL sources are simultaneously in FALHA state.
    Returns uptime since the system recovered from the last total blackout.
    """
    now = datetime.now()
    all_sources = list(FONTES_CONFIG.keys())
    
    if not all_sources:
        # No sources configured, return system uptime
        uptime_since_start = (now - simulacao_iniciada).total_seconds()
        logger.debug("No sources configured, returning system uptime")
        return uptime_since_start, None
    
    # Parse and sort events chronologically (oldest first)
    parsed_events = []
    
    for evento in eventos:
        fonte, tipo, tensao, data_hora = evento
        try:
            # Try different date formats
            event_time = datetime.strptime(data_hora, '%Y-%m-%d %H:%M:%S')
        except ValueError:
            try:
                event_time = datetime.fromisoformat(data_hora.replace('Z', '+00:00'))
            except ValueError:
                continue
        
        parsed_events.append((event_time, fonte, tipo))
    
    # Sort events by time (oldest first)
    parsed_events.sort(key=lambda x: x[0])
    
    # Track state transitions and find blackout periods
    source_states = {source: 'ATIVA' for source in all_sources}  # Start with all active
    blackout_periods = []
    current_blackout_start = None
    
    # Process events chronologically to identify blackout periods
    for event_time, fonte, tipo in parsed_events:
        if fonte in source_states:
            old_state = source_states[fonte]
            source_states[fonte] = tipo
            
            # Check if we just entered a total blackout
            all_failed = all(state == 'FALHA' for state in source_states.values())
            was_all_failed = all_failed and old_state != 'FALHA'  # This event caused total blackout
            
            if all_failed and current_blackout_start is None:
                # Start of a new blackout period
                current_blackout_start = event_time
                logger.debug(f"Total blackout started at {event_time} due to {fonte} failure")
            elif not all_failed and current_blackout_start is not None:
                # End of current blackout period
                blackout_periods.append((current_blackout_start, event_time))
                logger.debug(f"Total blackout ended at {event_time} due to {fonte} recovery")
                current_blackout_start = None
    
    # Check if we're currently in a blackout
    currently_in_blackout = all(state == 'FALHA' for state in source_states.values())
    
    logger.debug(f"Current source states: {source_states}")
    logger.debug(f"Currently in blackout: {currently_in_blackout}")
    logger.debug(f"Blackout periods found: {len(blackout_periods)}")
    
    if current_blackout_start is not None and currently_in_blackout:
        # We're still in a blackout that started at current_blackout_start
        uptime_since_blackout = 0  # No uptime during blackout
        logger.debug(f"Currently in ongoing blackout that started at {current_blackout_start}")
        return uptime_since_blackout, current_blackout_start.strftime('%Y-%m-%d %H:%M:%S')
    
    # Find the most recent completed blackout period
    if blackout_periods:
        last_blackout_start, last_blackout_end = blackout_periods[-1]
        
        # Calculate uptime since the last blackout ended
        uptime_since_blackout = (now - last_blackout_end).total_seconds()
        logger.debug(f"Last blackout: {last_blackout_start} to {last_blackout_end}, uptime since: {uptime_since_blackout}s")
        return uptime_since_blackout, last_blackout_start.strftime('%Y-%m-%d %H:%M:%S')
    
    # Check if there's an ongoing blackout that started but hasn't ended
    if current_blackout_start is not None:
        # We're in a blackout - no uptime
        logger.debug(f"In ongoing blackout that started at {current_blackout_start}")
        return 0, current_blackout_start.strftime('%Y-%m-%d %H:%M:%S')
    
    # No total blackout found in the event history, use system uptime
    uptime_since_start = (now - simulacao_iniciada).total_seconds()
    logger.debug(f"No total blackout found, using system uptime: {uptime_since_start}s")
    return uptime_since_start, None

@app.route("/estatisticas", methods=["GET"])
def estatisticas():
    """Retorna estatísticas agregadas do sistema"""
    try:
        periodo = request.args.get('periodo', '24h')
        fonte_filtro = request.args.get('fonte', '')  # New source filter parameter
        
        # Definir período em horas
        horas_periodo = {
            '24h': 24,
            '7d': 24 * 7,
            '30d': 24 * 30
        }.get(periodo, 24)
        
        # Buscar eventos do período
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Build query with optional source filter
            if fonte_filtro:
                cursor.execute("""
                    SELECT fonte, tipo, tensao, data_hora 
                    FROM eventos 
                    WHERE data_hora >= datetime('now', '-{} hours')
                    AND fonte = ?
                    ORDER BY data_hora DESC
                """.format(horas_periodo), (fonte_filtro,))
            else:
                cursor.execute("""
                    SELECT fonte, tipo, tensao, data_hora 
                    FROM eventos 
                    WHERE data_hora >= datetime('now', '-{} hours')
                    ORDER BY data_hora DESC
                """.format(horas_periodo))
            
            eventos = cursor.fetchall()
        
        # Calcular estatísticas por fonte
        stats = {}
        
        # Determine which sources to process
        sources_to_process = [fonte_filtro] if fonte_filtro and fonte_filtro in FONTES_CONFIG else FONTES_CONFIG.keys()
        
        for fonte_key in sources_to_process:
            if fonte_key not in FONTES_CONFIG:
                continue
                
            fonte_config = FONTES_CONFIG[fonte_key]
            eventos_fonte = [e for e in eventos if e[0] == fonte_key]
            
            total_eventos = len(eventos_fonte)
            eventos_ativa = len([e for e in eventos_fonte if e[1] == 'ATIVA'])
            eventos_falha = len([e for e in eventos_fonte if e[1] == 'FALHA'])
            
            # Calcular disponibilidade (% tempo ativo)
            if total_eventos > 0:
                disponibilidade = (eventos_ativa / total_eventos) * 100
            else:
                disponibilidade = 100.0
            
            # Calcular tensões
            tensoes = [float(e[2]) for e in eventos_fonte if e[2]]
            if tensoes:
                tensao_media = sum(tensoes) / len(tensoes)
                tensao_min = min(tensoes)
                tensao_max = max(tensoes)
            else:
                tensao_media = tensao_min = tensao_max = 0.0
            
            stats[fonte_key] = {
                'nome': fonte_config['nome'],
                'disponibilidade': round(disponibilidade, 1),
                'total_eventos': total_eventos,
                'eventos_ativa': eventos_ativa,
                'eventos_falha': eventos_falha,
                'tensao_media': round(tensao_media, 2),
                'tensao_min': round(tensao_min, 2),
                'tensao_max': round(tensao_max, 2)
            }
        
        # Adicionar métricas de sistema
        data_inicio = datetime.now() - timedelta(hours=horas_periodo)
        data_fim = datetime.now()
        
        # Calculate uptime based on filter
        uptime_info = calculate_uptime_stats(fonte_filtro, eventos)
        
        # Debug logging for uptime calculation
        logger.debug(f"Uptime calculation - Filter: {fonte_filtro}, Type: {uptime_info.get('uptime_type')}, Seconds: {uptime_info.get('uptime_seconds')}")
        if fonte_filtro:
            logger.debug(f"Source uptime - Last failure: {uptime_info.get('last_failure')}")
        else:
            logger.debug(f"System uptime - Last total blackout: {uptime_info.get('last_total_blackout')}")
        
        sistema_stats = {
            'uptime_sistema': (datetime.now() - simulacao_iniciada).total_seconds(),
            'total_fontes': len(sources_to_process),
            'fontes_ativas': len([s for s in stats.values() if s['disponibilidade'] >= 80]),
            'eventos_por_hora': sum(s['total_eventos'] for s in stats.values()) / max(horas_periodo, 1),
            'disponibilidade_sistema': sum(s['disponibilidade'] for s in stats.values()) / len(stats) if stats else 0,
            'modo_hardware': HARDWARE_AVAILABLE,
            'conexoes_websocket_ativas': len(getattr(enviar_dados, '__clients__', [])),
            'versao': '2.0',
            'banco_eventos': len(eventos) if eventos else 0,
            'fonte_filtro': fonte_filtro,  # Include filter info in response
            'uptime_stats': uptime_info  # Add uptime statistics
        }
        
        return jsonify({
            'periodo': periodo,
            'fonte_filtro': fonte_filtro,
            'timestamp': datetime.now().isoformat(),
            'estatisticas': stats,
            'sistema': sistema_stats,
            'periodo_detalhes': {
                'inicio': data_inicio.isoformat(),
                'fim': data_fim.isoformat(),
                'horas': horas_periodo
            }
        })
        
    except Exception as e:
        logger.error(f"Erro ao calcular estatísticas: {e}")
        return jsonify({"error": str(e)}), 500

@app.route("/configuracao", methods=["GET"])
def get_configuracao():
    """Retorna configuração atual do sistema"""
    try:
        # Carregar configurações do banco de dados
        config = {
            'modo_simulacao': not HARDWARE_AVAILABLE,
            'intervalo_leitura': get_config_value('intervalo_leitura', INTERVALO_LEITURA),
            'percentual_instabilidade': get_config_value('percentual_instabilidade', 70),
            'notify_failures': get_config_value('notify_failures', True),
            'notify_recovery': get_config_value('notify_recovery', True),
            'modo_debug': get_config_value('modo_debug', False),
            'thresholds': {},
            'fontes': {}
        }
        
        # Thresholds das fontes do banco ou valores padrão
        thresholds_db = get_config_value('thresholds_fontes', {})
        
        # Configurações por fonte
        for fonte_key, fonte_config in FONTES_CONFIG.items():
            threshold_value = thresholds_db.get(fonte_key, fonte_config['threshold'])
            config['thresholds'][fonte_key] = threshold_value
            config['fontes'][fonte_key] = {
                'nome': fonte_config['nome'],
                'threshold': threshold_value,
                'prioridade': fonte_config['prioridade'],
                'canal': fonte_config.get('canal', 0)
            }
        
        return jsonify(config)
        
    except Exception as e:
        logger.error(f"Erro ao obter configuração: {e}")
        return jsonify({"error": str(e), "details": "Erro interno do servidor"}), 500

@app.route("/configuracao", methods=["POST"])
def set_configuracao():
    """Atualiza configuração do sistema"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "Dados JSON obrigatórios", "details": "Nenhum dado foi enviado"}), 400
        
        # Validar e aplicar configurações
        alteracoes = []
        erros = []
        
        # Intervalo de leitura
        if 'intervalo_leitura' in data:
            try:
                novo_intervalo = float(data['intervalo_leitura'])
                if 0.1 <= novo_intervalo <= 60:
                    if set_config_value('intervalo_leitura', novo_intervalo, 'float', 'web'):
                        global INTERVALO_LEITURA
                        INTERVALO_LEITURA = novo_intervalo
                        alteracoes.append(f"Intervalo de leitura: {novo_intervalo}s")
                    else:
                        erros.append("Erro ao salvar intervalo de leitura")
                else:
                    erros.append("Intervalo deve estar entre 0.1 e 60 segundos")
            except (ValueError, TypeError):
                erros.append("Intervalo de leitura deve ser um número válido")
        
        # Processar percentual de instabilidade
        if 'percentual_instabilidade' in data:
            try:
                novo_percentual = int(data['percentual_instabilidade'])
                if 50 <= novo_percentual <= 90:
                    if set_config_value('percentual_instabilidade', novo_percentual, 'int', 'web'):
                        alteracoes.append(f"Percentual de instabilidade: {novo_percentual}%")
                    else:
                        erros.append("Erro ao salvar percentual de instabilidade")
                else:
                    erros.append("Percentual deve estar entre 50% e 90%")
            except (ValueError, TypeError):
                erros.append("Percentual de instabilidade deve ser um número válido")

        # Processar notificações
        for notif_campo in ['notify_failures', 'notify_recovery']:
            if notif_campo in data:
                try:
                    valor = bool(data[notif_campo])
                    if set_config_value(notif_campo, valor, 'boolean', 'web'):
                        nome_campo = notif_campo.replace('notify_', '').replace('_', ' ').title()
                        alteracoes.append(f"Notificação {nome_campo}: {'Ativada' if valor else 'Desativada'}")
                    else:
                        erros.append(f"Erro ao salvar configuração de {notif_campo}")
                except (ValueError, TypeError):
                    erros.append(f"{notif_campo} deve ser verdadeiro ou falso")

        # Processar thresholds por fonte
        if 'thresholds' in data and isinstance(data['thresholds'], dict):
            thresholds_atuais = get_config_value('thresholds_fontes', {})
            thresholds_novos = thresholds_atuais.copy()
            
            for fonte_key, novo_threshold in data['thresholds'].items():
                if fonte_key in FONTES_CONFIG:
                    try:
                        novo_threshold = float(novo_threshold)
                        # Validar limites por tipo de fonte
                        limites = {
                            'rede': [100, 250],
                            'solar': [80, 200], 
                            'gerador': [100, 250],
                            'ups': [5, 20]
                        }
                        
                        min_val, max_val = limites.get(fonte_key, [0, 1000])
                        if min_val <= novo_threshold <= max_val:
                            thresholds_novos[fonte_key] = novo_threshold
                            # Atualizar configuração global também
                            FONTES_CONFIG[fonte_key]['threshold'] = novo_threshold
                            fonte_nome = FONTES_CONFIG[fonte_key]['nome']
                            alteracoes.append(f"{fonte_nome}: {novo_threshold}V")
                        else:
                            erros.append(f"Threshold {fonte_key} deve estar entre {min_val}V e {max_val}V")
                    except (ValueError, TypeError):
                        erros.append(f"Threshold {fonte_key} deve ser um número válido")
                else:
                    erros.append(f"Fonte {fonte_key} não é válida")
            
            # Salvar thresholds atualizados
            if set_config_value('thresholds_fontes', thresholds_novos, 'json', 'web'):
                logger.info(f"Thresholds atualizados: {thresholds_novos}")
            else:
                erros.append("Erro ao salvar configurações de threshold")

        # Configurações globais restantes
        for campo in ['modo_debug']:
            if campo in data:
                try:
                    valor = bool(data[campo])
                    if set_config_value(campo, valor, 'boolean', 'web'):
                        alteracoes.append(f"{campo.replace('_', ' ').title()}: {valor}")
                    else:
                        erros.append(f"Erro ao salvar {campo}")
                        
                except (ValueError, TypeError):
                    erros.append(f"Valor inválido para {campo}")
        
        # Configurações das fontes
        if 'fontes' in data:
            thresholds_atualizados = get_config_value('thresholds_fontes', {})
            
            for fonte_key, fonte_data in data['fontes'].items():
                if fonte_key in FONTES_CONFIG:
                    if 'threshold' in fonte_data:
                        try:
                            novo_threshold = float(fonte_data['threshold'])
                            if novo_threshold > 0:
                                # Atualizar em memória
                                FONTES_CONFIG[fonte_key]['threshold'] = novo_threshold
                                # Atualizar no banco
                                thresholds_atualizados[fonte_key] = novo_threshold
                                alteracoes.append(f"{FONTES_CONFIG[fonte_key]['nome']} threshold: {novo_threshold}V")
                            else:
                                erros.append(f"Threshold de {fonte_key} deve ser maior que 0")
                        except (ValueError, TypeError):
                            erros.append(f"Threshold inválido para {fonte_key}")
                else:
                    erros.append(f"Fonte desconhecida: {fonte_key}")
            
            # Salvar thresholds no banco
            if alteracoes and not set_config_value('thresholds_fontes', thresholds_atualizados, 'json', 'web'):
                erros.append("Erro ao salvar configurações das fontes")
        
        # Resposta
        if erros:
            status_code = 400
            status = "partial_success" if alteracoes else "error"
            message = f"Configuração atualizada com {len(erros)} erro(s)"
        else:
            status_code = 200
            status = "success"
            message = "Configuração atualizada com sucesso"
        
        logger.info(f"Configuração atualizada: {alteracoes}, Erros: {erros}")
        
        return jsonify({
            "status": status,
            "message": message,
            "alteracoes": alteracoes,
            "erros": erros,
            "total_alteracoes": len(alteracoes),
            "total_erros": len(erros)
        }), status_code
        
    except Exception as e:
        logger.error(f"Erro ao atualizar configuração: {e}")
        return jsonify({
            "error": "Erro interno do servidor",
            "details": str(e),
            "status": "error"
        }), 500

@app.route("/exportar", methods=["GET"])
def exportar_dados():
    """Exporta dados em formato CSV"""
    try:
        formato = request.args.get('formato', 'csv')
        data_inicio = request.args.get('data_inicio')
        data_fim = request.args.get('data_fim')
        fontes_filtro = request.args.get('fontes', '').split(',') if request.args.get('fontes') else []
        
        # Validar formato
        if formato not in ['csv', 'json']:
            return jsonify({
                "error": "Formato não suportado",
                "details": "Formatos válidos: csv, json",
                "formato_solicitado": formato
            }), 400
        
        # Validar datas
        erros_validacao = []
        if data_inicio:
            try:
                datetime.strptime(data_inicio, '%Y-%m-%d')
            except ValueError:
                erros_validacao.append("data_inicio deve estar no formato YYYY-MM-DD")
        
        if data_fim:
            try:
                datetime.strptime(data_fim, '%Y-%m-%d')
            except ValueError:
                erros_validacao.append("data_fim deve estar no formato YYYY-MM-DD")
        
        if erros_validacao:
            return jsonify({
                "error": "Parâmetros inválidos",
                "details": erros_validacao
            }), 400
        
        # Construir query
        where_clauses = []
        params = []
        
        if data_inicio:
            where_clauses.append("data_hora >= ?")
            params.append(data_inicio + " 00:00:00")
            
        if data_fim:
            where_clauses.append("data_hora <= ?")
            params.append(data_fim + " 23:59:59")
            
        # Validar fontes
        if fontes_filtro and fontes_filtro[0]:
            fontes_validas = []
            for fonte in fontes_filtro:
                if fonte in FONTES_CONFIG:
                    fontes_validas.append(fonte)
                else:
                    erros_validacao.append(f"Fonte desconhecida: {fonte}")
            
            if erros_validacao:
                return jsonify({
                    "error": "Fontes inválidas",
                    "details": erros_validacao,
                    "fontes_validas": list(FONTES_CONFIG.keys())
                }), 400
            
            if fontes_validas:
                placeholders = ','.join(['?' for _ in fontes_validas])
                where_clauses.append(f"fonte IN ({placeholders})")
                params.extend(fontes_validas)
        
        where_sql = "WHERE " + " AND ".join(where_clauses) if where_clauses else ""
        
        # Buscar dados
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(f"""
                SELECT id, fonte, tipo, tensao, data_hora 
                FROM eventos 
                {where_sql}
                ORDER BY data_hora DESC
                LIMIT 50000
            """, params)
            
            eventos = cursor.fetchall()
        
        if not eventos:
            return jsonify({
                "error": "Nenhum evento encontrado",
                "details": "Verifique os filtros aplicados",
                "filtros": {
                    "data_inicio": data_inicio,
                    "data_fim": data_fim,
                    "fontes": fontes_filtro
                }
            }), 404
        
        logger.info(f"Exportando {len(eventos)} eventos em formato {formato}")
        
        if formato == 'csv':
            import io
            import csv
            
            try:
                output = io.StringIO()
                writer = csv.writer(output)
                
                # Cabeçalho
                writer.writerow(['ID', 'Fonte', 'Nome da Fonte', 'Estado', 'Tensão (V)', 'Data/Hora'])
                
                # Dados
                for evento in eventos:
                    fonte_nome = FONTES_CONFIG.get(evento[1], {}).get('nome', evento[1])
                    writer.writerow([
                        evento[0],
                        evento[1],
                        fonte_nome,
                        evento[2],
                        f"{evento[3]:.2f}" if evento[3] else "N/A",
                        evento[4]
                    ])
                
                csv_data = output.getvalue()
                output.close()
                
                from flask import Response
                timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
                filename = f"poweredge_eventos_{timestamp}.csv"
                
                return Response(
                    csv_data,
                    mimetype='text/csv',
                    headers={
                        'Content-Disposition': f'attachment; filename={filename}',
                        'Content-Length': str(len(csv_data))
                    }
                )
                
            except Exception as e:
                logger.error(f"Erro ao gerar CSV: {e}")
                return jsonify({
                    "error": "Erro ao gerar arquivo CSV",
                    "details": str(e)
                }), 500
        
        elif formato == 'json':
            try:
                dados_json = []
                for evento in eventos:
                    fonte_nome = FONTES_CONFIG.get(evento[1], {}).get('nome', evento[1])
                    dados_json.append({
                        'id': evento[0],
                        'fonte': evento[1],
                        'nome_fonte': fonte_nome,
                        'estado': evento[2],
                        'tensao': round(evento[3], 2) if evento[3] else None,
                        'data_hora': evento[4]
                    })
                
                from flask import Response
                import json
                
                timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
                filename = f"poweredge_eventos_{timestamp}.json"
                
                json_data = json.dumps({
                    'exportacao': {
                        'timestamp': datetime.now().isoformat(),
                        'total_eventos': len(dados_json),
                        'filtros': {
                            'data_inicio': data_inicio,
                            'data_fim': data_fim,
                            'fontes': fontes_filtro
                        }
                    },
                    'eventos': dados_json
                }, indent=2, ensure_ascii=False)
                
                return Response(
                    json_data,
                    mimetype='application/json',
                    headers={
                        'Content-Disposition': f'attachment; filename={filename}',
                        'Content-Length': str(len(json_data))
                    }
                )
                
            except Exception as e:
                logger.error(f"Erro ao gerar JSON: {e}")
                return jsonify({
                    "error": "Erro ao gerar arquivo JSON",
                    "details": str(e)
                }), 500
            
    except Exception as e:
        logger.error(f"Erro ao exportar dados: {e}")
        return jsonify({
            "error": "Erro interno do servidor",
            "details": str(e)
        }), 500

if __name__ == "__main__":
    print("Iniciando PowerEdge v2.0...")
    print("="*50)
    print(f"Hardware disponível: {'Sim' if HARDWARE_AVAILABLE else 'Não (Modo Simulação)'}")
    print(f"Porta Flask: {FLASK_PORT}")
    print(f"Porta WebSocket: {WEBSOCKET_PORT}")
    print(f"Base dir: {BASE_DIR}")
    print(f"Static dir: {STATIC_DIR}")
    print("="*50)
    
    try:
        # Inicializar banco de dados
        init_database()
        
        # Iniciar thread do WebSocket em background
        websocket_thread = threading.Thread(target=iniciar_websocket, daemon=True)
        websocket_thread.start()
        
        print("Serviços iniciados com sucesso!")
        print(f"Acesse: http://localhost:{FLASK_PORT}")
        print("Pressione Ctrl+C para sair")
        
        # Iniciar Flask
        app.run(
            host='0.0.0.0',
            port=FLASK_PORT,
            debug=False,
            threaded=True
        )
        
    except KeyboardInterrupt:
        print("\nEncerrando PowerEdge...")
    except Exception as e:
        print(f"Erro crítico: {e}")
        logger.error(f"Erro crítico na inicialização: {e}")
