#!/bin/bash

# Script de limpeza do PowerEdge
# Remove arquivos desnecessários mantendo funcionalidade

echo "🧹 PowerEdge - Limpeza de Arquivos Desnecessários"
echo "================================================"

# Função para confirmar remoção
confirm_removal() {
    local file=$1
    local reason=$2
    
    if [ -f "$file" ] || [ -d "$file" ]; then
        echo "📄 Encontrado: $file"
        echo "   Motivo: $reason"
        read -p "   Remover? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$file"
            echo "   ✅ Removido: $file"
        else
            echo "   ⏭️  Mantido: $file"
        fi
        echo
    fi
}

echo "🔍 Verificando arquivos que podem ser removidos..."
echo

# Arquivos de desenvolvimento/teste
echo "📋 Arquivos de Desenvolvimento/Teste:"
confirm_removal "demo.py" "Script de demonstração - não usado em produção"
confirm_removal "monitor_realtime.py" "Arquivo vazio sem funcionalidade"
confirm_removal "quick_check.sh" "Duplica funcionalidade do diagnostic.sh"

# Arquivos de diagnóstico específicos
echo "🔧 Arquivos de Diagnóstico:"
if [ -f "diagnostic.sh" ] && [ -f "diagnostic.bat" ]; then
    echo "📄 Encontrados: diagnostic.sh e diagnostic.bat"
    echo "   Motivo: Manter apenas um (diagnostic.sh para Linux)"
    read -p "   Remover diagnostic.bat? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f "diagnostic.bat"
        echo "   ✅ Removido: diagnostic.bat"
    else
        echo "   ⏭️  Mantido: diagnostic.bat"
    fi
    echo
fi

# Arquivos de configuração temporários
echo "⚙️  Arquivos de Configuração Temporários:"
confirm_removal ".env" "Arquivo de configuração local - será recriado pelo install.sh"

# Requirements específicos
echo "📦 Arquivos de Requirements:"
if [ -f "requirements.txt" ] && [ -f "requirements-windows.txt" ]; then
    echo "📄 Encontrados: requirements.txt e requirements-windows.txt"
    echo "   Motivo: Manter apenas requirements.txt para Raspberry Pi"
    read -p "   Remover requirements-windows.txt? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f "requirements-windows.txt"
        echo "   ✅ Removido: requirements-windows.txt"
    else
        echo "   ⏭️  Mantido: requirements-windows.txt"
    fi
    echo
fi

# Cache e arquivos temporários
echo "🗂️  Cache e Arquivos Temporários:"
confirm_removal "__pycache__" "Cache Python - será recriado automaticamente"
confirm_removal "app/__pycache__" "Cache Python do app - será recriado automaticamente"

# Diretórios vazios ou temporários
echo "📁 Diretórios Temporários:"
if [ -d "logs" ] && [ -z "$(ls -A logs 2>/dev/null)" ]; then
    confirm_removal "logs" "Diretório vazio - será recriado automaticamente"
fi

if [ -d "backups" ] && [ -z "$(ls -A backups 2>/dev/null)" ]; then
    confirm_removal "backups" "Diretório vazio - será recriado automaticamente"
fi

# Bancos de dados de teste
echo "🗃️  Bancos de Dados Temporários:"
for db_file in *.db *.sqlite *.sqlite3; do
    if [ -f "$db_file" ] && [[ "$db_file" != "energia.db" ]]; then
        confirm_removal "$db_file" "Banco de dados temporário ou de teste"
    fi
done

# Arquivos de backup antigos
echo "💾 Backups Antigos:"
for backup_file in *backup* *.bak *.old; do
    if [ -f "$backup_file" ]; then
        confirm_removal "$backup_file" "Arquivo de backup antigo"
    fi
done

# Arquivos de log antigos
echo "📜 Logs Antigos:"
for log_file in *.log *.log.*; do
    if [ -f "$log_file" ]; then
        file_size=$(stat -c%s "$log_file" 2>/dev/null || echo 0)
        if [ "$file_size" -gt 10485760 ]; then  # > 10MB
            confirm_removal "$log_file" "Log grande (>10MB) - pode impactar performance"
        fi
    fi
done

# Arquivos específicos do editor
echo "🖥️  Arquivos do Editor:"
confirm_removal ".vscode" "Configurações do VS Code - específicas do usuário"
confirm_removal ".idea" "Configurações do PyCharm - específicas do usuário"
confirm_removal "*.swp" "Arquivos temporários do Vim"
confirm_removal "*.swo" "Arquivos temporários do Vim"

echo "🎉 Limpeza concluída!"
echo
echo "📋 Resumo:"
echo "✅ Arquivos principais mantidos:"
echo "   - app/run.py (aplicação principal)"
echo "   - app/config.py (configurações)"
echo "   - static/ (interface web)"
echo "   - install.sh (instalação)"
echo "   - requirements.txt (dependências)"
echo "   - docs/ (documentação)"
echo
echo "🔧 Para verificar o sistema após limpeza:"
echo "   ./diagnostic.sh"
echo
echo "🚀 Para reinstalar dependências se necessário:"
echo "   ./install.sh"
