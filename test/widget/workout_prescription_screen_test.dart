import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/exercises/logic/exercise_provider.dart';
import 'package:newfitness/features/instructor/logic/custom_exercise_provider.dart';
import 'package:newfitness/features/workout/logic/training_plan_provider.dart';
import 'package:newfitness/features/workout/logic/workout_provider.dart';
import 'package:newfitness/features/workout/presentation/rest_timer_sheet.dart';
import 'package:newfitness/features/workout/presentation/workout_screen.dart';
import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/models/training_plan.dart';

import '../helpers/mocks.dart';

/// Tela de execução com prescrição do plano (#14): mostra a meta, não
/// preenche os campos do realizado e não compara nada.
void main() {
  late MockFirestoreService firestoreService;
  late WorkoutProvider workoutProvider;
  late ExerciseProvider exerciseProvider;
  late AuthProvider authProvider;

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

  const rosca = Exercise(
    id: 'rosca_unilateral',
    name: 'Rosca unilateral',
    muscleGroup: 'Bíceps',
    equipment: 'Halter',
    description: '',
    videoUrl: '',
    isUnilateral: true,
  );

  setUp(() {
    firestoreService = MockFirestoreService();
    when(() => firestoreService.watchExercises())
        .thenAnswer((_) => Stream.value(const [rosca]));
    when(() => firestoreService.seedExercise(any())).thenAnswer((_) async {});
    final authService = MockAuthService();
    when(() => authService.authStateChanges)
        .thenAnswer((_) => const Stream<User?>.empty());
    authProvider = AuthProvider(
      authService: authService,
      firestoreService: firestoreService,
    );
    exerciseProvider = ExerciseProvider(firestoreService: firestoreService);
    workoutProvider = WorkoutProvider(firestoreService: firestoreService);
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<WorkoutProvider>.value(value: workoutProvider),
          ChangeNotifierProvider<ExerciseProvider>.value(
            value: exerciseProvider,
          ),
          ChangeNotifierProvider(
            create: (_) =>
                TrainingPlanProvider(firestoreService: firestoreService),
          ),
          ChangeNotifierProvider(
            create: (_) =>
                CustomExerciseProvider(firestoreService: firestoreService),
          ),
        ],
        child: const MaterialApp(home: WorkoutScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  TrainingPlan planWith(List<PlanExercise> exercises) => TrainingPlan(
    id: 'plan1',
    studentUid: 'u1',
    instructorUid: 'i1',
    title: 'Hipertrofia',
    createdAt: DateTime(2024),
    workouts: [TrainingSubWorkout(label: 'Treino A', exercises: exercises)],
  );

  const supino = PlanExercise(
    exerciseId: 'supino_reto',
    exerciseName: 'Supino reto',
    targetSets: 4,
    targetReps: '10',
    targetWeightsKg: '30',
    restSeconds: 90,
    notes: 'Controlar a descida',
  );

  final block = find.byKey(const ValueKey('prescription-block'));

  testWidgets('bloco "Prescrito" com séries, reps, carga, descanso e notas', (
    tester,
  ) async {
    workoutProvider.startFromPlan('u1', planWith([supino]), 0);
    await pump(tester);

    expect(block, findsOneWidget);
    expect(find.text('Prescrito'), findsOneWidget);
    expect(find.text('4 séries × 10 reps'), findsOneWidget);
    expect(find.text('30 kg'), findsOneWidget);
    expect(find.text('Descanso: 90 s'), findsOneWidget);
    expect(find.text('Controlar a descida'), findsOneWidget);
    expect(find.text('Realizado'), findsOneWidget);
  });

  testWidgets('campos de execução continuam VAZIOS apesar da prescrição', (
    tester,
  ) async {
    workoutProvider.startFromPlan('u1', planWith([supino]), 0);
    await pump(tester);

    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields, hasLength(8)); // 4 séries × (kg, reps)
    for (final f in fields) {
      expect(f.controller!.text, isEmpty);
    }
  });

  testWidgets('treino livre não mostra o bloco', (tester) async {
    workoutProvider.startWorkout('u1');
    workoutProvider.addExercise(rosca);
    await pump(tester);

    expect(block, findsNothing);
    expect(find.text('Realizado'), findsNothing);
  });

  testWidgets('descanso abre o cronômetro com o tempo prescrito', (
    tester,
  ) async {
    workoutProvider.startFromPlan('u1', planWith([supino]), 0);
    await pump(tester);

    await tester.tap(find.text('Descansar'));
    await tester.pumpAndSettle();

    final sheet = tester.widget<RestTimerSheet>(find.byType(RestTimerSheet));
    expect(sheet.initialSeconds, 90);
    expect(find.text('01:30'), findsOneWidget);
  });

  testWidgets('substituição mostra "No lugar de" e "Prescrito para X"', (
    tester,
  ) async {
    workoutProvider.startFromPlan('u1', planWith([supino]), 0);
    workoutProvider.substituteExercise(
      0,
      const Exercise(
        id: 'supino_inclinado',
        name: 'Supino inclinado',
        muscleGroup: 'Peito',
        equipment: 'Barra',
        description: '',
        videoUrl: '',
      ),
    );
    await pump(tester);

    expect(find.text('Supino inclinado'), findsOneWidget);
    expect(find.text('No lugar de Supino reto'), findsOneWidget);
    expect(find.text('Prescrito para Supino reto'), findsOneWidget);
    expect(find.text('Prescrito'), findsNothing);
  });

  testWidgets('exercício unilateral mostra "(cada lado)"', (tester) async {
    workoutProvider.startFromPlan(
      'u1',
      planWith(const [
        PlanExercise(
          exerciseId: 'rosca_unilateral',
          exerciseName: 'Rosca unilateral',
          targetSets: 3,
          targetReps: '12',
        ),
      ]),
      0,
    );
    await pump(tester);

    expect(find.text('3 séries × 12 reps (cada lado)'), findsOneWidget);
  });

  testWidgets('faixa "8-12" aparece como faixa e sem nenhuma comparação', (
    tester,
  ) async {
    workoutProvider.startFromPlan(
      'u1',
      planWith(const [
        PlanExercise(
          exerciseId: 'remada',
          exerciseName: 'Remada',
          targetSets: 3,
          targetReps: '8-12',
          targetWeightsKg: '40/50/60',
        ),
      ]),
      0,
    );
    await pump(tester);

    expect(find.text('3 séries × 8–12 reps'), findsOneWidget);
    expect(find.text('40/50/60 kg'), findsOneWidget);
    // Digitar algo abaixo/acima não gera seta nem indicador.
    await tester.enterText(find.byType(TextField).at(1), '6');
    await tester.enterText(find.byType(TextField).at(0), '32,5');
    await tester.pump();
    expect(find.byIcon(Icons.arrow_upward), findsNothing);
    expect(find.byIcon(Icons.arrow_downward), findsNothing);
    // e o realizado registra exatamente o que foi digitado (vírgula ok)
    final set = workoutProvider.activeWorkout!.exercises.first.sets.first;
    expect(set.reps, 6);
    expect(set.weightKg, 32.5);
    expect(
      workoutProvider.activeWorkout!.exercises.first.prescription!.targetReps,
      '8-12',
    );
  });

  testWidgets('A → B → A: não mostra "No lugar de A" (troca desfeita)', (
    tester,
  ) async {
    workoutProvider.startFromPlan('u1', planWith([supino]), 0);
    workoutProvider.substituteExercise(
      0,
      const Exercise(
        id: 'supino_inclinado',
        name: 'Supino inclinado',
        muscleGroup: 'Peito',
        equipment: 'Barra',
        description: '',
        videoUrl: '',
      ),
    );
    workoutProvider.substituteExercise(
      0,
      const Exercise(
        id: 'supino_reto',
        name: 'Supino reto',
        muscleGroup: 'Peito',
        equipment: 'Barra',
        description: '',
        videoUrl: '',
      ),
    );
    await pump(tester);

    expect(find.text('Supino reto'), findsOneWidget);
    expect(find.textContaining('No lugar de'), findsNothing);
    expect(find.text('Prescrito'), findsOneWidget);
    expect(find.textContaining('Prescrito para'), findsNothing);
  });
}
