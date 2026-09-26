# Cloud Functions — NewFitness

Backend do NewFitness. As funções de IA existem para **proteger a chave
de API** (ela nunca fica no app Flutter) e para controlar o custo.

## Funções de IA (`src/ai.ts`)

- `chatWithAI` — `{ message }`; todos os papéis; grava a resposta em
  `chat_messages`.
- `askNutritionAI` — `{ message }`; só aluno; grava a resposta em
  `nutrition_chat` (busca na web: 1 por pergunta).
- `analyzeMealPhoto` — `{ photoId }`; só o aluno dono; lê a foto do Storage
  e grava `aiAnalysis`/`aiAnalysisError` no documento.
- `suggestTrainingPlan` — `{ prompt, studentUid? }`; só instrutor (aluno,
  se enviado, precisa estar vinculado).

Todas exigem login **com e-mail verificado**, validam a entrada (1–2000
caracteres) e reservam a cota numa transação antes de chamar a IA (ver
`src/ai_guard.ts`). O histórico dos chats é montado pelo servidor (últimas
10 mensagens). Modelos por função: `DEFAULT_MODELS` em `src/anthropic.ts`,
sobrescrevíveis por `AI_MODEL_CHAT`, `AI_MODEL_MEAL_PHOTO`,
`AI_MODEL_NUTRITION` e `AI_MODEL_TRAINING` (ex: em `functions/.env`).
Limites, modelos e custos: seção "Backend de IA" do README principal.

Nos testes (`firestore-tests/ai-functions.test.js`) a Anthropic nunca é
chamada: `setClaudeClient` troca o cliente por um falso.

## Configuração

### 1. Instalar dependências

```bash
cd functions
npm install
```

### 2. Criar sua chave de API da Anthropic

Crie uma conta e uma chave em https://console.anthropic.com (seção "API
Keys"). Guarde a chave — ela só é mostrada uma vez.

### 3. Guardar a chave como *secret* do Firebase

**Nunca** coloque a chave direto no código. Use o gerenciador de secrets:

```bash
firebase functions:secrets:set ANTHROPIC_API_KEY
```

Ele vai pedir pra colar a chave (fica oculta ao digitar/colar).

### 4. Fazer o deploy

Na raiz do projeto (não dentro de `functions/`):

```bash
firebase deploy --only functions
```

Na primeira vez, o Firebase CLI pode pedir para você fazer upgrade do
projeto para o plano **Blaze** (pay-as-you-go) — Cloud Functions que
chamam APIs externas exigem esse plano. O uso típico de um app pessoal
fica dentro da faixa gratuita mensal do Blaze.

### 5. Testar

No app Flutter, a tela de Chat (aba "IA") já está preparada para chamar
`chatWithAI` via `cloud_functions`. Basta estar logado e mandar uma
mensagem.

## Custos e limites (importante)

- Cada chamada ao chat/análise de foto consome créditos da sua conta
  Anthropic — acompanhe o uso em https://console.anthropic.com.
- Para produção, considere adicionar um limite de chamadas por usuário
  por dia (ex: salvando um contador no Firestore e checando antes de
  chamar `callClaude`), para evitar custo inesperado.
