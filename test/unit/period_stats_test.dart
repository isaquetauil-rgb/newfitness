import 'package:flutter_test/flutter_test.dart';
import 'package:newfitness/features/home/logic/week_summary.dart';
import 'package:newfitness/features/stats/logic/period_stats.dart';
import 'package:newfitness/features/stats/logic/record_history.dart';
import 'package:newfitness/shared/models/logged_exercise.dart';
import 'package:newfitness/shared/models/workout.dart';
import 'package:newfitness/shared/models/workout_set.dart';
import 'package:newfitness/shared/utils/one_rep_max.dart';

WorkoutSet _s(double kg, int reps, {SetType type = SetType.normal}) =>
    WorkoutSet(weightKg: kg, reps: reps, completed: true, type: type);

LoggedExercise _e(String id, List<WorkoutSet> sets) =>
    LoggedExercise(exerciseId: id, exerciseName: 'Ex $id', sets: sets);

Workout _w(DateTime date, List<LoggedExercise> ex, {int seconds = 3600}) =>
    Workout(
      id: '$date',
      userId: 'u',
      date: date,
      exercises: ex,
      durationSeconds: seconds,
    );

void main() {
  group('Period', () {
    test('mês: início, fim, anterior e próximo (virada de ano)', () {
      final p = Period.containing(PeriodKind.month, DateTime(2026, 1, 15));
      expect(p.start, DateTime(2026, 1));
      expect(p.end, DateTime(2026, 2));
      expect(p.previous.start, DateTime(2025, 12));
      expect(p.next.start, DateTime(2026, 2));
      expect(p.contains(DateTime(2026, 1, 31, 23, 59)), isTrue);
      expect(p.contains(DateTime(2026, 2)), isFalse);
    });

    test('ano', () {
      final p = Period.containing(PeriodKind.year, DateTime(2026, 7, 4));
      expect(p.start, DateTime(2026));
      expect(p.end, DateTime(2027));
      expect(p.previous.start, DateTime(2025));
    });
  });

  group('recordsFromHistory', () {
    test('primeira vez só cria a marca; depois, carga maior é recorde', () {
      final recs = recordsFromHistory([
        _w(DateTime(2026, 11, 10), [
          _e('a', [_s(60, 8)]),
        ]),
        _w(DateTime(2026, 11, 3), [
          _e('a', [_s(50, 8)]),
        ]),
        _w(DateTime(2026, 11, 17), [
          _e('a', [_s(55, 8)]),
        ]),
      ]);
      // Ordem cronológica: 50 (marca) → 60 (recorde) → 55 (nada).
      final load = recs
          .where((r) => r.record.kind == PersonalRecordKind.load)
          .toList();
      expect(load, hasLength(1));
      expect(load.single.date, DateTime(2026, 11, 10));
      expect(load.single.record.valueKg, 60);
    });

    test('aquecimento não bate recorde', () {
      final recs = recordsFromHistory([
        _w(DateTime(2026, 11, 3), [
          _e('a', [_s(50, 8)]),
        ]),
        _w(DateTime(2026, 11, 10), [
          _e('a', [_s(80, 5, type: SetType.warmup), _s(50, 8)]),
        ]),
      ]);
      expect(recs, isEmpty);
    });
  });

  group('PeriodStats', () {
    final history = [
      _w(DateTime(2026, 10, 28), [
        _e('supino', [_s(50, 8)]),
      ]), // outubro: só marca anterior
      _w(DateTime(2026, 11, 2), [
        _e('supino', [_s(55, 8), _s(55, 8)]),
        _e('agacha', [_s(80, 5)]),
      ], seconds: 3000),
      _w(DateTime(2026, 11, 9), [
        _e('agacha', [_s(80, 5), _s(80, 5)]),
      ], seconds: 2400),
      _w(DateTime(2026, 11, 25), [
        _e('agacha', [_s(20, 10, type: SetType.warmup), _s(85, 5)]),
      ], seconds: 1800),
    ];

    test('totais do mês', () {
      final s = PeriodStats.from(
        history,
        Period.containing(PeriodKind.month, DateTime(2026, 11, 20)),
      );
      expect(s.workouts, 3);
      expect(s.totalSeconds, 7200);
      expect(formatHours(s.totalSeconds), '2 h');
      // 55*8*2 + 80*5 + 80*5*2 + 85*5 (aquecimento fora)
      expect(s.volumeKg, 880 + 400 + 800 + 425);
    });

    test('exercício mais feito: mais treinos, depois mais séries', () {
      final s = PeriodStats.from(
        history,
        Period.containing(PeriodKind.month, DateTime(2026, 11, 1)),
      );
      expect(s.topExercise!.name, 'Ex agacha');
      expect(s.topExercise!.workouts, 3);
      expect(s.topExercise!.sets, 4); // aquecimento não conta
    });

    test('recordes usam o histórico de antes do período', () {
      final s = PeriodStats.from(
        history,
        Period.containing(PeriodKind.month, DateTime(2026, 11, 1)),
      );
      final labels = s.records.map((r) => r.label).toList();
      expect(labels, contains('Ex supino: carga 55 kg'));
      expect(labels, contains('Ex agacha: carga 85 kg'));
      // Um por exercício e tipo.
      expect(
        s.records.where(
          (r) =>
              r.exerciseName == 'Ex agacha' &&
              r.kind == PersonalRecordKind.load,
        ),
        hasLength(1),
      );
    });

    test('semanas seguidas: maior sequência dentro do período', () {
      // Semanas de 2/11 e 9/11 seguidas; 23/11 isolada.
      final s = PeriodStats.from(
        history,
        Period.containing(PeriodKind.month, DateTime(2026, 11, 1)),
      );
      expect(s.consecutiveWeeks, 2);
    });

    test('período vazio', () {
      final s = PeriodStats.from(
        history,
        Period.containing(PeriodKind.month, DateTime(2026, 6, 1)),
      );
      expect(s.isEmpty, isTrue);
      expect(s.topExercise, isNull);
      expect(s.records, isEmpty);
      expect(s.consecutiveWeeks, 0);
    });
  });

  group('WeekSummary (sequência reaproveitada)', () {
    test('longestStreak acha a maior sequência', () {
      final weeks = {
        DateTime(2026, 1, 5),
        DateTime(2026, 1, 12),
        DateTime(2026, 1, 19),
        DateTime(2026, 2, 2),
      };
      expect(
        WeekSummary.longestStreak(weeks, DateTime(2026), DateTime(2027)),
        3,
      );
      expect(WeekSummary.streakEndingAt(weeks, DateTime(2026, 1, 21)), 3);
    });
  });

  test('formatHours', () {
    expect(formatHours(0), '0 min');
    expect(formatHours(45 * 60), '45 min');
    expect(formatHours(3600 + 30 * 60), '1 h 30 min');
  });
}
