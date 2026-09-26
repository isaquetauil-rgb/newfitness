# NewFitness

App de treino em Flutter com login, registro de treinos (exercícios/séries/
repetições), cronômetro de descanso, biblioteca de exercícios com vídeo
demonstrativo, histórico com gráfico de progresso e perfil do usuário.

## Arquitetura

O app é organizado **feature-first**, com camadas separadas dentro de cada
feature:

```
lib/
├── main.dart                # bootstrap: runZonedGuarded, Firebase.initializeApp,
│                             # ErrorHandler.init, setupInjector, runApp
├── app/
│   ├── app.dart              # MaterialApp.router + composição dos providers (MultiProvider)
│   ├── routes/
│   │   ├── app_routes.dart   # constantes de caminho (AppRoutes.login, .workout, ...)
│   │   └── app_router.dart   # GoRouter: StatefulShellRoute das abas, redirect de auth
│   ├── theme/app_theme.dart
│   └── widgets/
│       ├── app_shell.dart    # bottom-nav (StatefulShellRoute.indexedStack)
│       └── error_view.dart   # fallback do ErrorWidget.builder
├── core/                     # infraestrutura sem regra de negócio
│   ├── di/injector.dart      # get_it: registra os services como singletons
│   ├── error/                # AppException (hierarquia tipada) + ErrorHandler global
│   ├── logging/app_logger.dart
│   ├── network/functions_client.dart  # chamada de Cloud Functions com erro tratado
│   ├── storage/local_prefs.dart       # SharedPreferences (preferências de UI)
│   └── constants/firestore_paths.dart # nomes de coleção num único lugar
├── shared/
│   ├── models/                # Workout, Exercise, Reminder, UserProfile, etc.
│   │                           # (usados por 2+ features — ficam aqui para não
│   │                           #  criar import cíclico entre features)
│   └── services/               # FirestoreService, StorageService
│                                # (usados por 4+ features)
└── features/
    ├── auth/           data/auth_service.dart · logic/auth_provider.dart ·
    │                    presentation/{login,register,forgot_password}_screen.dart
    ├── home/           presentation/home_dashboard_screen.dart
    ├── profile/        presentation/profile_screen.dart
    ├── notifications/  data/notification_service.dart · logic/reminder_provider.dart ·
    │                    presentation/reminders_screen.dart
    ├── workout/        logic/workout_provider.dart ·
    │                    presentation/{workout_screen,rest_timer_sheet,exercise_picker_screen}.dart
    ├── exercises/      logic/exercise_provider.dart ·
    │                    presentation/{exercise_library_screen,exercise_detail_screen}.dart
    ├── progress/       logic/body_photo_provider.dart ·
    │                    presentation/{progress_screen,body_progress_screen}.dart
    ├── ai/             data/ai_service.dart · logic/{chat_provider,meal_photo_provider}.dart ·
    │                    presentation/{ai_hub_screen,chat_screen,meals_screen}.dart
    └── instructor/     presentation/{instructor_dashboard_screen,student_detail_screen}.dart
```

`firebase_options.dart` fica na raiz de `lib/` (gerado pelo `flutterfire
configure`, não é código do app). `functions/` (Cloud Functions em
TypeScript) é um projeto Node separado, fora de `lib/`.

### Decisões de arquitetura

- **Gerenciamento de estado: `provider`.** Cada feature expõe um
  `ChangeNotifier` em `logic/`, registrado uma vez em `app/app.dart` via
  `MultiProvider`. Não usamos Riverpod/Bloc — `provider` já resolve bem o
  tamanho atual do app, e trocar geraria uma reescrita grande sem ganho
  proporcional agora.
- **Injeção de dependência: `get_it`** (`core/di/injector.dart`), só para
  resolver *quem constrói* os services (`FirestoreService`, `StorageService`,
  `AuthService`, `NotificationService`, `AiService`) como singletons — os
  `ChangeNotifier`s recebem esses services pelo construtor
  (`WorkoutProvider({FirestoreService? firestoreService})`), o que também
  facilita passar mocks nos testes. Isso substitui o padrão anterior de
  cada tela instanciar `FirestoreService()` direto.
- **Navegação: `go_router`**, com `StatefulShellRoute.indexedStack` para a
  barra inferior (cada aba mantém sua própria pilha) e um `redirect` baseado
  em `refreshListenable: authProvider` para proteger as rotas autenticadas —
  substitui o antigo widget `AuthGate` que fazia essa checagem manualmente.
- **Tratamento de erro**: `core/error/app_exception.dart` define uma
  hierarquia tipada (`NetworkException`, `AuthException`,
  `NotFoundException`, `ValidationException`, `UnknownException`).
  `FirestoreService`, `StorageService` e as chamadas de Cloud Functions
  (`core/network/functions_client.dart`, usado por `AiService`) capturam a
  exceção original, logam via `AppLogger` e relançam como `AppException` com
  mensagem amigável. `main.dart` + `core/error/error_handler.dart` capturam
  qualquer erro não tratado (`runZonedGuarded`, `FlutterError.onError`,
  `PlatformDispatcher.onError`, `ErrorWidget.builder`) para nunca mostrar a
  tela vermelha de erro do Flutter em produção.
- **Logging**: `AppLogger` (`core/logging/app_logger.dart`) envolve
  `package:logging`; é o único ponto de saída de log do app, pronto para
  depois plugar um backend (Crashlytics, Sentry) sem mexer em quem chama.
- **Persistência local**: `core/storage/local_prefs.dart` usa
  `shared_preferences` para preferências de UI (ex: última aba aberta) — o
  Firestore continua sendo a fonte de verdade dos dados do usuário.

### Testes

```
test/
├── helpers/mocks.dart     # Mocks (mocktail) dos 5 services + fallback values
├── unit/                  # AuthProvider, WorkoutProvider, ReminderProvider
└── widget/                # LoginScreen, ForgotPasswordScreen
```

Rodar tudo: `flutter test`. Os testes de provider mockam os services
(`AuthService`, `FirestoreService`, `NotificationService`) com `mocktail` —
nenhum teste toca o Firebase de verdade.

### CI

`.github/workflows/flutter_ci.yml` roda em todo push/PR para `main`:
`flutter pub get` → `dart format --set-exit-if-changed` → `flutter analyze`
→ `flutter test`. Não faz `flutter build` porque isso exigiria
`google-services.json`/`GoogleService-Info.plist` (específicos de cada
projeto Firebase, de propósito fora do repositório — veja `.gitignore`).

## Como rodar

### 1. Instalar dependências

```bash
flutter pub get
```

### 2. Configurar o Firebase (obrigatório)

O app usa **Firebase Authentication** (e-mail/senha) e **Cloud Firestore**.
`lib/firebase_options.dart` neste projeto é um placeholder — você precisa
gerar o arquivo real:

```bash
# instalar a CLI (uma vez só)
dart pub global activate flutterfire_cli

# na raiz do projeto, logado na sua conta Firebase (firebase login)
flutterfire configure
```

Isso cria/associa um projeto no [Firebase Console](https://console.firebase.google.com),
gera `lib/firebase_options.dart` com as chaves reais e configura os arquivos
nativos (`google-services.json` no Android, `GoogleService-Info.plist` no iOS).

No **Firebase Console**, depois de configurado:
- Vá em **Authentication → Sign-in method** e habilite **E-mail/senha**.
- Vá em **Firestore Database** e crie o banco (modo de produção ou teste).

### 3. Regras do Firestore (sugestão inicial)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      // O próprio usuário sempre pode ler/escrever seu perfil.
      // Um instrutor também pode LER o perfil de um aluno vinculado a ele.
      allow read: if request.auth != null && (
        request.auth.uid == userId ||
        resource.data.instructorId == request.auth.uid
      );
      allow write: if request.auth != null && request.auth.uid == userId;

      match /workouts/{workoutId} {
        allow read: if request.auth != null && (
          request.auth.uid == userId ||
          get(/databases/$(database)/documents/users/$(userId)).data.instructorId == request.auth.uid
        );
        allow write: if request.auth != null && request.auth.uid == userId;
      }
      match /reminders/{reminderId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      match /body_photos/{photoId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      match /chat_messages/{messageId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      match /meal_photos/{photoId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      match /students/{studentId} {
        // Só o próprio instrutor (dono deste documento users/{userId}) mexe
        // na sua lista de alunos.
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
    match /exercises/{exerciseId} {
      allow read: if request.auth != null;
      allow write: if false; // gerenciado por admin/backend
    }
  }
}
```

> **Nota sobre índices**: a busca de instrutor por código
> (`findInstructorByCode`) filtra por `role` e `inviteCode` ao mesmo tempo.
> Na primeira vez que isso rodar, o Firebase pode mostrar um erro no
> console/logs com um link para criar o índice composto necessário — é só
> clicar no link, ele cria automaticamente.

### 3.1 Regras do Storage (fotos de evolução do corpo e de refeições)

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /users/{userId}/body_photos/{fileName} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /users/{userId}/meal_photos/{fileName} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### 4. Biblioteca de exercícios

`lib/shared/models/sample_exercises.dart` traz 20 exercícios reais (nome,
grupo muscular, equipamento, descrição, passo a passo e vídeo do YouTube
ensinando a execução correta) cobrindo os principais grupos musculares. Os
vídeos tocam via `youtube_player_iframe` (funciona em Android, iOS e Web).

Você não precisa fazer nada manualmente: na primeira vez que o app roda com
a coleção `exercises` do Firestore vazia, `ExerciseProvider._seedIfEmpty`
copia essa lista para o Firestore automaticamente — a biblioteca "de
verdade" (persistida, sincronizada entre dispositivos) fica pronta sozinha.

Quer adicionar mais exercícios depois? Edite `sample_exercises.dart` e
apague os documentos antigos da coleção `exercises` no Console (ou publique
os novos direto lá) — o app não sobrescreve documentos já existentes.

### 5. Rodar o app

```bash
flutter run
```

## O que já está implementado

- ✅ Login, cadastro e **recuperação de senha** com Firebase Auth
  (e-mail/senha). O cadastro é **sempre de aluno**; personal e
  nutricionista pedem aprovação depois (ver "Aprovação de profissionais")
- ✅ Aba **Início** com resumo do dia (treino em andamento, lembretes ativos)
  e atalhos para as outras abas
- ✅ Navegação por `go_router` com transições animadas entre telas
- ✅ Início/registro de treino com múltiplos exercícios, séries, reps e peso
- ✅ Cronômetro de descanso entre séries (com presets de 30/60/90/120s)
- ✅ Biblioteca de exercícios com busca, filtro por grupo muscular e vídeo
  demonstrativo do movimento (player embutido)
- ✅ Progresso: gráfico de volume de treino ao longo do tempo (fl_chart) +
  histórico, e uma aba de **fotos de evolução do corpo** (galeria + upload
  via câmera/galeria)
- ✅ **Lembretes de água e suplementos**: notificações locais diárias
  recorrentes, configuráveis por horário
- ✅ **Chat com IA** (aba "IA") — tira dúvidas de treino/dieta/suplementação
  (orientação geral, com cota por plano — ver "Backend de IA")
- ✅ **Fotos de refeição** (café/almoço/janta/lanche) com **análise de IA**
  feita e gravada pelo servidor logo após o upload
- ✅ **Área instrutor/aluno**: instrutor recebe um código único quando é
  aprovado; aluno informa esse código no próprio cadastro (ou depois, no
  perfil) para se vincular; instrutor vê a lista de alunos vinculados e o
  histórico de treinos de cada um
- ✅ **Interface e Início diferentes para instrutor e aluno** — o instrutor
  vê número de alunos, atalho para a lista e acesso direto ao assistente
  de IA em vez dos cards de treino/lembretes do aluno
- ✅ **Assistente de IA para instrutores**: sugestões gerais ("me dê mais
  ideias de treino de braço") ou contextualizadas a um aluno específico —
  o instrutor anota algo sobre o aluno (ex: "dor nas costas") na tela do
  aluno, pede sugestão à IA e pode transformar a resposta num **plano de
  treino** de verdade (título, instruções, exercícios com séries/reps
  alvo escolhidos da biblioteca)
- ✅ **Planos de treino**: o aluno vê os planos que o instrutor montou pra
  ele na aba Treino e inicia o registro de séries já com os exercícios
  prescritos carregados
- ✅ **Painel de administração** (aba "Admin", só visível para o dono do
  app — identificado pelo e-mail, checado também nas regras do Firestore,
  não só na UI): estatísticas gerais (usuários, alunos, instrutores,
  exercícios, treinos registrados), lista de todos os usuários com busca e
  promoção/rebaixamento de papel (aluno ↔ instrutor) sem precisar do fluxo
  de código de convite, e gerenciamento completo da biblioteca de
  exercícios (criar/editar/remover) — só o admin pode escrever nessa
  coleção compartilhada
- ✅ Perfil do usuário (peso, altura, meta) salvo no Firestore

## Backend de IA (Cloud Functions)

O chat, a análise de foto de refeição e o assistente do instrutor **não
chamam a API de IA diretamente do app** — isso exporia a chave. O app chama
Cloud Functions (`functions/src/ai.ts`) que guardam a chave em segredo.
Veja `functions/README.md` para instalar, criar a chave da Anthropic,
guardar como secret e fazer o deploy. **Sem isso, as funções de IA retornam
erro** — o resto do app funciona normalmente.

### Quem pode chamar

Todas exigem login **e e-mail verificado** (`email_verified` no token). O
papel vem do perfil no Firestore, nunca do app.

| Function | Quem pode | O que faz |
|---|---|---|
| `chatWithAI` | todos os papéis | chat geral; a resposta é gravada em `chat_messages` pelo servidor |
| `askNutritionAI` | só aluno | chat de nutrição (a nutricionista vê a conversa); resposta gravada pelo servidor |
| `analyzeMealPhoto` | só o aluno dono da foto | recebe `{ photoId }`, lê a foto do Storage (JPEG/PNG/WebP, até 5 MB) e grava `aiAnalysis`/`aiAnalysisError` na foto |
| `suggestTrainingPlan` | só instrutor | sugestões de exercício; com `studentUid`, só aluno vinculado a ele (o nome vem do perfil) |

O cliente **não grava** respostas da IA: as regras só deixam criar
mensagens `user` em `chat_messages` (1–2000 caracteres, campos fechados) e
proíbem `aiAnalysis`/`aiAnalysisError` em `meal_photos`. O histórico enviado
à IA é montado pelo servidor (últimas 10 mensagens do Firestore); o que o
app mandar como histórico é ignorado. Perguntas e pedidos: de 1 a 2000
caracteres. Versões antigas do app que mandavam a foto em base64 recebem
"Atualize o app para ver a análise da IA" (a foto continua salva).

### Cotas de uso

Contadas por usuário em `users/{uid}/ai_usage/{período}`, no fuso de São
Paulo — o dia vira à meia-noite (`yyyy-MM-dd`) e o mês no dia 1º
(`yyyy-MM`). O uso é **reservado numa transação antes** de chamar a IA (10
chamadas em paralelo com cota 3 → exatamente 3 passam) e **devolvido** se a
chamada falhar. Com a cota esgotada, a Function responde
`resource-exhausted` com a mensagem pronta, que o app mostra.

| Papel/plano | Chat geral | Nutrição | Foto de refeição | Sugestão de treino |
|---|---|---|---|---|
| Aluno Básico | 5/dia | 10/mês | 3/mês | — |
| Aluno Premium | 20/dia | 60/mês | 60/mês | — |
| Instrutor | 20/dia | — | — | 10/dia |
| Nutricionista | 20/dia | — | — | — |
| Admin | 100/dia em cada função que o papel dele permite | | | |

Os números ficam em `QUOTAS` (`functions/src/ai_guard.ts`) e são repetidos
só para exibição em `AiUsageLimits` (`lib/shared/models/subscription.dart`).

**Plano (Básico/Premium):** fonte única em
`users/{uid}/finance/subscription.planTier`, gravado **só pelo admin**
(Painel admin → Usuários → menu do aluno → "Plano de IA", Function
`setStudentPlanTier`). Sem plano = Básico. O plano é do aluno: não muda ao
vincular/desvincular de instrutor. O instrutor só vê o plano (não altera).

### Modelos

Um por função, em `DEFAULT_MODELS` (`functions/src/anthropic.ts`) — único
lugar para trocar. Cada um pode ser sobrescrito sem mexer no código por uma
variável de ambiente das Functions (ex: em `functions/.env`):

| Função | Modelo padrão | Variável |
|---|---|---|
| Chat geral | `claude-haiku-4-5-20251001` | `AI_MODEL_CHAT` |
| Foto de refeição | `claude-haiku-4-5-20251001` | `AI_MODEL_MEAL_PHOTO` |
| Nutrição (com busca na web, 1 por pergunta) | `claude-sonnet-5` | `AI_MODEL_NUTRITION` |
| Sugestão de treino | `claude-sonnet-5` | `AI_MODEL_TRAINING` |

Timeout: 45 s de espera pela IA (100 s na nutrição, com `timeoutSeconds`
120 na Function). Estouro → "A IA demorou para responder. Tente de novo.";
429/529 da Anthropic → "A IA está com muita procura agora...". As telas de
chat e nutrição mostram o aviso fixo "Orientação geral por IA. Não
substitui um profissional.", e os prompts de sistema pedem só orientação
geral.

### Custo estimado por chamada

Aproximado, para decidir limites — confira os preços atuais em
https://www.anthropic.com/pricing (as contas abaixo usam Haiku 4.5 a US$ 1
/ US$ 5 por milhão de tokens de entrada/saída, Sonnet 5 **assumido** a
US$ 3 / US$ 15, e US$ 10 por mil buscas na web).

| Função | Entrada típica | Saída (máx.) | Custo típico | Teto por chamada |
|---|---|---|---|---|
| Chat geral (Haiku) | 300–2.500 tokens (10 mensagens de histórico) | ~250 (500) | US$ 0,001–0,004 | ~US$ 0,01 |
| Foto de refeição (Haiku) | ~1.800 (imagem até 1600 px + texto) | ~150 (400) | ~US$ 0,003 | ~US$ 0,004 |
| Nutrição (Sonnet + 1 busca) | 3.000–12.000 (resultados da busca) | ~300 (500) | US$ 0,02–0,05 | ~US$ 0,07 |
| Sugestão de treino (Sonnet) | 400–900 | ~400 (700) | ~US$ 0,008 | ~US$ 0,013 |

Teto mensal aproximado por pessoa usando **toda** a cota: aluno Básico
~US$ 2; aluno Premium ~US$ 10; instrutor ~US$ 10; nutricionista ~US$ 6.

## Painel de administração

O e-mail do dono do app está fixo em **quatro** lugares, que precisam ter
exatamente o mesmo valor (e mudar juntos se um dia você trocar de conta):

1. `firestore.rules` — função `isAdmin()`;
2. `functions/src/admin.ts` — constante `ADMIN_EMAIL` (única nas Functions,
   usada por `setUserRole`, `getAdminStats` e `reviewProfessionalRequest`);
3. `lib/core/constants/admin_config.dart` — `ownerEmail` (só controla o que
   a UI mostra);
4. as constantes `ADMIN_EMAIL` dos testes do emulador em `firestore-tests/`.

Além do e-mail certo, a conta do dono precisa estar com o **e-mail
verificado** no Firebase Authentication: as regras e as Functions exigem
`email_verified == true` no token, e o app só mostra a aba/painel de admin
com o e-mail verificado. Com o e-mail não verificado, a conta é tratada
como um usuário comum.
Trocar o papel de um usuário (aluno/instrutor/nutricionista) é feito SÓ
pela Cloud Function `setUserRole` (`functions/src/admin.ts`) — as regras
não deixam nenhum cliente, nem o admin, gravar `role` direto. Ao tirar
alguém de instrutor, a Function encerra antes todos os vínculos de
instrutor dessa pessoa (senão ela continuaria acessando os alunos antigos).

### Aprovação de profissionais

Qualquer pessoa se cadastra como **aluno** — as regras não deixam o cliente
criar perfil com outro papel, nem apagar o próprio perfil (apagar e recriar
era um jeito de escolher o papel de novo). Para virar **personal** ou
**nutricionista**, o aluno abre Perfil → "Sou profissional" e envia o
registro: número do **CREF** + UF, ou número do **CRN** + região (1 a 11).
Isso cria `professional_requests/{uid}` como pendente (nome e e-mail vêm
do perfil e da conta — não podem ser editados no pedido). O pedido só é
aceito com o **e-mail da conta verificado**: sem isso, a tela mostra um
aviso com "Enviar e-mail de verificação" e "Já verifiquei" (recarrega a
conta e o token) e só libera o formulário depois da verificação.

O admin vê os pendentes em Painel admin → "Pedidos de profissional",
confere o registro no site do conselho e decide pela Cloud Function
`reviewProfessionalRequest` (`functions/src/admin.ts`):

- **Aprovar**: o papel do usuário e o status do pedido mudam na mesma
  transação (reaproveita `applyUserRole`, o mesmo núcleo de `setUserRole`).
  O código de convite vem em seguida, pelo `ensureInviteCode`.
- **Recusar**: motivo obrigatório (até 500 caracteres), que o aluno vê. Ele
  pode pedir de novo na hora.

Toda decisão fica registrada em `professional_requests/{uid}/history`.
Repetir a mesma decisão não muda nada; uma decisão contrária é recusada.
A promoção direta pelo painel de usuários (`setUserRole`) continua
existindo como exceção administrativa. Profissionais que já existiam
continuam aprovados, sem migração.

Não existe fluxo de "virar admin" pelo app de propósito: é sempre a mesma
conta, verificada tanto na UI (mostra/esconde a aba) quanto no servidor
(regra do Firestore, que é a barreira de segurança real).

## Deploy de regras e fotos privadas (checklist)

Nada disto é aplicado automaticamente — rode manualmente, com uma conta que
tenha acesso ao projeto `newfitnessappbr`.

1. **Functions antes das regras** — o código de convite depende de
   `ensureInviteCode` e a aprovação de profissionais de
   `reviewProfessionalRequest`:
   `firebase deploy --only functions`
   Publique também os índices (`firebase deploy --only firestore:indexes`)
   e espere ficarem "Enabled" — a lista de pedidos pendentes do admin usa
   um índice composto (`status` + `createdAt`).
2. **Regras juntas** (as de Storage consultam o Firestore):
   `firebase deploy --only firestore:rules,storage`
   Na primeira vez, a CLI pede para conceder ao Storage a permissão de ler
   o Firestore (regras "cross-service"). Aceite — sem isso toda leitura de
   foto de evolução é negada.
3. **CORS do bucket (só para o Flutter Web)** — fotos de evolução novas
   não têm URL pública; o app baixa os bytes pelo SDK, e o navegador só
   permite isso com CORS configurado no bucket:
   ```bash
   gsutil cors set storage.cors.json gs://newfitnessappbr.firebasestorage.app
   gsutil cors get gs://newfitnessappbr.firebasestorage.app   # conferir
   ```
   Ajuste as origens em `storage.cors.json` se o app Web for servido em
   outro domínio. Android/iOS não precisam disso.
4. **Fotos antigas** (gravadas com `imageUrl`) continuam com link público
   até o token ser revogado no Console do Firebase (Storage → arquivo →
   "Revogar token") ou a foto ser reenviada.

## Próximos passos sugeridos

- Notificações push (Firebase Cloud Messaging) para o instrutor avisar
  alunos diretamente
- Marcar exercícios do plano como concluídos e comparar com o prescrito
- Editar/excluir um treino já salvo
- App Check nas Functions de IA (primeiro em modo de monitoramento)
- Testes de integração com Firebase real/emulado (`firebase_auth_mocks`,
  `fake_cloud_firestore`) complementando os testes unitários existentes

## Permissões nativas já configuradas

- **Android**: notificações (`POST_NOTIFICATIONS`), alarme exato
  (`SCHEDULE_EXACT_ALARM`), reagendamento após reboot
  (`RECEIVE_BOOT_COMPLETED`), câmera. Também foi habilitado
  *core library desugaring*, exigido pelo `flutter_local_notifications`.
- **iOS**: descrições de uso de câmera, microfone (áudio dos vídeos de
  exercício) e galeria (`NSCameraUsageDescription`,
  `NSMicrophoneUsageDescription`, `NSPhotoLibraryUsageDescription`)
  exigidas pela Apple; a permissão de
  notificação é solicitada em tempo de execução pelo app (tela de
  Lembretes) via `permission_handler`.

Depois de rodar `flutter pub get`, gere novamente os projetos nativos se
necessário:

```bash
cd ios && pod install && cd ..
```
