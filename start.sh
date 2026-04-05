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

# --- Python (mínimo 3.10; instalação automática prefere 3.11) ----------
MIN_PY_MAJOR=3
MIN_PY_MINOR=10
AUTO_PY_MINOR=11
# Homebrew usa python@3.11 (não python@11)
AUTO_PY_MM="${MIN_PY_MAJOR}.${AUTO_PY_MINOR}"

py_meets_min() {
    local mj mi
    mj=$1 mi=$2
    [ "$mj" -gt "$MIN_PY_MAJOR" ] && return 0
    [ "$mj" -eq "$MIN_PY_MAJOR" ] && [ "$mi" -ge "$MIN_PY_MINOR" ] && return 0
    return 1
}

pick_python() {
    local cmd mj mi
    for cmd in python3.13 python3.12 python3."${AUTO_PY_MINOR}" python3.10 python3 python; do
        if command -v "$cmd" &>/dev/null; then
            mj=$("$cmd" -c "import sys; print(sys.version_info.major)" 2>/dev/null) || continue
            mi=$("$cmd" -c "import sys; print(sys.version_info.minor)" 2>/dev/null) || continue
            if py_meets_min "$mj" "$mi"; then
                PYTHON="$cmd"
                return 0
            fi
        fi
    done
    for p in /opt/homebrew/opt/python@${AUTO_PY_MM}/bin/python3 \
             /usr/local/opt/python@${AUTO_PY_MM}/bin/python3; do
        if [ -x "$p" ]; then
            mj=$("$p" -c "import sys; print(sys.version_info.major)" 2>/dev/null) || continue
            mi=$("$p" -c "import sys; print(sys.version_info.minor)" 2>/dev/null) || continue
            if py_meets_min "$mj" "$mi"; then
                PYTHON="$p"
                return 0
            fi
        fi
    done
    return 1
}

try_install_python() {
    if command -v pyenv &>/dev/null; then
        warn "Python 3.${MIN_PY_MINOR}+ não encontrado. Tentando instalar via pyenv..."
        local v
        v="$(pyenv latest "${AUTO_PY_MM}" 2>/dev/null || true)"
        [ -z "$v" ] && v="${AUTO_PY_MM}.9"
        pyenv install -s "$v" || return 1
        export PYENV_VERSION="$v"
        eval "$(pyenv init - bash)"
        PYTHON="$(pyenv which python3 2>/dev/null || pyenv which python 2>/dev/null)"
        [ -n "$PYTHON" ] || return 1
        return 0
    fi
    if [ "$(uname -s)" = "Darwin" ] && command -v brew &>/dev/null; then
        warn "Python 3.${MIN_PY_MINOR}+ não encontrado. Tentando instalar via Homebrew (python@${AUTO_PY_MM})..."
        brew list "python@${AUTO_PY_MM}" &>/dev/null || brew install "python@${AUTO_PY_MM}"
        for p in /opt/homebrew/opt/python@${AUTO_PY_MM}/bin/python3 \
                 /usr/local/opt/python@${AUTO_PY_MM}/bin/python3; do
            if [ -x "$p" ]; then
                PYTHON="$p"
                return 0
            fi
        done
    fi
    return 1
}

PYTHON=""
if ! pick_python; then
    try_install_python || true
    if ! pick_python; then
        if [ -n "$PYTHON" ] && "$PYTHON" -c "import sys; sys.exit(0 if sys.version_info >= (${MIN_PY_MAJOR}, ${MIN_PY_MINOR}) else 1)" 2>/dev/null; then
            true
        else
            fail "Python 3.${MIN_PY_MINOR}+ não encontrado e instalação automática não foi possível."
            fail "Instale Python 3.${MIN_PY_MINOR} ou superior (https://www.python.org/downloads/) ou use pyenv/brew."
            exit 1
        fi
    fi
fi

PY_VERSION=$("$PYTHON" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
PY_MAJOR=$("$PYTHON" -c "import sys; print(sys.version_info.major)")
PY_MINOR=$("$PYTHON" -c "import sys; print(sys.version_info.minor)")

if ! py_meets_min "$PY_MAJOR" "$PY_MINOR"; then
    fail "Python $PY_VERSION detectado. É necessário Python 3.${MIN_PY_MINOR} ou superior."
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
echo -e "  URL: ${GREEN}http://localhost:5000${NC} (ou outra porta se 5000 estiver ocupada — veja a linha * Running on do Flask)"
echo -e "  Para encerrar: ${YELLOW}Ctrl+C${NC}\n"

cd "$API_DIR"
"$VENV_DIR/bin/python" app.py
