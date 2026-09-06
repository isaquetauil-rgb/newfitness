# Cloud Functions — NewFitness

Backend mínimo para o chat com IA e a análise de fotos (refeição/corpo).
Existe **só pra proteger a chave de API** — ela nunca fica no app Flutter,
só aqui no servidor.

## Funções

- `chatWithAI` — recebe uma mensagem de texto (+ histórico opcional) e
  devolve a resposta da IA.
- `analyzeMealPhoto` — recebe uma foto de refeição em base64 e devolve um
  comentário nutricional breve.
- `analyzeBodyPhoto` — recebe uma foto de evolução do corpo em base64 e
  devolve um comentário observacional.

Todas exigem usuário autenticado (Firebase Auth) — chamadas anônimas são
rejeitadas.

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
