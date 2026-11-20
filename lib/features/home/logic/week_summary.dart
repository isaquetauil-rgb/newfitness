import 'package:newfitness/shared/models/workout.dart';

/// Resumo da semana (segunda a domingo) mostrado na tela inicial, calculado
/// a partir do histórico já ordenado do mais recente para o mais antigo.
class WeekSummary {
  /// Sete posições, de segunda a domingo: houve treino nesse dia?
  final List<bool> trainedDays;
  final int workoutsThisWeek;
  final double volumeThisWeek;

  /// Semanas seguidas com treino. A semana atual só encerra a sequência
  /// depois que acaba: sem treino nela ainda, conta a partir da anterior.
  final int weekStreak;

  const WeekSummary({
    required this.trainedDays,
    required this.workoutsThisWeek,
    required this.volumeThisWeek,
    required this.weekStreak,
  });

  factory WeekSummary.from(List<Workout> workouts, DateTime now) {
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

    final weeks = trainedWeeks(workouts);
    final streak = streakEndingAt(
      weeks,
      weeks.contains(currentWeek) ? currentWeek : _previousWeek(currentWeek),
    );

    return WeekSummary(
      trainedDays: days,
      workoutsThisWeek: count,
      volumeThisWeek: volume,
      weekStreak: streak,
    );
  }

  /// Semanas (segunda-feira) em que houve treino.
  static Set<DateTime> trainedWeeks(Iterable<Workout> workouts) => {
    for (final w in workouts) _weekStart(w.date),
  };

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

  /// Maior sequência de semanas seguidas com treino entre [from] e [to]
  /// (só conta as semanas que começam dentro do intervalo).
  static int longestStreak(Set<DateTime> weeks, DateTime from, DateTime to) {
    final inRange = weeks
        .where((w) => !w.isBefore(_weekStart(from)) && w.isBefore(to))
        .toSet();
    var best = 0;
    for (final w in inRange) {
      final next = DateTime(w.year, w.month, w.day + 7);
      if (inRange.contains(next)) continue; // não é o fim de uma sequência
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

  static DateTime _previousWeek(DateTime week) =>
      DateTime(week.year, week.month, week.day - 7);
}
