"""Carregamento do modelo serializado e inferência para o StrokeGuard MVP."""

import os

import joblib
import numpy as np
import pandas as pd

MODEL_PATH = os.path.join(os.path.dirname(__file__), "modelo_treinado.pkl")

FEATURE_COLUMNS = [
    "gender",
    "age",
    "hypertension",
    "heart_disease",
    "ever_married",
    "work_type",
    "Residence_type",
    "avg_glucose_level",
    "bmi",
    "smoking_status",
]


def load_model(path=None):
    """Carrega o pipeline de ML serializado do disco.

    Args:
        path: Caminho opcional para o arquivo .pkl. Usa MODEL_PATH se omitido.

    Returns:
        Objeto pipeline carregado pelo joblib.

    Raises:
        FileNotFoundError: Se o arquivo do modelo não existir.
    """
    model_path = path or MODEL_PATH
    if not os.path.exists(model_path):
        raise FileNotFoundError(f"Modelo não encontrado: {model_path}")
    return joblib.load(model_path)


def predict(pipeline, patient_data: dict) -> dict:
    """Executa predição com o pipeline carregado e dados do paciente.

    Args:
        pipeline: Pipeline sklearn carregado.
        patient_data: Dicionário com as features do paciente (nomes das colunas
            do modelo).

    Returns:
        Dicionário com prediction (int), prediction_label (str) e confidence
        (float ou None).
    """
    df = pd.DataFrame([patient_data], columns=FEATURE_COLUMNS)

    if "bmi" in df.columns and (
        df["bmi"].isna().any() or df["bmi"].iloc[0] is None
    ):
        df["bmi"] = np.nan

    prediction = int(pipeline.predict(df)[0])

    confidence = None
    if hasattr(pipeline, "predict_proba"):
        try:
            probas = pipeline.predict_proba(df)[0]
            confidence = round(float(probas[prediction]), 4)
        except (AttributeError, IndexError, TypeError, ValueError):
            confidence = None

    label = "Alto Risco de AVC" if prediction == 1 else "Baixo Risco"

    return {
        "prediction": prediction,
        "prediction_label": label,
        "confidence": confidence,
    }
