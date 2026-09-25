import 'package:flutter_test/flutter_test.dart';

import 'package:newfitness/shared/models/exercise_progress_record.dart';
import 'package:newfitness/shared/models/logged_exercise.dart';
import 'package:newfitness/shared/models/workout_set.dart';

void main() {
  group('ExerciseProgressRecord.merge', () {
    test('primeira sessão: cria o registro com 1 sessão e a carga como melhor e última', () {
      final result = ExerciseProgressRecord.merge(
        existing: null,
        exerciseId: 'bench_press',
        exerciseName: 'Supino reto',
        date: DateTime(2026, 1, 10),
        topSetLoadKg: 40,
        totalVolume: 400,
      );

      expect(result.totalSessions, 1);
      expect(result.bestLoadKg, 40);
      expect(result.lastLoadKg, 40);
      expect(result.history, hasLength(1));
    });

    test('carga maior que a anterior vira o novo melhor e o novo último', () {
      final first = ExerciseProgressRecord.merge(
        existing: null,
        exerciseId: 'bench_press',
        exerciseName: 'Supino reto',
        date: DateTime(2026, 1, 10),
        topSetLoadKg: 40,
        totalVolume: 400,
      );

      final second = ExerciseProgressRecord.merge(
        existing: first,
        exerciseId: 'bench_press',
        exerciseName: 'Supino reto',
        date: DateTime(2026, 1, 17),
        topSetLoadKg: 50,
        totalVolume: 500,
      );

      expect(second.bestLoadKg, 50);
      expect(second.lastLoadKg, 50);
      expect(second.totalSessions, 2);
      expect(second.history, hasLength(2));
    });

    test('carga menor que a melhor histórica não derruba o recorde, mas atualiza a última', () {
      final first = ExerciseProgressRecord.merge(
        existing: null,
        exerciseId: 'bench_press',
        exerciseName: 'Supino reto',
        date: DateTime(2026, 1, 10),
        topSetLoadKg: 60,
        totalVolume: 600,
      );

      final second = ExerciseProgressRecord.merge(
        existing: first,
        exerciseId: 'bench_press',
        exerciseName: 'Supino reto',
        date: DateTime(2026, 1, 17),
        topSetLoadKg: 45,
        totalVolume: 450,
      );

      expect(second.bestLoadKg, 60);
      expect(second.lastLoadKg, 45);
    });

    test(
      'respeita o limite de histórico, mantendo os pontos mais recentes',
      () {
        ExerciseProgressRecord? record;
        for (var i = 0; i < 5; i++) {
          record = ExerciseProgressRecord.merge(
            existing: record,
            exerciseId: 'bench_press',
            exerciseName: 'Supino reto',
            date: DateTime(2026, 1, 1 + i),
            topSetLoadKg: 40.0 + i,
            totalVolume: 400,
            historyLimit: 3,
          );
        }

        expect(record!.history, hasLength(3));
        expect(record.history.last.topSetLoadKg, 44);
        expect(record.history.first.topSetLoadKg, 42);
      },
    );
  });

  group('aggregateProgressInputs', () {
    test('agrega um exercício repetido no mesmo treino como UMA entrada', () {
      final exercises = [
        LoggedExercise(
          exerciseId: 'bench_press',
          exerciseName: 'Supino reto',
          sets: [WorkoutSet(reps: 10, weightKg: 40)],
        ),
        LoggedExercise(
          exerciseId: 'bench_press',
          exerciseName: 'Supino reto',
          sets: [WorkoutSet(reps: 8, weightKg: 50)],
        ),
      ];

      final result = aggregateProgressInputs(exercises);

      expect(result, hasLength(1));
      expect(result['bench_press']!.topSetLoadKg, 50);
      expect(result['bench_press']!.totalVolume, 10 * 40 + 8 * 50);
    });

    test('exercícios diferentes viram entradas separadas', () {
      final exercises = [
        LoggedExercise(
          exerciseId: 'bench_press',
          exerciseName: 'Supino reto',
          sets: [WorkoutSet(reps: 10, weightKg: 40)],
        ),
        LoggedExercise(
          exerciseId: 'squat',
          exerciseName: 'Agachamento livre',
          sets: [WorkoutSet(reps: 10, weightKg: 60)],
        ),
      ];

      final result = aggregateProgressInputs(exercises);

      expect(result.keys, containsAll(['bench_press', 'squat']));
    });

    test('ignora exercícios sem carga nem volume registrado', () {
      final exercises = [
        LoggedExercise(exerciseId: 'bench_press', exerciseName: 'Supino reto'),
      ];

      final result = aggregateProgressInputs(exercises);

      expect(result, isEmpty);
    });
  });
}
