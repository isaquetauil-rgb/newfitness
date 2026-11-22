import 'package:flutter_test/flutter_test.dart';
import 'package:newfitness/features/achievements/logic/achievements.dart';
import 'package:newfitness/features/home/logic/week_summary.dart';
import 'package:newfitness/shared/models/logged_exercise.dart';
import 'package:newfitness/shared/models/user_profile.dart';
import 'package:newfitness/shared/models/weekly_goal.dart';
import 'package:newfitness/shared/models/workout.dart';
import 'package:newfitness/shared/models/workout_set.dart';

Workout _w(DateTime d) => Workout(
  id: d.toIso8601String(),
  userId: 'u',
  date: d,
  exercises: [
    LoggedExercise(
      exerciseId: 'x',
      exerciseName: 'x',
      sets: [WorkoutSet(reps: 8, weightKg: 40, completed: true)],
    ),
  ],
);

/// [perWeek] treinos em cada semana a partir de 5/1/2026 (segunda).
List<Workout> _weeks(List<int> perWeek) => [
  for (var w = 0; w < perWeek.length; w++)
    for (var d = 0; d < perWeek[w]; d++)
      _w(DateTime(2026, 1, 5 + w * 7 + d, 18)),
];

DateTime _week(int i) => DateTime(2026, 1, 5 + i * 7);

void main() {
  group('WeeklyGoalSchedule', () {
    test('sem histórico: a meta do perfil vale para todas as semanas', () {
      final s = WeeklyGoalSchedule(const [], fallback: 4);
      expect(s.goalFor(_week(0)), 4);
      expect(s.goalFor(DateTime(2030)), 4);
    });

    test('primeira mudança guarda a meta antiga para o passado', () {
      final s = WeeklyGoalSchedule(
        const [],
        fallback: 3,
      ).withChange(2, DateTime(2026, 1, 21, 10)); // quarta da 3ª semana
      expect(s.goalFor(_week(0)), 3);
      expect(s.goalFor(_week(1)), 3);
      expect(s.goalFor(_week(2)), 2); // vale desde a segunda dessa semana
      expect(s.goalFor(_week(5)), 2);
    });

    test('mudar duas vezes na mesma semana fica só a última', () {
      final s = WeeklyGoalSchedule(const [], fallback: 3)
          .withChange(5, DateTime(2026, 1, 19, 8))
          .withChange(4, DateTime(2026, 1, 22, 8));
      expect(s.changes.where((c) => c.since == _week(2)), hasLength(1));
      expect(s.goalFor(_week(2)), 4);
    });

    test('vai e volta do Firestore', () {
      final c = WeeklyGoalChange(goal: 2, since: _week(3));
      expect(WeeklyGoalChange.fromMap(c.toMap()), c);
      expect(WeeklyGoalChange.fromMap({'goal': 9, 'since': 0}), isNull);
      final p = UserProfile.fromMap('u', {
        'weeklyGoal': 2,
        'weeklyGoalHistory': [
          {'goal': 3, 'since': 0},
          c.toMap(),
          'lixo',
        ],
      });
      expect(p.weeklyGoalHistory, hasLength(2));
      expect(p.goalSchedule.goalFor(_week(0)), 3);
      expect(p.goalSchedule.goalFor(_week(3)), 2);
      // Perfil antigo continua abrindo:
      expect(UserProfile.fromMap('u', const {}).weeklyGoalHistory, isNull);
    });
  });

  group('cada semana pela meta que valia nela', () {
    final now = DateTime(2026, 2, 4, 12); // quarta da 5ª semana

    test('BAIXAR a meta não faz semanas antigas fracas passarem a contar', () {
      // 2 treinos por semana nas 4 primeiras semanas, com meta 3 nelas.
      // Na 4ª semana o aluno baixa a meta para 2.
      final history = _weeks([2, 2, 2, 2]);
      final schedule = WeeklyGoalSchedule(
        const [],
        fallback: 3,
      ).withChange(2, DateTime(2026, 1, 26, 9));
      final s = WeekSummary.from(
        history,
        now,
        weeklyGoal: 2,
        goalForWeek: schedule.goalFor,
      );
      // Só a 4ª semana (meta 2) conta; as 3 anteriores (meta 3) não.
      expect(s.weekStreak, 1);
      // Sem histórico (regra antiga), as 4 contariam.
      expect(WeekSummary.from(history, now, weeklyGoal: 2).weekStreak, 4);
    });

    test('SUBIR a meta não apaga semanas que bateram a meta da época', () {
      // 3 treinos por semana com meta 3; na 4ª semana sobe para 5.
      final history = _weeks([3, 3, 3, 5]);
      final schedule = WeeklyGoalSchedule(
        const [],
        fallback: 3,
      ).withChange(5, DateTime(2026, 1, 26, 9));
      final s = WeekSummary.from(
        history,
        now,
        weeklyGoal: 5,
        goalForWeek: schedule.goalFor,
      );
      expect(s.weekStreak, 4);
      expect(s.weeklyGoal, 5); // semana atual usa a meta nova
      // A regra antiga (meta 5 para tudo) zeraria o passado.
      expect(WeekSummary.from(history, now, weeklyGoal: 5).weekStreak, 1);
    });

    test('conquista de 4 semanas respeita a meta de cada semana', () {
      final history = _weeks([3, 3, 3, 5]);
      final up = WeeklyGoalSchedule(
        const [],
        fallback: 3,
      ).withChange(5, DateTime(2026, 1, 26, 9));
      final a = computeAchievements(
        history,
        weeklyGoal: 5,
        goalForWeek: up.goalFor,
      );
      expect(a.containsKey(Achievement.weeks4), isTrue);

      final down = WeeklyGoalSchedule(
        const [],
        fallback: 3,
      ).withChange(2, DateTime(2026, 1, 26, 9));
      final b = computeAchievements(
        _weeks([2, 2, 2, 2]),
        weeklyGoal: 2,
        goalForWeek: down.goalFor,
      );
      expect(b.containsKey(Achievement.weeks4), isFalse);
    });
  });
}
