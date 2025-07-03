#!/usr/bin/env python3
"""
PowerEdge Demo Script
Demonstra as funcionalidades do sistema com hardware real
"""

import requests
import json
import time
import threading
import websocket
from datetime import datetime

class PowerEdgeDemo:
    def __init__(self, host='localhost', port=5000, ws_port=8765):
        self.api_url = f"http://{host}:{port}"
        self.ws_url = f"ws://{host}:{ws_port}"
        self.running = False
        
    def test_api_endpoints(self):
        """Testa todos os endpoints da API"""
        print("🧪 Testando API Endpoints...")
        
        # Teste GET /status
        try:
            response = requests.get(f"{self.api_url}/status")
            if response.status_code == 200:
                data = response.json()
                print("✅ GET /status - OK")
                print(f"   Hardware disponível: {data.get('hardware_disponivel', 'N/A')}")
                print(f"   Fontes monitoradas: {len(data.get('fontes', {}))}")
            else:
                print(f"❌ GET /status - Erro {response.status_code}")
        except Exception as e:
            print(f"❌ GET /status - Erro: {e}")
        
        # Teste GET /eventos
        try:
            response = requests.get(f"{self.api_url}/eventos?limite=5")
            if response.status_code == 200:
                eventos = response.json()
                print("✅ GET /eventos - OK")
                print(f"   Eventos recentes: {len(eventos)}")
                if eventos:
                    ultimo = eventos[0]
                    print(f"   Último evento: {ultimo['fonte']} - {ultimo['tipo']}")
            else:
                print(f"❌ GET /eventos - Erro {response.status_code}")
        except Exception as e:
            print(f"❌ GET /eventos - Erro: {e}")
        
        # Teste POST /eventos
        try:
            evento_teste = {
                "fonte": "rede",
                "tipo": "TESTE_API",
                "tensao": 220.5
            }
            response = requests.post(
                f"{self.api_url}/eventos",
                json=evento_teste,
                headers={"Content-Type": "application/json"}
            )
            if response.status_code == 200:
                print("✅ POST /eventos - OK")
                print("   Evento de teste criado com sucesso")
            else:
                print(f"❌ POST /eventos - Erro {response.status_code}")
        except Exception as e:
            print(f"❌ POST /eventos - Erro: {e}")
        
        print()
    
    def test_websocket(self, duration=10):
        """Testa conexão WebSocket"""
        print(f"🔌 Testando WebSocket por {duration} segundos...")
        
        def on_message(ws, message):
            try:
                data = json.loads(message)
                fontes_ativas = sum(1 for fonte in data.values() if fonte.get('estado') == 'ATIVA')
                total_fontes = len(data)
                print(f"📊 Dados recebidos: {fontes_ativas}/{total_fontes} fontes ativas")
            except Exception as e:
                print(f"❌ Erro ao processar mensagem: {e}")
        
        def on_error(ws, error):
            print(f"❌ Erro WebSocket: {error}")
        
        def on_close(ws, close_status_code, close_msg):
            print("🔌 WebSocket desconectado")
        
        def on_open(ws):
            print("✅ WebSocket conectado")
            
        try:
            ws = websocket.WebSocketApp(
                self.ws_url,
                on_open=on_open,
                on_message=on_message,
                on_error=on_error,
                on_close=on_close
            )
            
            # Executa em thread separada
            wst = threading.Thread(target=ws.run_forever)
            wst.daemon = True
            wst.start()
            
            # Aguarda o tempo especificado
            time.sleep(duration)
            ws.close()
            
        except Exception as e:
            print(f"❌ Erro ao conectar WebSocket: {e}")
        
        print()
    
    def generate_sample_events(self, count=5):
        """Gera eventos de exemplo"""
        print(f"📝 Gerando {count} eventos de exemplo...")
        
        fontes = ['rede', 'solar', 'gerador', 'ups']
        tipos = ['ATIVA', 'FALHA', 'TESTE']
        
        import random
        
        for i in range(count):
            evento = {
                "fonte": random.choice(fontes),
                "tipo": random.choice(tipos),
                "tensao": round(random.uniform(0.5, 250.0), 2)
            }
            
            try:
                response = requests.post(
                    f"{self.api_url}/eventos",
                    json=evento,
                    headers={"Content-Type": "application/json"}
                )
                if response.status_code == 200:
                    print(f"   ✅ {evento['fonte']} - {evento['tipo']} ({evento['tensao']}V)")
                else:
                    print(f"   ❌ Erro ao criar evento: {response.status_code}")
            except Exception as e:
                print(f"   ❌ Erro: {e}")
            
            time.sleep(0.5)  # Pequena pausa entre eventos
        
        print()
    
    def show_dashboard_info(self):
        """Mostra informações do dashboard"""
        print("📊 Informações do Dashboard...")
        
        try:
            response = requests.get(f"{self.api_url}/status")
            if response.status_code == 200:
                data = response.json()
                
                print(f"🔧 Hardware: {'Disponível' if data.get('hardware_disponivel') else 'Indisponível'}")
                print(f"⏰ Timestamp: {data.get('timestamp', 'N/A')}")
                print()
                
                fontes = data.get('fontes', {})
                if fontes:
                    print("⚡ Status das Fontes:")
                    for nome, info in fontes.items():
                        icones = {
                            'rede': '🏠',
                            'solar': '☀️', 
                            'gerador': '⚡',
                            'ups': '🔋'
                        }
                        icone = icones.get(nome, '💡')
                        status_icon = '✅' if info['estado'] == 'ATIVA' else '❌' if info['estado'] == 'FALHA' else '⚠️'
                        
                        print(f"   {icone} {nome.capitalize():<10}: {info['tensao']:>6.1f}V {status_icon} {info['estado']}")
                else:
                    print("❌ Nenhuma fonte encontrada")
            else:
                print(f"❌ Erro ao obter status: {response.status_code}")
        except Exception as e:
            print(f"❌ Erro: {e}")
        
        print()
    
    def run_demo(self):
        """Executa demonstração completa"""
        print("🔋 PowerEdge v2.0 - Demonstração do Sistema")
        print("=" * 50)
        print()
        print("🔧 MODO HARDWARE REAL")
        print("   • Sistema configurado para usar apenas hardware real")
        print("   • Requer Raspberry Pi com ADS1115 conectado")
        print("   • Monitoramento em tempo real das fontes de energia")
        print()
        
        # Informações básicas
        print(f"🌐 API URL: {self.api_url}")
        print(f"🔌 WebSocket URL: {self.ws_url}")
        print(f"⏰ Hora: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print()
        
        # Testes
        self.test_api_endpoints()
        self.show_dashboard_info()
        self.generate_sample_events(3)
        self.test_websocket(15)
        
        print("✅ Demonstração concluída!")
        print()
        print("🌐 Acesse a interface web em: http://localhost:5000")
        print("📊 Dashboard moderno com monitoramento em tempo real")
        print("🔋 Suporte completo para UPS/Bateria")
        print("📱 Interface responsiva para mobile")

def main():
    import argparse
    
    parser = argparse.ArgumentParser(description='PowerEdge Demo Script')
    parser.add_argument('--host', default='localhost', help='Host do servidor')
    parser.add_argument('--port', type=int, default=5000, help='Porta da API')
    parser.add_argument('--ws-port', type=int, default=8765, help='Porta do WebSocket')
    parser.add_argument('--api-only', action='store_true', help='Testar apenas API')
    parser.add_argument('--ws-only', action='store_true', help='Testar apenas WebSocket')
    
    args = parser.parse_args()
    
    demo = PowerEdgeDemo(args.host, args.port, args.ws_port)
    
    if args.api_only:
        demo.test_api_endpoints()
        demo.show_dashboard_info()
    elif args.ws_only:
        demo.test_websocket(30)
    else:
        demo.run_demo()

if __name__ == "__main__":
    main()
