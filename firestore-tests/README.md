# Testes comportamentais do Firestore (regras + Cloud Function de vínculo)

Testa `../firestore.rules` e a Cloud Function `linkToProfessional`
(`../functions/src/linking.ts`) rodando operações de verdade contra o
**Firestore Emulator** — nunca contra o Firestore de produção. Complementa
(não substitui) os testes de texto em
`../test/unit/firestore_rules_test.dart` (que só confere que certas linhas
existem no arquivo de regras, sem executar nada).

## Pré-requisitos

- **Java 21+** (o Firestore Emulator precisa de uma JVM). Se `java -version`
  não funcionar, baixe um JDK portátil sem precisar de admin:
  ```bash
  curl -L -o temurin21.zip "https://api.adoptium.net/v3/binary/latest/21/ga/windows/x64/jdk/hotspot/normal/eclipse"
  # extrair (ex: com Expand-Archive do PowerShell) para alguma pasta, ex: ~/.jdks/
  export JAVA_HOME="$HOME/.jdks/jdk-21.x.x.x+x"
  export PATH="$JAVA_HOME/bin:$PATH"
  ```
- Node 20+ (usa o test runner nativo `node --test`, sem depender de
  jest/mocha).
- `functions/lib/linking.js` compilado: rode `npm run build` dentro de
  `functions/` antes de testar a Cloud Function (só afeta
  `linking-function.test.js`; `rules.test.js` não depende disso).

## Instalar e rodar

```bash
cd firestore-tests
npm install          # só na primeira vez (ou quando package.json mudar)

# Jeito mais simples (sobe os emuladores, roda e desliga), da raiz do projeto:
firebase emulators:exec --only firestore,storage --project demo-newfitness-rules-test "cd firestore-tests && npm test"

# Ou manualmente — num terminal, com Java no PATH:
firebase emulators:start --only firestore,storage --project demo-newfitness-rules-test
# espera aparecer "All emulators ready!" (Firestore 8080, Storage 9199)
# Noutro terminal:
cd firestore-tests
npm test             # roda os 9 arquivos, um de cada vez
```

Os arquivos rodam **em sequência** (`--test-concurrency=1`) de propósito:
todos usam o mesmo projeto no emulador e cada teste limpa os dados
(`clearFirestore`), então rodar em paralelo faz um arquivo apagar os dados
do outro no meio do teste (falhas aleatórias).

## O que cada arquivo cobre

- **`rules.test.js`** — 27 casos usando `@firebase/rules-unit-testing`
  (`initializeTestEnvironment`, `authenticatedContext`,
  `unauthenticatedContext`, `assertSucceeds`/`assertFails`): aluno lendo/
  editando o próprio perfil e tentando escalar privilégio (`role`,
  `instructorId`, `nutritionistId`, `inviteCode`), isolamento entre alunos,
  `workouts`/`progress_records`, escopo de acesso do instrutor (só alunos
  vinculados, nunca escreve `role`/vínculo), e CRUD do admin em
  `muscle_groups`/`equipment`/`exercises`.
- **`linking-function.test.js`** — chama `linkToProfessional.run({data, auth})`
  diretamente (mecanismo oficial do `firebase-functions` v2 pra testar um
  callable sem precisar do Functions Emulator), com o Admin SDK apontado pro
  Firestore Emulator via `FIRESTORE_EMULATOR_HOST`: código válido/inválido,
  não-autenticado, chamador com role diferente de `student`, código de um
  usuário com role errado, e que o vínculo grava dos dois lados
  (`instructorId` + `users/{profissional}/students/{aluno}`).

- **`evolution.test.js`** — etapa de Evolução Física: `physical_assessments`
  (aluno cria/edita só o que é dele, não finge ser o instrutor, não muda
  autor/origem/criação; instrutor vinculado lança e edita só o que lançou;
  não vinculado não lê; nutricionista só lê; admin lê/apaga; avaliações
  antigas sem autor continuam funcionando; campos fora da lista/valores
  inválidos recusados) e fotos de evolução em `body_photos` **e no
  Storage** (dono envia só imagem até 10 MB; instrutor/nutricionista
  vinculados só leem; admin e outros alunos não leem).

- **`invite-and-links.test.js`** — código de convite só emitido pelo
  backend (`ensureInviteCode`): cliente não define/altera o código, códigos
  únicos e bem formados, reservas inacessíveis, código copiado não dá
  acesso nem desvia vínculos, códigos antigos duplicados recusados. E troca
  de instrutor: a lista (consulta `users where instructorId == eu`) segue o
  vínculo atual, o instrutor antigo perde o acesso, o novo só acessa o que
  as regras permitem e o histórico do aluno é preservado.

- **`consistency.test.js`** — estatísticas do admin via `getAdminStats`
  (só o admin obtém; aluno/instrutor/nutricionista recebem
  permission-denied); troca e desvinculação de instrutor e de
  nutricionista (`linkToProfessional`/`unlinkFromProfessional`) com o
  efeito real nas regras do Firestore e do Storage (profissional antigo
  perde acesso, inclusive à agenda; novo ganha só após o vínculo; histórico
  preservado; entrada antiga em `students` não concede acesso); conversa de
  nutrição (ninguém forja `assistant`, cada um só cria o próprio papel,
  mensagens imutáveis, resposta da IA gravada pelo servidor). Usa o mesmo
  projectId do emulador porque as regras do Storage consultam o Firestore.

- **`audit.test.js`** — regressões da auditoria funcional: curtir um aviso
  da Timeline só acrescenta/remove o próprio uid (não apaga nem inventa
  curtidas de outras pessoas, nem altera outros campos).

- **`demotion.test.js`** — rebaixamento de instrutor pela Cloud Function
  `setUserRole`: todos os vínculos de instrutor encerrados (em lotes,
  idempotente, com trava contra vínculos novos durante o processo),
  histórico dos alunos preservado, vínculos de nutrição intactos, ex-
  instrutor sem acesso a nada (Firestore e Storage) mesmo reativando
  `students` à mão, só admin chama a Function, ninguém grava `role`
  direto (nem o admin), e voltar a ser instrutor não restaura vínculos.

- **`workout-prescription.test.js`** — não-regressão da prescrição do plano
  no treino: um treino com `prescription`/`source` é aceito pelas regras
  existentes de `workouts` (dono grava e lê, instrutor vinculado lê,
  não vinculados não).

- **`professional-requests.test.js`** — aprovação de profissionais: o
  cliente só cria perfil de aluno e ninguém apaga perfil (fecha a
  autopromoção por apagar-e-recriar); pedido `professional_requests/{uid}`
  validado (name/email não forjáveis, registro e região do CREF/CRN,
  horário do servidor, só "pending"); só o admin decide pela Function
  `reviewProfessionalRequest` (papel e status gravados juntos, recusa com
  motivo obrigatório, histórico, idempotência, pedir de novo). Nas suítes
  `invite-and-links` e `consistency`, profissionais passaram a ser criados
  pelo Admin SDK (o cliente não cria mais perfil de profissional).

## Dados usados

100% fictícios (`student1`, `instructor1`, `ana@x.com` etc.), criados e
apagados a cada teste (`clearFirestore`) só dentro do emulador local. Nada
disto toca o projeto Firebase real — `initializeTestEnvironment`/
`admin.initializeApp` usam `projectId: 'demo-...'`, que o emulador trata como
um projeto "de mentira" isolado.

## Não commitar

`node_modules/` e os `*-debug.log` do emulador (ver `.gitignore` desta
pasta).
