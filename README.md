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
  (e-mail/senha), com escolha de **papel** (aluno ou instrutor) direto no
  cadastro
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
- ✅ **Fotos de refeição** (café/almoço/janta/lanche) com **análise de IA**
  automática logo após o upload
- ✅ **Área instrutor/aluno**: instrutor recebe um código único ao se
  cadastrar; aluno informa esse código no próprio cadastro (ou depois, no
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
- ✅ Perfil do usuário (peso, altura, meta) salvo no Firestore

## Backend de IA (Cloud Functions)

O chat, as análises de foto e o assistente de IA do instrutor **não chamam
a API de IA diretamente do app** — isso exporia a chave de API. Em vez
disso, o app chama uma Cloud Function (`chatWithAI`, `analyzeMealPhoto`,
`analyzeBodyPhoto`, `suggestTrainingPlan`) que guarda a chave em segredo.
Veja `functions/README.md` para o passo a passo completo (instalar
dependências, criar a chave da Anthropic, guardar como secret, fazer o
deploy). **Sem seguir esses passos, essas quatro funções retornam erro** —
o resto do app (incluindo criar planos manualmente e o aluno vê-los)
funciona normalmente sem depender da IA.

## Próximos passos sugeridos

- Notificações push (Firebase Cloud Messaging) para o instrutor avisar
  alunos diretamente
- Marcar exercícios do plano como concluídos e comparar com o prescrito
- Editar/excluir um treino já salvo
- Limite de uso diário do chat/análise de IA por usuário (controle de custo)
- Testes de integração com Firebase real/emulado (`firebase_auth_mocks`,
  `fake_cloud_firestore`) complementando os testes unitários existentes

## Permissões nativas já configuradas

- **Android**: notificações (`POST_NOTIFICATIONS`), alarme exato
  (`SCHEDULE_EXACT_ALARM`), reagendamento após reboot
  (`RECEIVE_BOOT_COMPLETED`), câmera. Também foi habilitado
  *core library desugaring*, exigido pelo `flutter_local_notifications`.
- **iOS**: descrições de uso de câmera e galeria (`NSCameraUsageDescription`,
  `NSPhotoLibraryUsageDescription`) exigidas pela Apple; a permissão de
  notificação é solicitada em tempo de execução pelo app (tela de
  Lembretes) via `permission_handler`.

Depois de rodar `flutter pub get`, gere novamente os projetos nativos se
necessário:

```bash
cd ios && pod install && cd ..
```
