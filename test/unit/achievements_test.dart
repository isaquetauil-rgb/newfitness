import 'package:flutter_test/flutter_test.dart';
import 'package:newfitness/features/achievements/logic/achievements.dart';
import 'package:newfitness/features/home/logic/week_summary.dart';
import 'package:newfitness/shared/models/logged_exercise.dart';
import 'package:newfitness/shared/models/workout.dart';
import 'package:newfitness/shared/models/workout_set.dart';
import 'package:newfitness/shared/models/user_profile.dart';

Workout _w(DateTime date, {double kg = 50, String id = ''}) => Workout(
  id: id.isEmpty ? date.toIso8601String() : id,
  userId: 'u',
  date: date,
  exercises: [
    LoggedExercise(
      exerciseId: 'supino',
      exerciseName: 'Supino',
      sets: [WorkoutSet(weightKg: kg, reps: 8, completed: true)],
    ),
  ],
);

/// [perWeek] treinos por semana, por [weeks] semanas a partir de 5/1/2026
/// (segunda), em segunda, quarta, sexta...
List<Workout> _weeks(int weeks, int perWeek, {DateTime? start}) {
  final first = start ?? DateTime(2026, 1, 5, 18);
  return [
    for (var w = 0; w < weeks; w++)
      for (var d = 0; d < perWeek; d++)
        _w(DateTime(first.year, first.month, first.day + w * 7 + d * 2, 18)),
  ];
}

void main() {
  group('meta semanal na sequência (WeekSummary)', () {
    final now = DateTime(2026, 1, 28, 12); // quarta da 4ª semana

    test('semana abaixo da meta quebra a sequência', () {
      final history = [
        ..._weeks(1, 3), // semana de 5/1: 3 treinos
        ..._weeks(1, 2, start: DateTime(2026, 1, 12, 18)), // 2: abaixo
        ..._weeks(1, 3, start: DateTime(2026, 1, 19, 18)), // 3
      ];
      final s = WeekSummary.from(history, now, weeklyGoal: 3);
      expect(s.weekStreak, 1);
      // Com meta 2, as três semanas contam.
      expect(WeekSummary.from(history, now, weeklyGoal: 2).weekStreak, 3);
    });

    test('dias de descanso não quebram: só a contagem da semana importa', () {
      // Semana de 12/1: sex, sáb, dom. Semana de 19/1: seg e depois só sáb e
      // dom (4 dias de descanso no meio).
      final history = [
        _w(DateTime(2026, 1, 16)),
        _w(DateTime(2026, 1, 17)),
        _w(DateTime(2026, 1, 18)),
        _w(DateTime(2026, 1, 19)),
        _w(DateTime(2026, 1, 24)),
        _w(DateTime(2026, 1, 25)),
      ];
      final s = WeekSummary.from(history, now, weeklyGoal: 3);
      expect(s.weekStreak, 2);
    });

    test('semana atual ainda abaixo da meta não zera a sequência', () {
      final history = [
        ..._weeks(3, 3),
        _w(DateTime(2026, 1, 26, 8)), // semana atual: 1 de 3
      ];
      final s = WeekSummary.from(history, now, weeklyGoal: 3);
      expect(s.workoutsThisWeek, 1);
      expect(s.goalMetThisWeek, isFalse);
      expect(s.weekStreak, 3);
    });

    test('meta padrão do perfil é 3 e valores fora de 1 a 7 são ignorados', () {
      const p = UserProfile(uid: 'u', name: 'A', email: 'a@a');
      expect(p.effectiveWeeklyGoal, 3);
      expect(p.copyWith(weeklyGoal: 5).effectiveWeeklyGoal, 5);
      expect(p.copyWith(weeklyGoal: 0).effectiveWeeklyGoal, 3);
      expect(p.copyWith(weeklyGoal: 9).effectiveWeeklyGoal, 3);
    });

    test('perfil antigo (sem os campos novos) continua abrindo', () {
      final p = UserProfile.fromMap('u', {'name': 'A', 'email': 'a@a'});
      expect(p.weeklyGoal, isNull);
      expect(p.achievements, isNull);
      expect(p.toMap().containsKey('weeklyGoal'), isFalse);
      expect(p.toMap().containsKey('achievements'), isFalse);
      final back = UserProfile.fromMap('u', {
        'weeklyGoal': 4,
        'achievements': {'firstWorkout': 1000, 'lixo': 'x'},
      });
      expect(back.weeklyGoal, 4);
      expect(back.achievements, {'firstWorkout': 1000});
    });
  });

  group('computeAchievements', () {
    test('nenhum treino, nenhuma conquista', () {
      expect(computeAchievements(const [], weeklyGoal: 3), isEmpty);
    });

    test('quantidade: data do N-ésimo treino', () {
      final history = _weeks(4, 3); // 12 treinos
      final a = computeAchievements(history.reversed, weeklyGoal: 3);
      expect(a[Achievement.firstWorkout], history.first.date);
      expect(a[Achievement.workouts10], history[9].date);
      expect(a.containsKey(Achievement.workouts50), isFalse);
    });

    test('50, 100 e 250 treinos', () {
      final a = computeAchievements(_weeks(84, 3), weeklyGoal: 3); // 252
      expect(
        a.keys,
        containsAll([
          Achievement.workouts50,
          Achievement.workouts100,
          Achievement.workouts250,
        ]),
      );
    });

    test('primeiro recorde: só depois de haver marca anterior', () {
      final a = computeAchievements([
        _w(DateTime(2026, 1, 5), kg: 50),
        _w(DateTime(2026, 1, 7), kg: 50),
        _w(DateTime(2026, 1, 9), kg: 52.5),
      ], weeklyGoal: 3);
      expect(a[Achievement.firstRecord], DateTime(2026, 1, 9));

      final none = computeAchievements([
        _w(DateTime(2026, 1, 5), kg: 80),
      ], weeklyGoal: 3);
      expect(none.containsKey(Achievement.firstRecord), isFalse);
    });

    test('4 semanas seguidas: no treino que bateu a meta da 4ª semana', () {
      final history = _weeks(4, 3);
      final a = computeAchievements(history, weeklyGoal: 3);
      // 4ª semana começa 26/1; 3º treino dela é sexta 30/1.
      expect(a[Achievement.weeks4], DateTime(2026, 1, 30, 18));
      expect(a.containsKey(Achievement.weeks12), isFalse);
    });

    test('sequência quebrada recomeça do zero', () {
      final history = [
        ..._weeks(3, 3),
        // pula a semana de 26/1
        ..._weeks(3, 3, start: DateTime(2026, 2, 2, 18)),
      ];
      final a = computeAchievements(history, weeklyGoal: 3);
      expect(a.containsKey(Achievement.weeks4), isFalse);
    });

    test('12 e 26 semanas', () {
      final a = computeAchievements(_weeks(26, 2), weeklyGoal: 2);
      expect(
        a.keys,
        containsAll([
          Achievement.weeks4,
          Achievement.weeks12,
          Achievement.weeks26,
        ]),
      );
      // Com meta 3 as mesmas semanas não contam.
      final b = computeAchievements(_weeks(26, 2), weeklyGoal: 3);
      expect(b.containsKey(Achievement.weeks4), isFalse);
    });
  });

  group('perfil e aviso', () {
    test('mergeAchievements nunca perde o que estava gravado', () {
      final stored = {
        'weeks4': DateTime(2025, 6, 1).millisecondsSinceEpoch,
        'conquistaAntiga': 1,
      };
      final merged = mergeAchievements({
        Achievement.firstWorkout: DateTime(2025, 1, 1),
      }, stored);
      expect(merged.keys, {Achievement.weeks4, Achievement.firstWorkout});
      expect(
        achievementsToMap(merged)['firstWorkout'],
        DateTime(2025, 1, 1).millisecondsSinceEpoch,
      );
    });

    test('newlyEarned: só o que o último treino trouxe', () {
      final history = _weeks(3, 3); // 9 treinos
      final latest = _w(DateTime(2026, 1, 26, 18), id: 'novo'); // 10º
      final fresh = newlyEarned([...history, latest], latest, weeklyGoal: 3);
      expect(fresh, [Achievement.workouts10]);

      // Histórico ainda sem o novo treino (cache atrasado): mesmo resultado.
      expect(newlyEarned(history, latest, weeklyGoal: 3), [
        Achievement.workouts10,
      ]);
    });

    test('primeiro treino de todos', () {
      final latest = _w(DateTime(2026, 1, 5), id: 'a');
      expect(newlyEarned([latest], latest, weeklyGoal: 3), [
        Achievement.firstWorkout,
      ]);
    });
  });
}
