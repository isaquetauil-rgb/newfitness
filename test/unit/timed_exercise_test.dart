import 'package:flutter_test/flutter_test.dart';

import 'package:newfitness/features/workout/logic/rest_timer_controller.dart';
import 'package:newfitness/features/workout/logic/workout_provider.dart';
import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/models/exercise_progress_record.dart';
import 'package:newfitness/shared/models/logged_exercise.dart';
import 'package:newfitness/shared/models/workout_set.dart';
import 'package:newfitness/shared/utils/one_rep_max.dart';

import '../helpers/mocks.dart';

WorkoutSet _t(int seconds, {double kg = 0, bool done = true}) =>
    WorkoutSet(seconds: seconds, weightKg: kg, completed: done);

void main() {
  test('segundos vão e voltam e são opcionais', () {
    expect(WorkoutSet(reps: 10).toMap().containsKey('seconds'), isFalse);
    final s = _t(45, kg: 10);
    expect(WorkoutSet.fromMap(s.toMap()).seconds, 45);
    expect(s.copy().seconds, 45);
    expect(WorkoutSet.fromMap({'reps': 8}).seconds, 0);
  });

  test('série por tempo fica fora do volume, da carga e do 1RM', () {
    final prancha = LoggedExercise(
      exerciseId: 'plank',
      exerciseName: 'Prancha',
      sets: [_t(40, kg: 10), _t(50, kg: 10)],
    );
    expect(prancha.totalVolume, 0);
    expect(bestLoad(prancha.sets), 0);
    expect(bestE1rm(prancha.sets), isNull);
    expect(bestSeconds(prancha.sets), 50);
  });

  group('recorde de tempo', () {
    const base = RecordBaseline(bestSeconds: 45);

    test('passou do maior tempo: recorde de tempo', () {
      final s = _t(50, kg: 20);
      expect(detectSetRecords(s, [s], base), [PersonalRecordKind.duration]);
    });

    test('igual ou menor: não', () {
      final s = _t(45);
      expect(detectSetRecords(s, [s], base), isEmpty);
    });

    test('não comemora de novo no mesmo treino', () {
      final a = _t(50);
      final b = _t(50);
      expect(detectSetRecords(b, [a, b], base), isEmpty);
    });

    test('resumo do dia e rótulo', () {
      final records = recordsOfTheDay(
        [
          LoggedExercise(
            exerciseId: 'plank',
            exerciseName: 'Prancha',
            sets: [_t(30), _t(60)],
          ),
        ],
        const {'plank': base},
      );
      expect(records.single.kind, PersonalRecordKind.duration);
      expect(records.single.label, 'Prancha: maior tempo 1 min');
    });

    test('progress_records guarda o maior tempo', () {
      final agg = aggregateProgressInputs([
        LoggedExercise(
          exerciseId: 'plank',
          exerciseName: 'Prancha',
          sets: [_t(30), _t(55)],
        ),
      ]);
      expect(agg['plank']!.bestSeconds, 55);
      expect(agg['plank']!.topSetLoadKg, 0);

      final first = ExerciseProgressRecord.merge(
        existing: null,
        exerciseId: 'plank',
        exerciseName: 'Prancha',
        date: DateTime(2026, 1, 1),
        topSetLoadKg: 0,
        totalVolume: 0,
        seconds: 55,
      );
      expect(first.bestSeconds, 55);
      expect(first.history.single.seconds, 55);
      final second = ExerciseProgressRecord.merge(
        existing: first,
        exerciseId: 'plank',
        exerciseName: 'Prancha',
        date: DateTime(2026, 1, 2),
        topSetLoadKg: 0,
        totalVolume: 0,
        seconds: 40,
      );
      expect(second.bestSeconds, 55);
      expect(second.baseline.bestSeconds, 55);
      expect(
        ExerciseProgressRecord.fromMap('plank', second.toMap()).bestSeconds,
        55,
      );
    });
  });

  test('exercício por tempo: marca com segundos, sem reps', () {
    final timer = RestTimerController();
    final provider = WorkoutProvider(
      firestoreService: MockFirestoreService(),
      restTimer: timer,
      keepScreenOn: (_) async {},
    );
    provider.startWorkout('u1');
    provider.addExercise(
      const Exercise(
        id: 'plank',
        name: 'Prancha',
        muscleGroup: '',
        equipment: '',
        description: '',
        videoUrl: '',
        tracksDuration: true,
      ),
    );
    final set = provider.activeWorkout!.exercises.single.sets.single;
    provider.updateSet(0, 0, completed: true);
    expect(set.completed, isFalse);
    provider.updateSet(0, 0, seconds: 40, completed: true);
    expect(set.completed, isTrue);
    expect(
      WorkoutProvider.hasRealizedSets(provider.activeWorkout!.exercises),
      isTrue,
    );
    timer.skip();
  });
}
