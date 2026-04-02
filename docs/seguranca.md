# Reflexão sobre Segurança e Anonimização de Dados

**Projeto**: StrokeGuard MVP — Predição de Risco de AVC
**Data**: 2026-04-02

## 1. Introdução

O projeto StrokeGuard utiliza dados de saúde de pacientes para treinar
um modelo de machine learning capaz de prever o risco de Acidente
Vascular Cerebral (AVC). Esses dados incluem informações demográficas e
clínicas que, em contextos reais, seriam consideradas **dados pessoais
sensíveis** nos termos da Lei Geral de Proteção de Dados (LGPD, Lei
nº 13.709/2018) e do Health Insurance Portability and Accountability
Act (HIPAA).

Este documento reflete sobre as boas práticas de desenvolvimento
seguro e técnicas de anonimização de dados aplicáveis ao problema,
conforme estudado na disciplina de Desenvolvimento de Software Seguro.

## 2. Dados Sensíveis Identificados

O Stroke Prediction Dataset contém os seguintes atributos que
constituem Informação de Saúde Protegida (PHI — Protected Health
Information):

| Atributo | Tipo | Sensibilidade |
|----------|------|--------------|
| `age` | Numérico | Identificação indireta — pode, em combinação com outros campos, identificar um indivíduo |
| `gender` | Categórico | Dado pessoal protegido pela LGPD (Art. 5º, II) |
| `hypertension` | Binário | Dado de saúde — categoria especial de dados pessoais (LGPD Art. 11) |
| `heart_disease` | Binário | Dado de saúde — requer consentimento específico para tratamento |
| `avg_glucose_level` | Numérico | Indicador clínico — dado de saúde sensível |
| `bmi` | Numérico | Indicador clínico derivado de medidas corporais |
| `smoking_status` | Categórico | Hábito de saúde — informação médica protegida |

Além destes, o campo `stroke` (variável alvo) é, por definição,
um diagnóstico médico e constitui dado de saúde nos termos mais
restritos da legislação.

### Marco Legal

- **LGPD (Brasil)**: Dados de saúde são classificados como "dados
  pessoais sensíveis" (Art. 5º, II) e seu tratamento exige base legal
  específica (Art. 11), como consentimento explícito ou tutela da
  saúde.
- **HIPAA (EUA)**: Informações de saúde individualmente
  identificáveis (PHI) estão sujeitas a proteções rigorosas de
  privacidade e segurança.

## 3. Proveniência do Dataset

O dataset utilizado neste projeto é o **Stroke Prediction Dataset**,
disponível publicamente no Kaggle (por fedesoriano). Características
relevantes para a análise de segurança:

- **Dados públicos**: O dataset é de acesso livre, sem restrições de
  licença para uso acadêmico.
- **Identificadores sintéticos**: O campo `id` é um identificador
  numérico sequencial atribuído ao dataset, **não** correspondendo a
  identificadores reais de pacientes.
- **Sem informações diretamente identificáveis**: O dataset não
  contém nomes, endereços, CPFs, números de prontuário ou qualquer
  outro identificador direto.
- **Limitações**: Embora os identificadores diretos tenham sido
  removidos, a combinação de atributos quasi-identificadores (idade,
  gênero, tipo de residência) pode, em teoria, permitir a
  reidentificação em populações pequenas.

## 4. Técnicas de Anonimização Aplicáveis

Embora o dataset já seja público e não contenha identificadores
diretos, é importante demonstrar conhecimento sobre técnicas que
seriam aplicadas em um cenário com dados reais:

### 4.1 K-Anonimidade

Garantir que cada combinação de quasi-identificadores apareça em pelo
menos *k* registros. Aplicação prática:

- **Idade**: Substituir valores exatos por faixas etárias (0-18,
  19-35, 36-50, 51-65, 66+).
- **IMC**: Categorizar em faixas (abaixo do peso, normal, sobrepeso,
  obeso) em vez de manter valores contínuos.
- **Glicose**: Agrupar em níveis (normal, pré-diabético, diabético).

### 4.2 Mascaramento de Dados

Substituir valores reais por representações que preservam a
utilidade analítica sem expor informações individuais:

- Substituir valores exatos de idade por faixas.
- Arredondar valores de glicose e IMC para inteiros.
- Substituir valores de tabagismo por categorias binárias (fumante /
  não fumante) quando a granularidade detalhada não for necessária.

### 4.3 Privacidade Diferencial

Adicionar ruído calibrado às estatísticas agregadas para impedir a
inferência de informações sobre indivíduos específicos:

- Aplicar mecanismos de Laplace ou Gaussiano ao calcular médias e
  distribuições para relatórios.
- Garantir que a presença ou ausência de um único registro não
  altere significativamente os resultados publicados.

### 4.4 Pseudonimização

Substituir identificadores por tokens reversíveis apenas com uma
chave secreta:

- Substituir o campo `id` por um hash criptográfico com salt.
- Manter a chave de mapeamento em ambiente seguro e separado dos
  dados pseudonimizados.

### 4.5 Generalização

Reduzir a granularidade dos dados para dificultar a identificação:

- Substituir `Residence_type` (Rural/Urban) por regiões geográficas
  mais amplas.
- Generalizar `work_type` em menos categorias (empregado/desempregado
  /menor de idade).

## 5. Boas Práticas de Desenvolvimento Seguro Aplicadas

As seguintes práticas foram implementadas ou consideradas no
desenvolvimento do StrokeGuard MVP:

### 5.1 Validação de Entrada

Toda entrada recebida pelo endpoint `POST /api/predict` é validada
antes de ser processada pelo modelo:

- Verificação de campos obrigatórios.
- Validação de tipos (numérico, enum).
- Validação de faixas aceitáveis (idade ≥ 0, glicose > 0).
- Rejeição de valores não reconhecidos nas categorias.

Isso previne ataques de injeção e evita comportamentos inesperados
do modelo ao receber dados malformados.

### 5.2 API Stateless

A aplicação Flask não armazena dados de predição:

- Nenhum dado de paciente é persistido em banco de dados ou arquivo.
- Cada requisição é processada e descartada.
- Não há sessões de usuário nem cookies com dados sensíveis.

### 5.3 Ausência de Dados Sensíveis em Logs

A aplicação foi projetada para **não registrar** dados de pacientes
nos logs do sistema:

- Logs registram apenas eventos operacionais (startup, erros
  genéricos).
- Dados de entrada e saída de predições não são incluídos em
  mensagens de log.

### 5.4 Dependências Controladas

O arquivo `requirements.txt` utiliza versões mínimas e máximas
fixas para todas as dependências:

```
flask>=3.0,<4.0
scikit-learn>=1.4,<2.0
```

Essa prática mitiga ataques à cadeia de suprimentos (supply chain
attacks), onde versões maliciosas de pacotes são publicadas.

### 5.5 HTTPS em Produção

Embora o MVP rode em `localhost` para fins acadêmicos, em um
ambiente de produção é **obrigatório** o uso de HTTPS para
criptografar a comunicação entre cliente e servidor, protegendo os
dados de pacientes em trânsito.

### 5.6 Princípio do Menor Privilégio

A aplicação acessa apenas os recursos estritamente necessários:

- Leitura do arquivo do modelo (somente leitura).
- Servir arquivos estáticos do front-end.
- Nenhum acesso a banco de dados, sistema de arquivos adicional ou
  serviços externos.

## 6. Conclusão

Embora o StrokeGuard MVP utilize um dataset público que não contém
identificadores reais de pacientes, a reflexão sobre segurança e
anonimização é essencial para demonstrar consciência sobre as
responsabilidades envolvidas no tratamento de dados de saúde.

Em um cenário de produção, as seguintes ações adicionais seriam
recomendadas:

1. **Avaliação de Impacto à Proteção de Dados (DPIA/RIPD)**:
   Realizar antes do tratamento de dados reais.
2. **Consentimento informado**: Obter consentimento explícito dos
   pacientes conforme LGPD Art. 11.
3. **Criptografia em repouso**: Criptografar qualquer dado de saúde
   armazenado.
4. **Auditoria e monitoramento**: Implementar logs de acesso
   auditáveis sem expor dados sensíveis.
5. **Treinamento da equipe**: Capacitar desenvolvedores sobre LGPD
   e melhores práticas de segurança para dados de saúde.
6. **Revisão periódica**: Realizar auditorias regulares de segurança
   e atualizar dependências.

A segurança de dados não é uma funcionalidade opcional — é um
requisito fundamental para qualquer sistema que manipule informações
de saúde.
