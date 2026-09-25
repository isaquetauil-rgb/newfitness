import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:newfitness/features/workout/logic/workout_provider.dart';
import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/models/training_plan.dart';

import '../helpers/mocks.dart';

void main() {
  late MockFirestoreService firestoreService;
  late WorkoutProvider provider;

  setUpAll(registerTestFallbackValues);

  setUp(() {
    firestoreService = MockFirestoreService();
    provider = WorkoutProvider(firestoreService: firestoreService);
  });

  const exercise = Exercise(
    id: 'e1',
    name: 'Supino',
    muscleGroup: 'Peito',
    equipment: 'Barra',
    description: '',
    videoUrl: '',
  );

  test('startWorkout cria um treino ativo vazio', () {
    provider.startWorkout('u1');

    expect(provider.hasActiveWorkout, isTrue);
    expect(provider.activeWorkout!.userId, 'u1');
    expect(provider.activeWorkout!.exercises, isEmpty);
  });

  test('addExercise adiciona um exercício com uma série padrão', () {
    provider.startWorkout('u1');
    provider.addExercise(exercise);

    expect(provider.activeWorkout!.exercises, hasLength(1));
    expect(provider.activeWorkout!.exercises.first.sets, hasLength(1));
  });

  test('cancelWorkout limpa o treino ativo', () {
    provider.startWorkout('u1');
    provider.cancelWorkout();

    expect(provider.hasActiveWorkout, isFalse);
  });

  test('finishWorkout salva no Firestore e limpa o treino ativo', () async {
    when(() => firestoreService.saveWorkout(any()))
        .thenAnswer((_) async => 'w1');
    when(() => firestoreService.recordExerciseProgress(any()))
        .thenAnswer((_) async {});
    provider.startWorkout('u1');
    provider.addExercise(exercise);
    provider.updateSet(0, 0, reps: 10, weightKg: 40, completed: true);

    final result = await provider.finishWorkout();

    expect(result, WorkoutFinishResult.saved);
    expect(provider.hasActiveWorkout, isFalse);
    verify(() => firestoreService.saveWorkout(any())).called(1);
  });

  test('finishWorkout retorna failed se salvar falhar', () async {
    when(() => firestoreService.saveWorkout(any()))
        .thenThrow(Exception('offline'));
    provider.startWorkout('u1');
    provider.addExercise(exercise);
    provider.updateSet(0, 0, reps: 10, weightKg: 40, completed: true);

    final result = await provider.finishWorkout();

    expect(result, WorkoutFinishResult.failed);
  });

  group('substituteExercise', () {
    const alternative = Exercise(
      id: 'e2',
      name: 'Supino com halteres',
      muscleGroup: 'Peito',
      equipment: 'Halteres',
      description: '',
      videoUrl: '',
    );

    test('troca o exercício preservando as séries já preenchidas', () {
      provider.startWorkout('u1');
      provider.addExercise(exercise);
      provider.updateSet(0, 0, reps: 10, weightKg: 40, completed: true);

      provider.substituteExercise(0, alternative);

      final logged = provider.activeWorkout!.exercises.single;
      expect(logged.exerciseId, 'e2');
      expect(logged.exerciseName, 'Supino com halteres');
      expect(logged.sets.single.reps, 10);
      expect(logged.sets.single.weightKg, 40);
      expect(logged.sets.single.completed, isTrue);
    });

    test('registra o exercício original substituído', () {
      provider.startWorkout('u1');
      provider.addExercise(exercise);

      provider.substituteExercise(0, alternative);

      final logged = provider.activeWorkout!.exercises.single;
      expect(logged.replacedExerciseId, 'e1');
      expect(logged.replacedExerciseName, 'Supino');
    });

    test('uma segunda troca mantém a origem da cadeia, não a imediatamente anterior', () {
      const secondAlternative = Exercise(
        id: 'e3',
        name: 'Supino na máquina',
        muscleGroup: 'Peito',
        equipment: 'Máquina',
        description: '',
        videoUrl: '',
      );
      provider.startWorkout('u1');
      provider.addExercise(exercise);

      provider.substituteExercise(0, alternative);
      provider.substituteExercise(0, secondAlternative);

      final logged = provider.activeWorkout!.exercises.single;
      expect(logged.exerciseId, 'e3');
      expect(logged.replacedExerciseId, 'e1');
      expect(logged.replacedExerciseName, 'Supino');
    });
  });

  test('startFromPlan já cria o número de séries prescrito no plano', () {
    final plan = TrainingPlan(
      id: 'p1',
      studentUid: 'u1',
      instructorUid: 'i1',
      title: 'Plano',
      createdAt: DateTime(2024),
      workouts: const [
        TrainingSubWorkout(
          label: 'Treino A',
          exercises: [
            PlanExercise(
              exerciseId: 'e1',
              exerciseName: 'Supino',
              targetSets: 4,
              targetReps: '10',
            ),
            PlanExercise(
              exerciseId: 'e2',
              exerciseName: 'Remada',
              targetSets: 0, // valor inválido vira 1 série
              targetReps: '10',
            ),
          ],
        ),
      ],
    );

    provider.startFromPlan('u1', plan, 0);

    final exercises = provider.activeWorkout!.exercises;
    expect(provider.activeWorkout!.name, 'Plano · Treino A');
    expect(exercises[0].sets, hasLength(4));
    expect(exercises[1].sets, hasLength(1));
  });
}
