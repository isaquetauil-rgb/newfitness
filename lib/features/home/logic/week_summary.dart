import 'package:newfitness/shared/models/workout.dart';

/// Meta de treinos da semana que começa em `weekStart` (ver
/// `WeeklyGoalSchedule.goalFor`). Cada semana é avaliada pela meta que
/// valia nela.
typedef GoalForWeek = int Function(DateTime weekStart);

/// Resumo da semana (segunda a domingo) mostrado na tela inicial, calculado
/// a partir do histórico já ordenado do mais recente para o mais antigo.
///
/// Este é o ÚNICO lugar com a regra de "semanas seguidas" (tela inicial,
/// Meu mês/Meu ano e conquistas usam as funções daqui).
class WeekSummary {
  /// Sete posições, de segunda a domingo: houve treino nesse dia?
  final List<bool> trainedDays;
  final int workoutsThisWeek;
  final double volumeThisWeek;

  /// Treinos por semana que contam para a sequência.
  final int weeklyGoal;

  /// Semanas seguidas em que a meta foi atingida. Dias de descanso não
  /// quebram nada: só importa a semana bater a meta. A semana atual só
  /// encerra a sequência depois que acaba: enquanto a meta não foi batida
  /// nela, conta a partir da anterior.
  final int weekStreak;

  const WeekSummary({
    required this.trainedDays,
    required this.workoutsThisWeek,
    required this.volumeThisWeek,
    required this.weekStreak,
    this.weeklyGoal = 1,
  });

  /// A meta desta semana já foi batida?
  bool get goalMetThisWeek => workoutsThisWeek >= weeklyGoal;

  /// [weeklyGoal] padrão 1 = "semana com pelo menos um treino".
  factory WeekSummary.from(
    List<Workout> workouts,
    DateTime now, {
    int weeklyGoal = 1,
    GoalForWeek? goalForWeek,
  }) {
    final currentWeek = _weekStart(now);
    final days = List<bool>.filled(7, false);
    var count = 0;
    var volume = 0.0;

    for (final workout in workouts) {
      if (_weekStart(workout.date) == currentWeek) {
        days[workout.date.weekday - 1] = true;
        count++;
        volume += workout.totalVolume;
      }
    }

    final weeks = goalWeeks(
      workouts,
      goal: weeklyGoal,
      goalForWeek: goalForWeek,
    );
    final streak = streakEndingAt(
      weeks,
      weeks.contains(currentWeek) ? currentWeek : _previousWeek(currentWeek),
    );

    return WeekSummary(
      trainedDays: days,
      workoutsThisWeek: count,
      volumeThisWeek: volume,
      weekStreak: streak,
      weeklyGoal: goalForWeek?.call(currentWeek) ?? weeklyGoal,
    );
  }

  /// Semanas (segunda-feira) com pelo menos [goal] treinos.
  /// Com [goalForWeek], cada semana usa a meta que valia nela.
  static Set<DateTime> goalWeeks(
    Iterable<Workout> workouts, {
    int goal = 1,
    GoalForWeek? goalForWeek,
  }) =>
      goalHitDates(workouts, goal: goal, goalForWeek: goalForWeek).keys.toSet();

  /// Para cada semana que bateu a meta: o momento do treino que bateu
  /// (o [goal]-ésimo da semana, em ordem de data).
  static Map<DateTime, DateTime> goalHitDates(
    Iterable<Workout> workouts, {
    int goal = 1,
    GoalForWeek? goalForWeek,
  }) {
    final byWeek = <DateTime, List<DateTime>>{};
    for (final w in workouts) {
      (byWeek[_weekStart(w.date)] ??= []).add(w.date);
    }
    final out = <DateTime, DateTime>{};
    byWeek.forEach((week, dates) {
      final raw = goalForWeek?.call(week) ?? goal;
      final need = raw < 1 ? 1 : raw;
      if (dates.length < need) return;
      dates.sort();
      out[week] = dates[need - 1];
    });
    return out;
  }

  /// Quantas semanas seguidas, de [week] para trás, estão em [weeks].
  static int streakEndingAt(Set<DateTime> weeks, DateTime week) {
    var cursor = _weekStart(week);
    var streak = 0;
    while (weeks.contains(cursor)) {
      streak++;
      cursor = _previousWeek(cursor);
    }
    return streak;
  }

  /// Maior sequência de semanas seguidas em [weeks] entre [from] e [to]
  /// (só conta as semanas que começam dentro do intervalo).
  static int longestStreak(Set<DateTime> weeks, DateTime from, DateTime to) {
    final inRange = weeks
        .where((w) => !w.isBefore(_weekStart(from)) && w.isBefore(to))
        .toSet();
    var best = 0;
    for (final w in inRange) {
      if (inRange.contains(nextWeek(w))) continue; // não é o fim da sequência
      final run = streakEndingAt(inRange, w);
      if (run > best) best = run;
    }
    return best;
  }

  static DateTime _weekStart(DateTime date) => weekStartOf(date);

  /// Segunda-feira (meia-noite) da semana de [date]. Usado também pelo mapa
  /// muscular, para "semana" significar a mesma coisa no app todo.
  static DateTime weekStartOf(DateTime date) =>
      DateTime(date.year, date.month, date.day - (date.weekday - 1));

  static DateTime nextWeek(DateTime week) =>
      DateTime(week.year, week.month, week.day + 7);

  static DateTime _previousWeek(DateTime week) =>
      DateTime(week.year, week.month, week.day - 7);
}
