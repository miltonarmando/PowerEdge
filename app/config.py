# Configurações do Sistema
import os

# Configurações do banco de dados
DATABASE_PATH = os.getenv('DATABASE_PATH', 'energia.db')

# Configurações de rede
FLASK_HOST = os.getenv('FLASK_HOST', '0.0.0.0')
FLASK_PORT = int(os.getenv('FLASK_PORT', 5000))
WEBSOCKET_HOST = os.getenv('WEBSOCKET_HOST', '0.0.0.0')
WEBSOCKET_PORT = int(os.getenv('WEBSOCKET_PORT', 8765))

# Configurações do sensor
LIMIAR_TENSAO = float(os.getenv('LIMIAR_TENSAO', 0.8))  # volts
INTERVALO_LEITURA = float(os.getenv('INTERVALO_LEITURA', 1.0))  # segundos

# Configurações de logging
LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO')
LOG_FILE = os.getenv('LOG_FILE', 'energia.log')

# Configurações do ADS1115
ADS_GAIN = 1  # Para tensões até 4.096V
ADS_DATA_RATE = 128  # Samples per second

# Mapeamento das fontes
FONTES_CONFIG = {
    "gerador": {"canal": 0, "nome": "Gerador", "cor": "#ff6b6b", "icone": "⚡", "prioridade": 3, "threshold": 180.0},
    "rede": {"canal": 1, "nome": "Rede Elétrica", "cor": "#4ecdc4", "icone": "🏠", "prioridade": 1, "threshold": 180.0},
    "solar": {"canal": 2, "nome": "Energia Solar", "cor": "#45b7d1", "icone": "☀️", "prioridade": 2, "threshold": 120.0},
    "ups": {"canal": 3, "nome": "UPS/Bateria", "cor": "#9b59b6", "icone": "🔋", "prioridade": 4, "threshold": 10.0}
}
