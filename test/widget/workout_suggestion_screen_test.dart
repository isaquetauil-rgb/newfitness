import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/exercises/logic/exercise_provider.dart';
import 'package:newfitness/features/instructor/logic/custom_exercise_provider.dart';
import 'package:newfitness/features/progress/logic/progress_record_provider.dart';
import 'package:newfitness/features/workout/logic/training_plan_provider.dart';
import 'package:newfitness/features/workout/logic/workout_provider.dart';
import 'package:newfitness/features/workout/presentation/workout_screen.dart';
import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/models/exercise_progress_record.dart';
import 'package:newfitness/shared/models/logged_exercise.dart';
import 'package:newfitness/shared/models/training_plan.dart';
import 'package:newfitness/shared/models/user_profile.dart';
import 'package:newfitness/shared/models/workout.dart';
import 'package:newfitness/shared/models/workout_set.dart';

import '../helpers/mocks.dart';

/// Sugestão de carga na tela de treino: campos já vêm preenchidos, o (i)
/// explica o número e o aluno pode editar.
void main() {
  late MockFirestoreService firestoreService;
  late MockAuthService authService;
  late StreamController<User?> authState;
  late WorkoutProvider workoutProvider;

  setUpAll(() {
    registerTestFallbackValues();
    registerFallbackValue(
      const Exercise(
        id: '',
        name: '',
        muscleGroup: '',
        equipment: '',
        description: '',
        videoUrl: '',
      ),
    );
  });

  const supino = Exercise(
    id: 'supino_reto',
    name: 'Supino reto',
    muscleGroup: 'Peito',
    equipment: 'Barra',
    description: '',
    videoUrl: '',
    loadUnit: 'kg',
  );

  const prescription = PlanExercise(
    exerciseId: 'supino_reto',
    exerciseName: 'Supino reto',
    targetSets: 3,
    targetReps: '8-12',
  );

  final history = [
    Workout(
      id: 'w1',
      userId: 'u1',
      date: DateTime(2026, 1, 1),
      exercises: [
        LoggedExercise(
          exerciseId: 'supino_reto',
          exerciseName: 'Supino reto',
          sets: [
            for (final r in [12, 12, 12])
              WorkoutSet(reps: r, weightKg: 40, completed: true),
          ],
        ),
      ],
    ),
  ];

  setUp(() {
    firestoreService = MockFirestoreService();
    authService = MockAuthService();
    authState = StreamController<User?>.broadcast();
    when(() => authService.authStateChanges)
        .thenAnswer((_) => authState.stream);
    when(() => firestoreService.watchExercises())
        .thenAnswer((_) => Stream.value(const [supino]));
    when(() => firestoreService.seedExercise(any())).thenAnswer((_) async {});
    when(() => firestoreService.watchWorkouts('u1'))
        .thenAnswer((_) => Stream.value(history));
    when(() => firestoreService.getUserProfile('u1')).thenAnswer(
      (_) async => const UserProfile(uid: 'u1', name: 'Ana', email: 'a@x.com'),
    );
    // Marca anterior: 40 kg de carga e 1RM estimado de 56 kg (40 × 12).
    when(() => firestoreService.watchProgressRecords('u1')).thenAnswer(
      (_) => Stream.value([
        ExerciseProgressRecord(
          exerciseId: 'supino_reto',
          exerciseName: 'Supino reto',
          bestLoadKg: 40,
          lastLoadKg: 40,
          lastPerformedAt: DateTime(2026, 1, 1),
          totalSessions: 1,
          bestE1rmKg: 56,
        ),
      ]),
    );
    when(() => firestoreService.saveWorkout(any()))
        .thenAnswer((_) async => 'w2');
    when(() => firestoreService.recordExerciseProgress(any()))
        .thenAnswer((_) async {});
    // Tela inicial do treino, depois de finalizar.
    when(() => firestoreService.watchTrainingPlans(any()))
        .thenAnswer((_) => Stream.value(const []));
    workoutProvider = WorkoutProvider(firestoreService: firestoreService);
  });

  tearDown(() => authState.close());

  Future<void> pump(WidgetTester tester) async {
    final user = MockUser();
    when(() => user.uid).thenReturn('u1');
    when(() => user.email).thenReturn('a@x.com');
    when(() => user.emailVerified).thenReturn(true);
    final auth = AuthProvider(
      authService: authService,
      firestoreService: firestoreService,
    );
    authState.add(user);
    await tester.pump();

    workoutProvider.startFromPlan(
      'u1',
      TrainingPlan(
        id: 'p1',
        studentUid: 'u1',
        instructorUid: 'i1',
        title: 'Hipertrofia',
        createdAt: DateTime(2026),
        workouts: [
          const TrainingSubWorkout(label: 'A', exercises: [prescription]),
        ],
      ),
      0,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<WorkoutProvider>.value(value: workoutProvider),
          ChangeNotifierProvider(
            create: (_) => ExerciseProvider(firestoreService: firestoreService),
          ),
          ChangeNotifierProvider(
            create: (_) =>
                TrainingPlanProvider(firestoreService: firestoreService),
          ),
          ChangeNotifierProvider(
            create: (_) =>
                CustomExerciseProvider(firestoreService: firestoreService),
          ),
          ChangeNotifierProvider(
            create: (_) =>
                ProgressRecordProvider(firestoreService: firestoreService),
          ),
        ],
        child: const MaterialApp(home: WorkoutScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<String> fieldTexts(WidgetTester tester) => [
    for (final f in tester.widgetList<TextField>(find.byType(TextField)))
      f.controller!.text,
  ];

  testWidgets('campos vêm com a sugestão e o (i) explica', (tester) async {
    await pump(tester);

    expect(find.text('Sugestão de hoje: 42,5 kg × 8'), findsOneWidget);
    expect(fieldTexts(tester), ['42,5', '8', '42,5', '8', '42,5', '8']);

    await tester.tap(find.byTooltip('Por que essa carga?'));
    await tester.pumpAndSettle();
    expect(find.text('Por que essa carga?'), findsWidgets);
    expect(find.textContaining('Suba para 42,5 kg'), findsOneWidget);
  });

  testWidgets('aluno edita livremente e a sugestão vira o realizado', (
    tester,
  ) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField).first, '45');
    await tester.pump();
    final set = workoutProvider.activeWorkout!.exercises.single.sets.first;
    expect(set.weightKg, 45);
    expect(set.suggested, isFalse);
    // As outras séries continuam só sugestão: não contam se o aluno parar.
    final kept = WorkoutProvider.withoutEmptySets(
      workoutProvider.activeWorkout!.exercises,
    ).single.sets;
    expect(kept, hasLength(1));
  });

  testWidgets('recorde: banner + vibração e resumo lista os recordes', (
    tester,
  ) async {
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add('${call.arguments}');
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pump(tester);

    // 42,5 kg × 8 (sugestão) > 40 kg: recorde de carga. 1RM 53,8 < 56: não.
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(find.byKey(const ValueKey('record-banner')), findsOneWidget);
    expect(find.text('Novo recorde! maior carga: 42,5 kg'), findsOneWidget);
    expect(haptics, contains('HapticFeedbackType.lightImpact'));

    // A segunda série com a mesma carga não comemora de novo.
    await tester.pump(const Duration(seconds: 5));
    expect(find.byKey(const ValueKey('record-banner')), findsNothing);
    expect(workoutProvider.updateSet(0, 1, completed: true), isEmpty);
    await tester.pump();
    expect(find.byKey(const ValueKey('record-banner')), findsNothing);

    workoutProvider.skipRest();
    await tester.tap(find.text('Finalizar treino'));
    await tester.pumpAndSettle();
    expect(find.text('Treino salvo!'), findsOneWidget);
    expect(find.text('Recorde de hoje'), findsOneWidget);
    expect(find.text('Supino reto: carga 42,5 kg'), findsOneWidget);
  });
}
