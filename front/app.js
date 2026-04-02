document.addEventListener('DOMContentLoaded', function () {
  const form = document.getElementById('predict-form');
  const submitBtn = document.getElementById('submit-btn');
  const loadingIndicator = document.getElementById('loading-indicator');
  const errorArea = document.getElementById('error-area');
  const resultArea = document.getElementById('result-area');
  const resultInner = document.getElementById('result-inner');
  const resultLabel = document.getElementById('result-label');
  const resultConfidence = document.getElementById('result-confidence');
  const resultIcon = document.getElementById('result-icon');

  if (!form) return;

  form.addEventListener('submit', function (event) {
    handleSubmit(event);
  });

  function handleSubmit(event) {
    event.preventDefault();

    const data = collectFormData();
    const errors = validateForm(data);

    hideResult();
    hideErrors();

    if (errors.length > 0) {
      displayErrors(errors);
      return;
    }

    const payload = { ...data };
    if (payload.bmi === null) {
      delete payload.bmi;
    }

    setLoading(true);

    fetch('/api/predict', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    })
      .then(function (response) {
        return response.json().then(function (body) {
          return { ok: response.ok, status: response.status, body: body };
        });
      })
      .then(function ({ ok, status, body }) {
        if (ok && body.prediction !== undefined) {
          displayResult(body);
          return;
        }
        if (body.details && typeof body.details === 'object' && !Array.isArray(body.details)) {
          const fieldErrors = [];
          Object.keys(body.details).forEach(function (key) {
            fieldErrors.push(String(body.details[key]));
          });
          if (fieldErrors.length) {
            displayErrors(fieldErrors, body.error);
            return;
          }
        }
        const msg =
          body.error ||
          (status === 400 ? 'Dados inválidos. Verifique o formulário.' : 'Erro ao obter predição. Tente novamente.');
        displayErrors([msg]);
      })
      .catch(function () {
        displayErrors(['Não foi possível conectar ao servidor. Verifique se o serviço está em execução.']);
      })
      .finally(function () {
        setLoading(false);
      });
  }

  function collectFormData() {
    const gender = document.getElementById('gender').value.trim();
    const ageRaw = document.getElementById('age').value.trim();
    const hypertensionEl = document.querySelector('input[name="hypertension"]:checked');
    const heartEl = document.querySelector('input[name="heart_disease"]:checked');
    const everMarried = document.getElementById('ever_married').value.trim();
    const workType = document.getElementById('work_type').value.trim();
    const residenceType = document.getElementById('residence_type').value.trim();
    const glucoseRaw = document.getElementById('avg_glucose_level').value.trim();
    const bmiRaw = document.getElementById('bmi').value.trim();
    const smoking = document.getElementById('smoking_status').value.trim();

    return {
      gender: gender,
      age: ageRaw === '' ? NaN : parseFloat(ageRaw),
      hypertension: hypertensionEl ? parseInt(hypertensionEl.value, 10) : null,
      heart_disease: heartEl ? parseInt(heartEl.value, 10) : null,
      ever_married: everMarried,
      work_type: workType,
      residence_type: residenceType,
      avg_glucose_level: glucoseRaw === '' ? NaN : parseFloat(glucoseRaw),
      bmi: bmiRaw === '' ? null : parseFloat(bmiRaw),
      smoking_status: smoking,
    };
  }

  function validateForm(data) {
    const err = [];

    if (!data.gender) err.push('Selecione o sexo.');
    if (data.age === '' || Number.isNaN(data.age)) err.push('Informe uma idade válida.');
    else if (data.age <= 0) err.push('A idade deve ser maior que zero.');
    else if (data.age > 150) err.push('A idade não pode ser superior a 150.');

    if (data.hypertension !== 0 && data.hypertension !== 1) {
      err.push('Indique se há hipertensão (Sim ou Não).');
    }
    if (data.heart_disease !== 0 && data.heart_disease !== 1) {
      err.push('Indique se há doença cardíaca (Sim ou Não).');
    }

    if (!data.ever_married) err.push('Selecione se já foi casado(a).');
    if (!data.work_type) err.push('Selecione o tipo de trabalho.');
    if (!data.residence_type) err.push('Selecione o tipo de residência.');

    if (data.avg_glucose_level === '' || Number.isNaN(data.avg_glucose_level)) {
      err.push('Informe a glicemia média.');
    } else if (data.avg_glucose_level <= 0) {
      err.push('A glicemia média deve ser maior que zero.');
    }

    if (data.bmi !== null) {
      if (Number.isNaN(data.bmi)) err.push('O IMC informado não é um número válido.');
      else if (data.bmi <= 0) err.push('O IMC, se informado, deve ser maior que zero.');
    }

    if (!data.smoking_status) err.push('Selecione o status de tabagismo.');

    return err;
  }

  function displayResult(result) {
    const pred = result.prediction;
    resultArea.hidden = false;
    resultArea.classList.remove('result-baixo-risco', 'result-alto-risco');

    if (pred === 1) {
      resultArea.classList.add('result-alto-risco');
      resultIcon.innerHTML =
        '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2" aria-hidden="true"><path stroke-linecap="round" stroke-linejoin="round" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/></svg>';
    } else {
      resultArea.classList.add('result-baixo-risco');
      resultIcon.innerHTML =
        '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2" aria-hidden="true"><path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>';
    }

    const labelText =
      result.prediction_label ||
      (pred === 1 ? 'Alto Risco de AVC' : 'Baixo Risco');
    resultLabel.textContent = labelText;

    if (result.confidence != null && typeof result.confidence === 'number' && !Number.isNaN(result.confidence)) {
      const pct = Math.round(result.confidence * 1000) / 10;
      resultConfidence.textContent = 'Confiança: ' + pct + '%';
      resultConfidence.hidden = false;
    } else {
      resultConfidence.textContent = '';
      resultConfidence.hidden = true;
    }

    resultArea.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
  }

  function displayErrors(errors, generalTitle) {
    errorArea.hidden = false;
    const list = errors.map(function (e) {
      return '<li>' + escapeHtml(e) + '</li>';
    }).join('');
    const title =
      generalTitle && String(generalTitle).trim()
        ? '<p class="error-title">' + escapeHtml(String(generalTitle)) + '</p>'
        : '<p class="error-title">Corrija os seguintes pontos:</p>';
    errorArea.innerHTML = title + '<ul>' + list + '</ul>';
    errorArea.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
  }

  function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  function hideErrors() {
    errorArea.hidden = true;
    errorArea.innerHTML = '';
  }

  function hideResult() {
    resultArea.hidden = true;
    resultArea.classList.remove('result-baixo-risco', 'result-alto-risco');
    resultLabel.textContent = '';
    resultConfidence.textContent = '';
    resultConfidence.hidden = true;
    resultIcon.innerHTML = '';
  }

  function setLoading(isLoading) {
    submitBtn.disabled = isLoading;
    loadingIndicator.hidden = !isLoading;
    submitBtn.textContent = isLoading ? 'Processando…' : 'Prever Risco de AVC';
  }
});
