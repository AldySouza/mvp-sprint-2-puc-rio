"""Aplicação Flask do StrokeGuard MVP: API de predição e servir frontend."""

import logging
import os
import socket
import sys
import traceback

from flask import Flask, jsonify, request, send_from_directory

from model import loader as model_loader
from schemas import validate_patient_input

try:
    from flask_cors import CORS

    _HAS_FLASK_CORS = True
except ImportError:
    _HAS_FLASK_CORS = False

_LOGGER = logging.getLogger(__name__)

_API_DIR = os.path.dirname(os.path.abspath(__file__))
_FRONT_DIR = os.path.abspath(os.path.join(_API_DIR, "..", "front"))

app = Flask(__name__, static_folder=_FRONT_DIR, static_url_path="/static")

if _HAS_FLASK_CORS:
    CORS(app)
else:

    @app.after_request
    def _add_cors_headers(response):
        response.headers["Access-Control-Allow-Origin"] = "*"
        response.headers["Access-Control-Allow-Headers"] = "Content-Type"
        response.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
        return response


def _load_model_or_none():
    """Tenta carregar o modelo; retorna None e registra aviso se falhar."""
    try:
        return model_loader.load_model()
    except FileNotFoundError as exc:
        msg = f"Aviso: modelo não encontrado — {exc}. A API iniciará sem modelo carregado."
        print(msg, file=sys.stderr, flush=True)
        _LOGGER.warning("Modelo não encontrado no startup: %s", exc)
        return None


MODEL = _load_model_or_none()


@app.route("/")
def index():
    """Serve a página inicial do frontend."""
    return send_from_directory(_FRONT_DIR, "index.html")


@app.route("/static/<path:filename>")
def static_files(filename):
    """Serve arquivos estáticos do diretório front."""
    return send_from_directory(_FRONT_DIR, filename)


@app.route("/api/predict", methods=["POST", "OPTIONS"])
def predict():
    """Recebe JSON do paciente e retorna predição do modelo."""
    if request.method == "OPTIONS":
        return ("", 204)

    try:
        payload = request.get_json(silent=True)
        cleaned, errors = validate_patient_input(payload)

        if errors:
            return (
                jsonify(
                    {
                        "error": "Dados inválidos",
                        "details": errors,
                    }
                ),
                400,
            )

        if MODEL is None:
            return (
                jsonify({"error": "Modelo não carregado"}),
                500,
            )

        result = model_loader.predict(MODEL, cleaned)
        return jsonify(result), 200

    except Exception:
        _LOGGER.exception("Erro ao processar predição")
        return (
            jsonify(
                {
                    "error": "Erro interno do servidor",
                    "details": traceback.format_exc()
                    if app.debug
                    else None,
                }
            ),
            500,
        )


@app.errorhandler(400)
def bad_request(_error):
    """Resposta JSON para requisição inválida."""
    return jsonify({"error": "Requisição inválida"}), 400


@app.errorhandler(404)
def not_found(_error):
    """Resposta JSON para recurso não encontrado."""
    return jsonify({"error": "Recurso não encontrado"}), 404


@app.errorhandler(500)
def internal_error(_error):
    """Resposta JSON para erro interno."""
    return jsonify({"error": "Erro interno do servidor"}), 500


def _first_free_port(preferred: int, attempts: int = 40) -> int:
    """Retorna a primeira porta livre a partir de *preferred* (inclusive)."""
    for port in range(preferred, preferred + attempts):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            try:
                sock.bind(("0.0.0.0", port))
            except OSError:
                continue
            return port
    raise RuntimeError(
        f"Nenhuma porta livre entre {preferred} e {preferred + attempts - 1}."
    )


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    preferred = int(os.environ.get("PORT", "5000"))
    port = _first_free_port(preferred)
    if port != preferred:
        print(
            f"Aviso: porta {preferred} em uso; usando {port}. "
            "No macOS, a 5000 costuma ser o AirPlay Receiver (Ajustes do Sistema). "
            "Para fixar uma porta: export PORT=5001 (antes de iniciar).",
            file=sys.stderr,
            flush=True,
        )
    app.run(host="0.0.0.0", port=port, debug=True)
