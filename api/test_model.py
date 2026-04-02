"""
Testes automatizados para validação do modelo de predição de AVC.
Atua como gate de implantação: o modelo só pode ser utilizado se
todos os testes passarem.
"""
import os

import joblib
import numpy as np
import pandas as pd
import pytest
from sklearn.metrics import accuracy_score, f1_score, recall_score
from sklearn.model_selection import train_test_split

ACCURACY_THRESHOLD = 0.70
RECALL_THRESHOLD = 0.50
F1_THRESHOLD = 0.30

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.path.join(BASE_DIR, "model", "modelo_treinado.pkl")
DATA_PATH = os.path.join(BASE_DIR, "..", "data", "healthcare-dataset-stroke-data.csv")

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


@pytest.fixture
def loaded_model():
    """Carrega o modelo serializado."""
    if not os.path.exists(MODEL_PATH):
        pytest.skip("Modelo não encontrado. Execute o notebook primeiro.")
    return joblib.load(MODEL_PATH)


@pytest.fixture
def test_data():
    """Prepara dados de teste usando o mesmo split do notebook."""
    if not os.path.exists(DATA_PATH):
        pytest.skip("Dataset não encontrado.")
    df = pd.read_csv(DATA_PATH)
    df = df.drop(columns=["id"])
    X = df[FEATURE_COLUMNS]
    y = df["stroke"]
    _, X_test, _, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )
    return X_test, y_test


def test_model_accuracy_above_threshold(loaded_model, test_data):
    """Verifica se a acurácia do modelo está acima do threshold mínimo."""
    X_test, y_test = test_data
    y_pred = loaded_model.predict(X_test)
    accuracy = accuracy_score(y_test, y_pred)
    assert accuracy >= ACCURACY_THRESHOLD, (
        f"Acurácia {accuracy:.4f} abaixo do threshold {ACCURACY_THRESHOLD}"
    )


def test_model_recall_above_threshold(loaded_model, test_data):
    """Verifica se o recall para AVC (classe 1) está acima do threshold."""
    X_test, y_test = test_data
    y_pred = loaded_model.predict(X_test)
    recall = recall_score(y_test, y_pred, pos_label=1, zero_division=0)
    assert recall >= RECALL_THRESHOLD, (
        f"Recall {recall:.4f} abaixo do threshold {RECALL_THRESHOLD}"
    )


def test_model_f1_above_threshold(loaded_model, test_data):
    """Verifica se o F1-score para AVC (classe 1) está acima do threshold."""
    X_test, y_test = test_data
    y_pred = loaded_model.predict(X_test)
    f1 = f1_score(y_test, y_pred, pos_label=1, zero_division=0)
    assert f1 >= F1_THRESHOLD, (
        f"F1-score {f1:.4f} abaixo do threshold {F1_THRESHOLD}"
    )


def test_model_predicts_valid_classes(loaded_model, test_data):
    """Verifica se o modelo retorna apenas classes válidas (0 ou 1)."""
    X_test, _ = test_data
    y_pred = loaded_model.predict(X_test)
    unique_classes = set(y_pred)
    assert unique_classes.issubset({0, 1}), (
        f"Classes inválidas: {unique_classes - {0, 1}}"
    )


def test_model_handles_all_features(loaded_model):
    """Verifica se o pipeline aceita todas as features esperadas."""
    sample = pd.DataFrame([{
        "gender": "Male",
        "age": 50.0,
        "hypertension": 0,
        "heart_disease": 0,
        "ever_married": "Yes",
        "work_type": "Private",
        "Residence_type": "Urban",
        "avg_glucose_level": 100.0,
        "bmi": 25.0,
        "smoking_status": "never smoked",
    }])
    prediction = loaded_model.predict(sample)
    assert prediction is not None
    assert len(prediction) == 1


def test_model_handles_missing_bmi(loaded_model):
    """Verifica se o pipeline lida com BMI ausente (NaN) via imputação."""
    sample = pd.DataFrame([{
        "gender": "Female",
        "age": 60.0,
        "hypertension": 1,
        "heart_disease": 0,
        "ever_married": "Yes",
        "work_type": "Self-employed",
        "Residence_type": "Rural",
        "avg_glucose_level": 150.0,
        "bmi": np.nan,
        "smoking_status": "formerly smoked",
    }])
    prediction = loaded_model.predict(sample)
    assert prediction is not None
    assert len(prediction) == 1
    assert prediction[0] in [0, 1]
