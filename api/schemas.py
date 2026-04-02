"""Validação de entrada da API de predição (StrokeGuard MVP)."""

from typing import Any, Dict, Mapping, MutableMapping, Optional, Tuple

ALLOWED_GENDER = frozenset({"Male", "Female", "Other"})
ALLOWED_EVER_MARRIED = frozenset({"Yes", "No"})
ALLOWED_WORK_TYPE = frozenset(
    {"children", "Govt_job", "Never_worked", "Private", "Self-employed"}
)
ALLOWED_RESIDENCE = frozenset({"Rural", "Urban"})
ALLOWED_SMOKING = frozenset(
    {"formerly smoked", "never smoked", "smokes", "Unknown"}
)

REQUIRED_KEYS = (
    "gender",
    "age",
    "hypertension",
    "heart_disease",
    "ever_married",
    "work_type",
    "avg_glucose_level",
    "smoking_status",
)

RESIDENCE_INPUT_KEYS = ("residence_type", "Residence_type")


def _add_error(errors: MutableMapping[str, str], field: str, message: str) -> None:
    """Registra um erro por campo (mantém apenas a primeira mensagem por campo)."""
    if field not in errors:
        errors[field] = message


def _get_residence_raw(data: Mapping[str, Any]) -> Optional[Any]:
    """Obtém o valor de tipo de residência aceitando chave canônica ou alternativa."""
    for key in RESIDENCE_INPUT_KEYS:
        if key in data:
            return data[key]
    return None


def _validate_binary_int(value: Any, field: str, errors: MutableMapping[str, str]) -> None:
    """Valida inteiro 0 ou 1 (rejeita bool)."""
    if isinstance(value, bool):
        _add_error(
            errors,
            field,
            f"O campo '{field}' deve ser o número inteiro 0 ou 1, não booleano.",
        )
        return
    if isinstance(value, int):
        if value not in (0, 1):
            _add_error(
                errors,
                field,
                f"O campo '{field}' deve ser 0 ou 1.",
            )
        return
    if isinstance(value, float) and value.is_integer() and int(value) in (0, 1):
        return
    _add_error(
        errors,
        field,
        f"O campo '{field}' deve ser o número inteiro 0 ou 1.",
    )


def _coerce_positive_float(
    value: Any,
    field: str,
    errors: MutableMapping[str, str],
    *,
    allow_optional: bool = False,
) -> Optional[float]:
    """Converte para float e exige valor > 0."""
    if value is None and allow_optional:
        return None
    if not isinstance(value, (int, float)) or isinstance(value, bool):
        _add_error(
            errors,
            field,
            f"O campo '{field}' deve ser um número.",
        )
        return None
    fval = float(value)
    if fval <= 0:
        _add_error(
            errors,
            field,
            f"O campo '{field}' deve ser maior que zero.",
        )
        return None
    return fval


def _validate_age(value: Any, errors: MutableMapping[str, str]) -> Optional[float]:
    """Valida idade entre 0 e 150."""
    if not isinstance(value, (int, float)) or isinstance(value, bool):
        _add_error(errors, "age", "O campo 'age' deve ser um número.")
        return None
    fval = float(value)
    if fval < 0 or fval > 150:
        _add_error(
            errors,
            "age",
            "O campo 'age' deve estar entre 0 e 150.",
        )
        return None
    return fval


def _validate_choice(
    value: Any,
    field: str,
    allowed: frozenset,
    errors: MutableMapping[str, str],
    hint: str,
) -> Optional[str]:
    """Valida valor pertencente a um conjunto fixo."""
    if not isinstance(value, str):
        _add_error(
            errors,
            field,
            f"O campo '{field}' deve ser texto ({hint}).",
        )
        return None
    if value not in allowed:
        _add_error(
            errors,
            field,
            f"Valor inválido para '{field}': {hint}.",
        )
        return None
    return value


def validate_patient_input(
    data: Any,
) -> Tuple[Dict[str, Any], Dict[str, str]]:
    """Valida o corpo JSON do paciente e retorna dados limpos e erros.

    Campos obrigatórios: gender, age, hypertension, heart_disease, ever_married,
    work_type, avg_glucose_level, smoking_status e tipo de residência via
    'residence_type' ou 'Residence_type'. O campo 'bmi' é opcional.

    Args:
        data: Dicionário com os dados enviados (tipicamente request.get_json()).

    Returns:
        Tupla (cleaned_data, errors). Se houver erros, cleaned_data é um
        dicionário vazio. Os nomes em cleaned_data seguem as colunas do modelo
        (ex.: 'Residence_type').
    """
    errors: Dict[str, str] = {}

    if data is None:
        return {}, {"_geral": "Corpo da requisição JSON ausente ou inválido."}

    if not isinstance(data, Mapping):
        return {}, {"_geral": "O corpo da requisição deve ser um objeto JSON."}

    for key in REQUIRED_KEYS:
        if key not in data:
            _add_error(
                errors,
                key,
                f"Campo obrigatório ausente: '{key}'.",
            )

    if _get_residence_raw(data) is None:
        _add_error(
            errors,
            "residence_type",
            "Campo obrigatório ausente: 'residence_type' ou 'Residence_type'.",
        )

    if errors:
        return {}, errors

    gender = _validate_choice(
        data["gender"],
        "gender",
        ALLOWED_GENDER,
        errors,
        "use Male, Female ou Other",
    )
    age = _validate_age(data["age"], errors)
    _validate_binary_int(data["hypertension"], "hypertension", errors)
    _validate_binary_int(data["heart_disease"], "heart_disease", errors)
    ever_married = _validate_choice(
        data["ever_married"],
        "ever_married",
        ALLOWED_EVER_MARRIED,
        errors,
        "use Yes ou No",
    )
    work_type = _validate_choice(
        data["work_type"],
        "work_type",
        ALLOWED_WORK_TYPE,
        errors,
        "valores permitidos: children, Govt_job, Never_worked, Private, Self-employed",
    )
    residence_raw = _get_residence_raw(data)
    residence_display_field = (
        "Residence_type"
        if "Residence_type" in data
        else "residence_type"
    )
    residence = _validate_choice(
        residence_raw,
        residence_display_field,
        ALLOWED_RESIDENCE,
        errors,
        "use Rural ou Urban",
    )
    glucose = _coerce_positive_float(
        data["avg_glucose_level"],
        "avg_glucose_level",
        errors,
    )
    smoking = _validate_choice(
        data["smoking_status"],
        "smoking_status",
        ALLOWED_SMOKING,
        errors,
        "valores permitidos: formerly smoked, never smoked, smokes, Unknown",
    )

    bmi_val: Optional[float] = None
    if "bmi" in data and data["bmi"] is not None:
        bmi_val = _coerce_positive_float(data["bmi"], "bmi", errors)

    if errors:
        return {}, errors

    cleaned: Dict[str, Any] = {
        "gender": gender,
        "age": age,
        "hypertension": int(data["hypertension"])
        if isinstance(data["hypertension"], int)
        else int(float(data["hypertension"])),
        "heart_disease": int(data["heart_disease"])
        if isinstance(data["heart_disease"], int)
        else int(float(data["heart_disease"])),
        "ever_married": ever_married,
        "work_type": work_type,
        "Residence_type": residence,
        "avg_glucose_level": glucose,
        "smoking_status": smoking,
    }

    if bmi_val is not None:
        cleaned["bmi"] = bmi_val

    return cleaned, {}
