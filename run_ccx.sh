#!/usr/bin/env bash
set -euo pipefail

# ========== CONFIGURAÇÃO ==========
CONTAINER_NAME="ubuntu-calculix"
COMPOSE_DIR="/run/media/valdir/MAIN/000_VALDIR/GIT_PJR/FemEDSS/CalculiX"
PYTHON_VENV="/run/media/valdir/MAIN/000_VALDIR/GIT_PJR/PostEDSS/venv/bin/python"
# ===================================

if [[ $# -lt 1 ]]; then
    echo "Uso: $0 <arquivo.inp>"
    exit 1
fi

INP_FILE="$1"

if [[ ! -f "$INP_FILE" ]]; then
    echo "Arquivo não encontrado: $INP_FILE"
    exit 1
fi

INP_PATH=$(realpath "$INP_FILE")
INP_DIR=$(dirname "$INP_PATH")
INP_NAME=$(basename "$INP_PATH" .inp)

# Verifica se já existem resultados
if [[ -f "$INP_DIR/${INP_NAME}.frd" || -f "$INP_DIR/${INP_NAME}.vtu" ]]; then
    echo "Já existem resultados para $INP_NAME nesta pasta."
    read -p "Deseja sobrescrever? [y/N] " resposta
    if [[ ! "$resposta" =~ ^[Yy]$ ]]; then
        echo "Operação cancelada."
        exit 0
    fi
fi

echo "=== CalculiX ==="
echo "Arquivo : $INP_NAME.inp"
echo "Pasta   : $INP_DIR"
echo ""

# Garante que o container está rodando
cd "$COMPOSE_DIR"
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Iniciando container..."
    ./run-compose.sh
fi

# Copia o .inp para o container e roda
docker cp "$INP_PATH" "$CONTAINER_NAME:/home/ubuntu/${INP_NAME}.inp"

echo "[1/2] Rodando ccx..."
docker exec -w /home/ubuntu "$CONTAINER_NAME" /opt/CalculiX/bin/ccx "$INP_NAME"

# Copia os resultados de volta
for ext in frd dat sta cvg 12d; do
    docker cp "$CONTAINER_NAME:/home/ubuntu/${INP_NAME}.${ext}" "$INP_DIR/" 2>/dev/null || true
done

# Limpa no container
docker exec "$CONTAINER_NAME" rm -f "/home/ubuntu/${INP_NAME}."* 2>/dev/null || true

# Converte para VTU
echo "[2/2] Convertendo para ParaView (.vtu)..."
if [[ -f "$INP_DIR/${INP_NAME}.frd" ]]; then
    "$PYTHON_VENV" -m ccx2paraview "$INP_DIR/${INP_NAME}.frd" vtu
else
    echo "Aviso: arquivo .frd não encontrado."
fi

echo ""
echo "Concluído!"
echo "Resultados em: $INP_DIR"
echo "Arquivo ParaView: $INP_DIR/${INP_NAME}.vtu"