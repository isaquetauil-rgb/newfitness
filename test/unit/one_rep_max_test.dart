import 'package:flutter_test/flutter_test.dart';

import 'package:newfitness/shared/utils/one_rep_max.dart';
import 'package:newfitness/shared/models/exercise_progress_record.dart';
import 'package:newfitness/shared/models/logged_exercise.dart';
import 'package:newfitness/shared/models/workout_set.dart';

WorkoutSet _set(double kg, int reps, {bool done = true}) =>
    WorkoutSet(weightKg: kg, reps: reps, completed: done);

void main() {
  group('Epley', () {
    test('peso × (1 + reps/30)', () {
      expect(epley1rm(100, 10), closeTo(133.33, 0.01));
      expect(epley1rm(60, 5), closeTo(70, 1e-9));
      expect(epley1rm(80, 12), closeTo(112, 1e-9));
    });

    test('com 1 rep o 1RM é o próprio peso', () {
      expect(epley1rm(140, 1), 140);
    });

    test('só vale de 1 a 12 reps e com carga', () {
      expect(epley1rm(50, 13), isNull);
      expect(epley1rm(50, 0), isNull);
      expect(epley1rm(0, 8), isNull);
    });

    test('melhor 1RM entre séries ignora as que não valem', () {
      expect(
        bestE1rm([_set(100, 15), _set(80, 6), _set(90, 3)]),
        closeTo(99, 1e-9), // 90 × 1,1
      );
      expect(bestE1rm([_set(40, 20)]), isNull);
    });

    test('formato pt-BR', () {
      expect(formatKg(62.5), '62,5 kg');
      expect(formatKg(75), '75 kg');
      expect(formatKg(133.333), '133,3 kg');
    });
  });

  group('detectSetRecords', () {
    const base = RecordBaseline(bestLoadKg: 60, bestE1rmKg: 70);

    test('carga acima da melhor: recorde de carga (e de 1RM)', () {
      final s = _set(62.5, 5);
      expect(detectSetRecords(s, [s], base), [
        PersonalRecordKind.load,
        PersonalRecordKind.e1rm,
      ]);
    });

    test('mesma carga com mais reps: só recorde de 1RM', () {
      final s = _set(60, 8); // 76
      expect(detectSetRecords(s, [s], base), [PersonalRecordKind.e1rm]);
    });

    test('igual à marca não é recorde', () {
      final s = _set(60, 5); // 70
      expect(detectSetRecords(s, [s], base), isEmpty);
    });

    test('não comemora de novo o que já bateu hoje', () {
      final first = _set(62.5, 5);
      final second = _set(62.5, 5);
      expect(detectSetRecords(second, [first, second], base), isEmpty);
    });

    test('série ainda não marcada não conta como "já bateu hoje"', () {
      final pending = _set(65, 5, done: false);
      final s = _set(62.5, 5);
      expect(detectSetRecords(s, [pending, s], base), isNotEmpty);
    });

    test('primeira vez no exercício ou sem carga: nada', () {
      expect(detectSetRecords(_set(100, 5), [], null), isEmpty);
      expect(detectSetRecords(_set(0, 20), [], base), isEmpty);
    });

    test('registro antigo sem 1RM: só detecta carga', () {
      const old = RecordBaseline(bestLoadKg: 60);
      expect(detectSetRecords(_set(60, 10), [], old), isEmpty);
      expect(detectSetRecords(_set(61, 3), [], old), [PersonalRecordKind.load]);
    });

    test('mais de 12 reps não conta para o 1RM', () {
      expect(detectSetRecords(_set(55, 15), [], base), isEmpty);
    });
  });

  group('recordsOfTheDay', () {
    LoggedExercise ex(String id, List<WorkoutSet> sets) =>
        LoggedExercise(exerciseId: id, exerciseName: id, sets: sets);

    test('lista carga e 1RM de cada exercício que bateu', () {
      final records = recordsOfTheDay(
        [
          ex('supino', [_set(62.5, 5), _set(60, 6)]),
          ex('agacho', [_set(100, 5)]),
          ex('remada', [_set(50, 10)]),
        ],
        const {
          'supino': RecordBaseline(bestLoadKg: 60, bestE1rmKg: 70),
          'agacho': RecordBaseline(bestLoadKg: 100, bestE1rmKg: 120),
        },
      );
      expect(records, [
        const PersonalRecord(
          exerciseName: 'supino',
          kind: PersonalRecordKind.load,
          valueKg: 62.5,
        ),
        const PersonalRecord(
          exerciseName: 'supino',
          kind: PersonalRecordKind.e1rm,
          valueKg: 72.9, // 62,5 × (1 + 5/30) = 72,92
        ),
      ]);
      expect(records.first.label, 'supino: carga 62,5 kg');
    });

    test('exercício repetido no treino conta junto', () {
      final records = recordsOfTheDay(
        [
          ex('supino', [_set(50, 5)]),
          ex('supino', [_set(65, 3)]),
        ],
        const {'supino': RecordBaseline(bestLoadKg: 60)},
      );
      expect(records.single.valueKg, 65);
    });
  });

  group('progress_records com 1RM', () {
    test('agregação guarda o maior 1RM do dia', () {
      final agg = aggregateProgressInputs([
        LoggedExercise(
          exerciseId: 'supino',
          exerciseName: 'Supino',
          sets: [_set(60, 10), _set(70, 3)],
        ),
      ]);
      expect(agg['supino']!.bestE1rmKg, closeTo(80, 1e-9)); // 60 × 4/3
    });

    test('merge grava e1rmKg no ponto e mantém o melhor', () {
      final first = ExerciseProgressRecord.merge(
        existing: null,
        exerciseId: 'supino',
        exerciseName: 'Supino',
        date: DateTime(2026, 1, 1),
        topSetLoadKg: 60,
        totalVolume: 600,
        e1rmKg: 79.96,
      );
      expect(first.bestE1rmKg, 80);
      expect(first.history.single.e1rmKg, 80);

      final second = ExerciseProgressRecord.merge(
        existing: first,
        exerciseId: 'supino',
        exerciseName: 'Supino',
        date: DateTime(2026, 1, 3),
        topSetLoadKg: 62.5,
        totalVolume: 500,
        e1rmKg: 75,
      );
      expect(second.bestE1rmKg, 80);
      expect(second.history.last.e1rmKg, 75);
    });

    test('documentos antigos sem os campos continuam abrindo', () {
      final r = ExerciseProgressRecord.fromMap('supino', {
        'exerciseName': 'Supino',
        'bestLoadKg': 60,
        'lastLoadKg': 60,
        'lastPerformedAt': 0,
        'totalSessions': 2,
        'history': [
          {'date': 0, 'topSetLoadKg': 60, 'totalVolume': 600},
        ],
      });
      expect(r.bestE1rmKg, isNull);
      expect(r.history.single.e1rmKg, isNull);
      expect(r.toMap().containsKey('bestE1rmKg'), isFalse);
      expect(r.history.single.toMap().containsKey('e1rmKg'), isFalse);
      expect(r.baseline.bestLoadKg, 60);
    });

    test('merge sem 1RM (ex.: só séries longas) mantém o anterior', () {
      final r = ExerciseProgressRecord.merge(
        existing: ExerciseProgressRecord(
          exerciseId: 'a',
          exerciseName: 'A',
          bestLoadKg: 20,
          lastLoadKg: 20,
          lastPerformedAt: DateTime.utc(2026),
          totalSessions: 1,
          bestE1rmKg: 26,
        ),
        exerciseId: 'a',
        exerciseName: 'A',
        date: DateTime(2026, 2, 1),
        topSetLoadKg: 20,
        totalVolume: 300,
      );
      expect(r.bestE1rmKg, 26);
      expect(r.history.last.e1rmKg, isNull);
    });
  });
}
