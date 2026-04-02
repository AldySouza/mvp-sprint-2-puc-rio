# StrokeGuard MVP — Predição de Risco de AVC

Sistema de classificação de risco de Acidente Vascular Cerebral (AVC)
utilizando Machine Learning, desenvolvido como MVP para a PUC-Rio.

## Visão Geral

O projeto é composto por três componentes principais:

1. **Notebook de ML** — Pipeline completo de ciência de dados em Google Colab
2. **Aplicação Full Stack** — Back-end Flask + Front-end HTML/CSS/JS
3. **Testes Automatizados** — Gate de implantação com PyTest

### Arquitetura

```
┌──────────────┐     joblib.dump      ┌──────────────────┐
│  Colab       │ ──────────────────→  │  modelo_         │
│  Notebook    │   modelo_treinado    │  treinado.pkl    │
│  (ML Pipeline)│      .pkl           └────────┬─────────┘
└──────────────┘                               │
                                    joblib.load │
                                               ▼
┌──────────────┐   POST /api/predict  ┌──────────────────┐
│  Front-end   │ ──────────────────→  │  Flask Back-end  │
│  (HTML/JS)   │ ←────────────────── │  (api/app.py)    │
│              │   JSON response      │  + modelo embarcado│
└──────────────┘                      └──────────────────┘
                                               │
                                    pytest      │
                                               ▼
                                      ┌──────────────────┐
                                      │  test_model.py   │
                                      │  (deployment gate)│
                                      └──────────────────┘
```

## Notebook de Machine Learning

**Link do Colab**: *[TODO: Adicionar link após salvar cópia no GitHub]*

O notebook implementa as seguintes etapas:
- Carga de dados via URL raw do GitHub (Stroke Prediction Dataset)
- Análise exploratória (distribuição de classes, valores ausentes)
- Separação treino/teste com holdout estratificado
- Demonstração de normalização (MinMaxScaler) e padronização (StandardScaler)
- Pipeline de pré-processamento (ColumnTransformer)
- Treinamento e comparação de 4 algoritmos: **KNN**, **Árvore de Decisão**, **Naive Bayes**, **SVM**
- Otimização de hiperparâmetros com **GridSearchCV** e **StratifiedKFold**
- Análise final de resultados e exportação do melhor modelo

## Como Executar

### Pré-requisitos

- Python 3.10 ou superior
- pip (gerenciador de pacotes Python)
- Conta Google (para o notebook Colab)

### 1. Clonar o repositório

```bash
git clone https://github.com/AldySouza/mvp-sprint-2-puc-rio.git
cd mvp-sprint-2-puc-rio
```

### 2. Executar o Notebook (Colab)

1. Abra o link do Colab --> https://colab.research.google.com/drive/1HlDI4orCt7JiwtrWDoHBWtVIN3ly8GbB?usp=sharing
2. Execute **Runtime → Run All**
3. Aguarde a conclusão (~5-10 min em CPU)
4. O modelo será exportado como `modelo_treinado.pkl`
5. Baixe o `.pkl` e coloque em `api/model/`

### 3. Início rápido (recomendado)

Os passos 4, 5 e 6 abaixo podem ser substituídos pelo script de inicialização,
que cria o ambiente virtual, instala as dependências e inicia o servidor
automaticamente:

```bash
# Linux / macOS
chmod +x start.sh
./start.sh

# Windows
start.bat
```

### 4. Configurar o Back-end

```bash
cd api
python -m venv venv
source venv/bin/activate  # Linux/macOS
pip install -r requirements.txt
```

### 5. Rodar os Testes (Gate de Implantação)

Assim como o `start`, há um script que configura o ambiente e executa os testes automaticamente:

```bash
# Linux / macOS
./test.sh

# Windows
test.bat
```

Ou, se preferir rodar manualmente (com o venv ativado):

```bash
pytest test_model.py -v
```

Todos os testes devem passar para que o modelo seja considerado apto.

### 6. Iniciar a Aplicação

```bash
python app.py
```

Acesse: **http://localhost:5000**

## Estrutura do Projeto

```
mvp-sprint-2-puc-rio/
├── notebook/
│   └── StrokeGuard_ML.ipynb        # Notebook Colab (pipeline ML)
├── api/
│   ├── app.py                      # Aplicação Flask
│   ├── model/
│   │   ├── modelo_treinado.pkl     # Modelo serializado
│   │   └── loader.py               # Utilitário de carga do modelo
│   ├── schemas.py                  # Validação de entrada
│   ├── requirements.txt            # Dependências Python
│   └── test_model.py               # Testes PyTest (deployment gate)
├── front/
│   ├── index.html                  # Formulário de predição
│   ├── styles.css                  # Estilos
│   └── app.js                      # Lógica do front-end
├── data/
│   └── healthcare-dataset-stroke-data.csv
├── docs/
│   └── seguranca.md                # Reflexão sobre segurança
└── README.md                       # Este arquivo
```

## Testes Automatizados

O arquivo `api/test_model.py` implementa um gate de implantação que valida:

| Teste | Métrica | Threshold |
|-------|---------|-----------|
| Acurácia | accuracy_score | ≥ 0.70 |
| Recall (AVC) | recall_score(pos_label=1) | ≥ 0.10 |
| F1-Score (AVC) | f1_score(pos_label=1) | ≥ 0.10 |
| Classes válidas | predict() output | {0, 1} |
| Features completas | Pipeline input | 10 features |
| BMI ausente | NaN handling | Imputação funcional |

Se qualquer teste falhar, o modelo **não deve ser implantado**.

## Segurança e Anonimização

Uma reflexão detalhada sobre boas práticas de desenvolvimento seguro e
técnicas de anonimização de dados aplicáveis ao problema está disponível
em [`docs/seguranca.md`](docs/seguranca.md).

## Vídeo Demonstrativo

*[TODO: Adicionar link do vídeo (máximo 3 minutos)]*

## Tecnologias Utilizadas

- **Python 3.11** — Linguagem principal
- **scikit-learn** — Algoritmos de ML e pipelines
- **Flask** — Framework web (back-end)
- **HTML/CSS/JS** — Interface web (front-end)
- **PyTest** — Testes automatizados
- **joblib** — Serialização do modelo
- **pandas / numpy** — Manipulação de dados
- **Google Colab** — Ambiente de execução do notebook
