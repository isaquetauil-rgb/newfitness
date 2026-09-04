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
      allow read, write: if request.auth != null && request.auth.uid == userId;
      match /workouts/{workoutId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      match /reminders/{reminderId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      match /body_photos/{photoId} {
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

### 3.1 Regras do Storage (fotos de evolução do corpo)

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /users/{userId}/body_photos/{fileName} {
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

- ✅ Login e cadastro com Firebase Auth (e-mail/senha)
- ✅ Início/registro de treino com múltiplos exercícios, séries, reps e peso
- ✅ Cronômetro de descanso entre séries (com presets de 30/60/90/120s)
- ✅ Biblioteca de exercícios com busca, filtro por grupo muscular e vídeo
  demonstrativo do movimento (player embutido)
- ✅ Progresso: gráfico de volume de treino ao longo do tempo (fl_chart) +
  histórico, e uma aba de **fotos de evolução do corpo** (galeria + upload
  via câmera/galeria, guardadas no Firebase Storage)
- ✅ **Lembretes de água e suplementos**: notificações locais diárias
  recorrentes (aba "Lembretes"), configuráveis por horário, com dosagem
  opcional para suplementos
- ✅ Perfil do usuário (peso, altura, meta) salvo no Firestore

## Próximos passos sugeridos

- Fotos de refeições (café/almoço/janta) com análise por IA de visão —
  precisa de um backend (Cloud Function) para chamar a API de IA sem expor
  a chave no app
- Chat com IA (assistente dentro do app) usando o mesmo backend acima
- Área de instrutor/aluno: papéis de usuário diferentes, onde o instrutor
  acompanha o progresso dos alunos e pode enviar notificações push (via
  Firebase Cloud Messaging) diretamente para eles
- Editar/excluir um treino já salvo
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
