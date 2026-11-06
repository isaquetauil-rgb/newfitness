import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:newfitness/features/workout/logic/workout_provider.dart';
import 'package:newfitness/shared/models/logged_exercise.dart';
import 'package:newfitness/shared/models/sample_exercises.dart';
import 'package:newfitness/shared/models/workout.dart';
import 'package:newfitness/shared/models/workout_set.dart';
import 'package:newfitness/shared/models/workout_templates.dart';
import 'package:newfitness/shared/services/firestore_service.dart';

class _MockFirestore extends Mock implements FirestoreService {}

void main() {
  group('catálogo', () {
    test('tem treinos grátis e Premium', () {
      expect(workoutTemplates.where((t) => !t.isPremium), isNotEmpty);
      expect(workoutTemplates.where((t) => t.isPremium), isNotEmpty);
    });

    test('ids são únicos e todo treino tem exercícios', () {
      final ids = workoutTemplates.map((t) => t.id).toSet();
      expect(ids.length, workoutTemplates.length);
      for (final template in workoutTemplates) {
        expect(template.workouts, isNotEmpty);
        for (final workout in template.workouts) {
          expect(workout.exercises, isNotEmpty);
        }
      }
    });

    test('todo exercício existe na biblioteca com o mesmo nome', () {
      final names = {for (final e in sampleExercises) e.id: e.name};
      for (final template in workoutTemplates) {
        for (final workout in template.workouts) {
          for (final exercise in workout.exercises) {
            expect(
              names[exercise.exerciseId],
              exercise.exerciseName,
              reason: '${template.id}: ${exercise.exerciseId}',
            );
          }
        }
      }
    });
  });

  group('WorkoutProvider', () {
    late WorkoutProvider provider;

    setUpAll(() {
      registerFallbackValue(Workout(id: '', userId: '', date: DateTime(2026)));
    });

    setUp(() {
      final firestore = _MockFirestore();
      when(() => firestore.saveWorkout(any())).thenAnswer((_) async => 'id');
      when(() => firestore.recordExerciseProgress(any()))
          .thenAnswer((_) async {});
      provider = WorkoutProvider(firestoreService: firestore);
    });

    test('treino pronto começa com a sugestão e as séries vazias', () {
      final template = workoutTemplates.first;
      provider.startFromTemplate('u', template, 0);

      final active = provider.activeWorkout!;
      final first = template.workouts.first.exercises.first;
      expect(active.source!.planId, '$templatePlanPrefix${template.id}');
      expect(active.exercises.first.exerciseId, first.exerciseId);
      expect(active.exercises.first.sets.length, first.targetSets);
      expect(active.exercises.first.prescription, isNotNull);
      expect(active.exercises.first.sets.first.reps, 0);
    });

    test('treino pronto sem séries preenchidas não é salvo', () async {
      provider.startFromTemplate('u', workoutTemplates.first, 0);
      expect(
        WorkoutProvider.hasRealizedSets(provider.activeWorkout!.exercises),
        isFalse,
      );
      expect(
        await provider.finishWorkout(),
        WorkoutFinishResult.endedWithoutSets,
      );
      expect(provider.lastSaved, isNull);
    });

    test('treino salvo fica disponível para o resumo', () async {
      provider.startFromTemplate('u', workoutTemplates.first, 0);
      provider.updateSet(0, 0, reps: 12, weightKg: 40);

      expect(await provider.finishWorkout(), WorkoutFinishResult.saved);
      expect(provider.hasActiveWorkout, isFalse);
      expect(provider.lastSaved!.totalVolume, 480);
    });

    test('repetir copia exercícios e nº de séries, sem os valores', () {
      final last = Workout(
        id: 'w',
        userId: 'u',
        date: DateTime(2026),
        name: 'Treino A',
        exercises: [
          LoggedExercise(
            exerciseId: 'squat',
            exerciseName: 'Agachamento livre',
            sets: [
              WorkoutSet(reps: 10, weightKg: 60, completed: true),
              WorkoutSet(reps: 8, weightKg: 70, completed: true),
            ],
          ),
        ],
      );

      provider.repeatWorkout('u', last);

      final active = provider.activeWorkout!;
      expect(active.id, '');
      expect(active.name, 'Treino A');
      expect(active.exercises.single.sets.length, 2);
      expect(active.exercises.single.sets.first.weightKg, 0);
      expect(active.exercises.single.sets.first.completed, isFalse);
      expect(last.exercises.single.sets.first.weightKg, 60);
    });
  });
}
