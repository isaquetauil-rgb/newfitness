import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
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
import 'package:newfitness/shared/models/training_plan.dart';
import 'package:newfitness/shared/models/user_profile.dart';

import '../helpers/mocks.dart';

/// Treino em andamento: excluir série (botão, arrastar, desfazer), tirar o
/// aquecimento, meta "10-12" no campo de reps e renomear treino/exercício.
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

  setUp(() {
    firestoreService = MockFirestoreService();
    authService = MockAuthService();
    authState = StreamController<User?>.broadcast();
    when(() => authService.authStateChanges)
        .thenAnswer((_) => authState.stream);
    when(() => firestoreService.watchExercises())
        .thenAnswer((_) => Stream.value(const [supino]));
    when(() => firestoreService.seedExercise(any())).thenAnswer((_) async {});
    // Sem histórico: sem sugestão de carga, os campos começam vazios.
    when(() => firestoreService.watchWorkouts('u1'))
        .thenAnswer((_) => Stream.value(const []));
    when(() => firestoreService.getUserProfile('u1')).thenAnswer(
      (_) async => const UserProfile(uid: 'u1', name: 'Ana', email: 'a@x.com'),
    );
    when(() => firestoreService.watchProgressRecords('u1'))
        .thenAnswer((_) => Stream.value(const []));
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
        workouts: const [
          TrainingSubWorkout(
            label: 'A',
            exercises: [
              PlanExercise(
                exerciseId: 'supino_reto',
                exerciseName: 'Supino reto',
                targetSets: 3,
                targetReps: '10-12',
              ),
            ],
          ),
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

  List<dynamic> sets() => workoutProvider.activeWorkout!.exercises.single.sets;

  testWidgets('meta "10-12" aparece no campo de reps vazio', (tester) async {
    await pump(tester);
    expect(find.text('10-12'), findsNWidgets(3));
    // Digitar quantas fez continua sendo um número.
    await tester.enterText(find.byType(TextField).at(1), '11');
    await tester.pump();
    expect(sets().first.reps, 11);
  });

  testWidgets('"Excluir série" apaga a última e "Desfazer" devolve', (
    tester,
  ) async {
    await pump(tester);
    await tester.ensureVisible(find.text('Adicionar série'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adicionar série'));
    await tester.pumpAndSettle();
    expect(sets(), hasLength(4));

    await tester.ensureVisible(find.byKey(const ValueKey('remove-last-set')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('remove-last-set')));
    await tester.pumpAndSettle();
    expect(sets(), hasLength(3));
    expect(find.text('Série excluída.'), findsOneWidget);

    await tester.tap(find.text('Desfazer'));
    await tester.pumpAndSettle();
    expect(sets(), hasLength(4));
  });

  testWidgets('arrastar a série para o lado apaga só ela', (tester) async {
    await pump(tester);
    final second = sets()[1];
    await tester.drag(find.byType(Dismissible).at(1), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(sets(), hasLength(2));
    expect(sets(), isNot(contains(second)));
  });

  testWidgets('tirar aquecimento: some só o aquecimento e dá para desfazer', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField).first, '60');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('generate-warmup')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('generate-warmup')));
    await tester.pumpAndSettle();
    final withWarmup = sets().length;
    expect(withWarmup, greaterThan(3));
    expect(find.byKey(const ValueKey('generate-warmup')), findsNothing);

    await tester.ensureVisible(find.byKey(const ValueKey('remove-warmup')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('remove-warmup')));
    await tester.pumpAndSettle();
    expect(sets(), hasLength(3));
    expect(sets().any((s) => s.isWarmup), isFalse);
    expect(sets().first.weightKg, 60); // a série de trabalho ficou
    expect(find.byKey(const ValueKey('generate-warmup')), findsOneWidget);

    await tester.tap(find.text('Desfazer'));
    await tester.pumpAndSettle();
    expect(sets(), hasLength(withWarmup));
    expect(sets().first.isWarmup, isTrue);
  });

  testWidgets('renomear o treino e o exercício', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('rename-workout')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('rename-field')),
      'Peito pesado',
    );
    await tester.tap(find.byKey(const ValueKey('rename-save')));
    await tester.pumpAndSettle();
    expect(workoutProvider.activeWorkout!.name, 'Peito pesado');

    await tester.ensureVisible(find.byKey(const ValueKey('rename-exercise-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rename-exercise-0')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('rename-field')),
      'Supino na barra',
    );
    await tester.tap(find.byKey(const ValueKey('rename-save')));
    await tester.pumpAndSettle();
    final ex = workoutProvider.activeWorkout!.exercises.single;
    expect(ex.exerciseName, 'Supino na barra');
    expect(ex.exerciseId, 'supino_reto'); // continua o mesmo exercício
    expect(find.text('Supino na barra'), findsOneWidget);
  });
}
