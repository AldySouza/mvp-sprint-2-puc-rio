#!/usr/bin/env bash
set -e

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
API_DIR="$ROOT_DIR/api"
VENV_DIR="$API_DIR/venv"
MODEL_FILE="$API_DIR/model/modelo_treinado.pkl"
REQUIREMENTS="$API_DIR/requirements.txt"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

header() { echo -e "\n${CYAN}══════════════════════════════════════════${NC}"; echo -e "${CYAN}  $1${NC}"; echo -e "${CYAN}══════════════════════════════════════════${NC}\n"; }
ok()     { echo -e "  ${GREEN}✔${NC} $1"; }
warn()   { echo -e "  ${YELLOW}⚠${NC} $1"; }
fail()   { echo -e "  ${RED}✖${NC} $1"; }

header "StrokeGuard MVP — Inicialização"

# --- Python -----------------------------------------------------------
PYTHON=""
for cmd in python3 python; do
    if command -v "$cmd" &>/dev/null; then
        PYTHON="$cmd"
        break
    fi
done

if [ -z "$PYTHON" ]; then
    fail "Python não encontrado. Instale Python 3.10+ e tente novamente."
    exit 1
fi

PY_VERSION=$("$PYTHON" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
PY_MAJOR=$("$PYTHON" -c "import sys; print(sys.version_info.major)")
PY_MINOR=$("$PYTHON" -c "import sys; print(sys.version_info.minor)")

if [ "$PY_MAJOR" -lt 3 ] || { [ "$PY_MAJOR" -eq 3 ] && [ "$PY_MINOR" -lt 10 ]; }; then
    fail "Python $PY_VERSION detectado. É necessário Python 3.10 ou superior."
    exit 1
fi
ok "Python $PY_VERSION encontrado ($PYTHON)"

# --- Virtual environment ----------------------------------------------
if [ ! -d "$VENV_DIR" ]; then
    echo -e "\n  Criando ambiente virtual em ${YELLOW}api/venv/${NC}..."
    "$PYTHON" -m venv "$VENV_DIR"
    ok "Ambiente virtual criado"
else
    ok "Ambiente virtual já existe"
fi

source "$VENV_DIR/bin/activate"
ok "Ambiente virtual ativado"

# --- Dependencies -----------------------------------------------------
echo -e "\n  Instalando dependências..."
pip install --upgrade pip --quiet
pip install -r "$REQUIREMENTS" --quiet
ok "Dependências instaladas"

# --- Model check ------------------------------------------------------
if [ ! -f "$MODEL_FILE" ]; then
    echo ""
    warn "Modelo não encontrado em api/model/modelo_treinado.pkl"
    warn "Execute o notebook no Google Colab primeiro e copie o .pkl para api/model/"
    warn "O servidor iniciará, mas predições não funcionarão até o modelo estar presente."
    echo ""
fi

# --- Dataset check ----------------------------------------------------
if [ ! -f "$ROOT_DIR/data/healthcare-dataset-stroke-data.csv" ]; then
    warn "Dataset não encontrado em data/. Os testes PyTest podem falhar."
fi

# --- Start server -----------------------------------------------------
header "Iniciando servidor Flask"
echo -e "  URL: ${GREEN}http://localhost:5000${NC}"
echo -e "  Para encerrar: ${YELLOW}Ctrl+C${NC}\n"

cd "$API_DIR"
"$VENV_DIR/bin/python" app.py
