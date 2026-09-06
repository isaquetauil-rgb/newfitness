# NewFitness

App de treino em Flutter com login, registro de treinos (exercícios/séries/
repetições), cronômetro de descanso, biblioteca de exercícios com vídeo
demonstrativo, histórico com gráfico de progresso e perfil do usuário.

## Estrutura do projeto

```
lib/
  models/            # Exercise, Workout, LoggedExercise, WorkoutSet, UserProfile
  services/          # AuthService (Firebase Auth), FirestoreService (Firestore)
  providers/         # AuthProvider, WorkoutProvider, ExerciseProvider (estado global)
  screens/
    auth/            # login_screen.dart, register_screen.dart
    home/            # home_screen.dart (navegação inferior)
    workout/         # workout_screen.dart, rest_timer_sheet.dart
    exercises/       # exercise_library_screen.dart, exercise_detail_screen.dart,
                      # exercise_picker_screen.dart
    progress/        # progress_screen.dart (gráficos com fl_chart)
    profile/         # profile_screen.dart
  theme/             # app_theme.dart
  data/              # sample_exercises.dart (dados de exemplo/fallback)
  firebase_options.dart  # PLACEHOLDER — veja passo 2 abaixo
  main.dart
```

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

### 4. Popular a biblioteca de exercícios

Por enquanto o app usa `lib/data/sample_exercises.dart` como fallback caso a
coleção `exercises` do Firestore esteja vazia. Para persistir esses dados de
verdade, você pode rodar um script simples chamando
`FirestoreService().seedExercise(...)` para cada item de `sampleExercises`,
ou cadastrar manualmente no Console. **Troque as URLs de vídeo de exemplo**
pelos vídeos reais (hospedados no Firebase Storage, YouTube, Vimeo, etc.).

### 5. Rodar o app

```bash
flutter run
```

## O que já está implementado

- ✅ Login e cadastro com Firebase Auth (e-mail/senha), com escolha de
  **papel** (aluno ou instrutor) direto no cadastro
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
- ✅ Perfil do usuário (peso, altura, meta) salvo no Firestore

## Backend de IA (Cloud Functions)

O chat e as análises de foto **não chamam a API de IA diretamente do app**
— isso exporia a chave de API. Em vez disso, o app chama uma Cloud Function
que guarda a chave em segredo. Veja `functions/README.md` para o passo a
passo completo (instalar dependências, criar a chave da Anthropic, guardar
como secret, fazer o deploy). **Sem seguir esses passos, o chat e a análise
de foto retornam erro** — o resto do app funciona normalmente.

## Próximos passos sugeridos

- Notificações push (Firebase Cloud Messaging) para o instrutor avisar
  alunos diretamente
- Instrutor poder montar/atribuir planos de treino para os alunos
- Editar/excluir um treino já salvo
- Limite de uso diário do chat/análise de IA por usuário (controle de custo)
- Testes automatizados com mock do Firebase (`firebase_auth_mocks`,
  `fake_cloud_firestore`)

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
