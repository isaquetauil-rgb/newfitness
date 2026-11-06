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
    final weeks = <DateTime>{};

    for (final workout in workouts) {
      final week = _weekStart(workout.date);
      weeks.add(week);
      if (week == currentWeek) {
        days[workout.date.weekday - 1] = true;
        count++;
        volume += workout.totalVolume;
      }
    }

    var cursor = weeks.contains(currentWeek)
        ? currentWeek
        : _previousWeek(currentWeek);
    var streak = 0;
    while (weeks.contains(cursor)) {
      streak++;
      cursor = _previousWeek(cursor);
    }

    return WeekSummary(
      trainedDays: days,
      workoutsThisWeek: count,
      volumeThisWeek: volume,
      weekStreak: streak,
    );
  }

  static DateTime _weekStart(DateTime date) =>
      DateTime(date.year, date.month, date.day - (date.weekday - 1));

  static DateTime _previousWeek(DateTime week) =>
      DateTime(week.year, week.month, week.day - 7);
}
