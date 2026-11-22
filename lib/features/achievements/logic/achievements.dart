/// Conquistas, calculadas a partir do histórico de treinos. Lógica pura:
/// sem Flutter e sem Firebase.
library;

import 'package:newfitness/features/home/logic/week_summary.dart';
import 'package:newfitness/features/stats/logic/record_history.dart';
import 'package:newfitness/shared/models/workout.dart';

enum AchievementKind { workouts, record, weekStreak }

/// As conquistas do app. O [name] é a chave gravada no perfil
/// (`users/{uid}.achievements`) — não renomeie.
enum Achievement {
  firstWorkout(
    AchievementKind.workouts,
    1,
    'Primeiro treino',
    'Registrou o primeiro treino',
  ),
  workouts10(AchievementKind.workouts, 10, '10 treinos', 'Chegou a 10 treinos'),
  workouts50(AchievementKind.workouts, 50, '50 treinos', 'Chegou a 50 treinos'),
  workouts100(
    AchievementKind.workouts,
    100,
    '100 treinos',
    'Chegou a 100 treinos',
  ),
  workouts250(
    AchievementKind.workouts,
    250,
    '250 treinos',
    'Chegou a 250 treinos',
  ),
  firstRecord(
    AchievementKind.record,
    1,
    'Primeiro recorde',
    'Bateu o primeiro recorde pessoal',
  ),
  weeks4(
    AchievementKind.weekStreak,
    4,
    '4 semanas seguidas',
    '4 semanas seguidas batendo a meta',
  ),
  weeks12(
    AchievementKind.weekStreak,
    12,
    '12 semanas seguidas',
    '12 semanas seguidas batendo a meta',
  ),
  weeks26(
    AchievementKind.weekStreak,
    26,
    '26 semanas seguidas',
    '26 semanas seguidas batendo a meta',
  );

  const Achievement(this.kind, this.target, this.title, this.description);

  final AchievementKind kind;
  final int target;
  final String title;
  final String description;

  static Achievement? byName(String name) {
    for (final a in values) {
      if (a.name == name) return a;
    }
    return null;
  }
}

/// Conquistas que o histórico garante, com o momento em que cada uma foi
/// alcançada. [weeklyGoal] é a meta semanal do aluno (sequências contam
/// semanas que bateram a meta).
Map<Achievement, DateTime> computeAchievements(
  Iterable<Workout> workouts, {
  required int weeklyGoal,
  GoalForWeek? goalForWeek,
}) {
  final out = <Achievement, DateTime>{};
  final ordered = workouts.toList()..sort((a, b) => a.date.compareTo(b.date));

  // Quantidade de treinos: a data do N-ésimo treino.
  for (final a in Achievement.values) {
    if (a.kind == AchievementKind.workouts && ordered.length >= a.target) {
      out[a] = ordered[a.target - 1].date;
    }
  }

  // Primeiro recorde (mesma regra do resumo do fim do treino).
  final records = recordsFromHistory(ordered);
  if (records.isNotEmpty) out[Achievement.firstRecord] = records.first.date;

  // Sequências: percorre as semanas que bateram a meta, em ordem; quando
  // uma sequência chega a N, a conquista é do treino que bateu a meta
  // daquela semana.
  final hits = WeekSummary.goalHitDates(
    ordered,
    goal: weeklyGoal,
    goalForWeek: goalForWeek,
  );
  final weeks = hits.keys.toList()..sort();
  var run = 0;
  DateTime? previous;
  for (final week in weeks) {
    run = previous != null && WeekSummary.nextWeek(previous) == week
        ? run + 1
        : 1;
    previous = week;
    for (final a in Achievement.values) {
      if (a.kind == AchievementKind.weekStreak &&
          run == a.target &&
          !out.containsKey(a)) {
        out[a] = hits[week]!;
      }
    }
  }
  return out;
}

/// Junta o que o histórico garante com o que já estava gravado no perfil
/// (uma conquista nunca se perde, mesmo se a meta semanal mudar depois).
/// Chaves desconhecidas no perfil são ignoradas.
Map<Achievement, DateTime> mergeAchievements(
  Map<Achievement, DateTime> computed,
  Map<String, int>? stored,
) {
  final out = <Achievement, DateTime>{};
  stored?.forEach((key, ms) {
    final a = Achievement.byName(key);
    if (a != null) out[a] = DateTime.fromMillisecondsSinceEpoch(ms);
  });
  computed.forEach((a, at) {
    final old = out[a];
    if (old == null || at.isBefore(old)) out[a] = at;
  });
  return out;
}

/// Formato gravado no perfil: id → milissegundos.
Map<String, int> achievementsToMap(Map<Achievement, DateTime> earned) => {
  for (final e in earned.entries) e.key.name: e.value.millisecondsSinceEpoch,
};

/// Conquistas que o treino [latest] acabou de dar: as que o histórico com
/// ele tem e o histórico sem ele não tinha. Ordem da lista de conquistas.
List<Achievement> newlyEarned(
  List<Workout> historyWithLatest,
  Workout latest, {
  required int weeklyGoal,
  GoalForWeek? goalForWeek,
}) {
  final before = computeAchievements(
    historyWithLatest.where((w) => w.id != latest.id),
    weeklyGoal: weeklyGoal,
    goalForWeek: goalForWeek,
  );
  final after = computeAchievements(
    [...historyWithLatest.where((w) => w.id != latest.id), latest],
    weeklyGoal: weeklyGoal,
    goalForWeek: goalForWeek,
  );
  return [
    for (final a in Achievement.values)
      if (after.containsKey(a) && !before.containsKey(a)) a,
  ];
}
