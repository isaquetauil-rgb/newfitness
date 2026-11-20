/// Resumo de um período (mês ou ano) para as telas "Meu mês" e "Meu ano".
/// Lógica pura: sem Flutter e sem Firebase.
library;

import 'package:newfitness/features/home/logic/week_summary.dart';
import 'package:newfitness/features/stats/logic/record_history.dart';
import 'package:newfitness/shared/models/workout.dart';
import 'package:newfitness/shared/utils/one_rep_max.dart';

enum PeriodKind { month, year }

/// Intervalo [start, end) de um mês ou ano.
class Period {
  const Period(this.kind, this.start);

  /// O mês/ano que contém [date].
  factory Period.containing(PeriodKind kind, DateTime date) => Period(
    kind,
    DateTime(date.year, kind == PeriodKind.month ? date.month : 1),
  );

  final PeriodKind kind;
  final DateTime start;

  DateTime get end => kind == PeriodKind.month
      ? DateTime(start.year, start.month + 1)
      : DateTime(start.year + 1);

  Period get previous => kind == PeriodKind.month
      ? Period(kind, DateTime(start.year, start.month - 1))
      : Period(kind, DateTime(start.year - 1));

  Period get next => Period(kind, end);

  bool contains(DateTime d) => !d.isBefore(start) && d.isBefore(end);

  @override
  bool operator ==(Object other) =>
      other is Period && other.kind == kind && other.start == start;

  @override
  int get hashCode => Object.hash(kind, start);
}

/// Exercício mais feito: em quantos treinos apareceu e quantas séries.
class TopExercise {
  const TopExercise(this.name, this.workouts, this.sets);
  final String name;
  final int workouts;
  final int sets;
}

class PeriodStats {
  const PeriodStats({
    required this.period,
    required this.workouts,
    required this.totalSeconds,
    required this.volumeKg,
    required this.topExercise,
    required this.records,
    required this.consecutiveWeeks,
  });

  final Period period;
  final int workouts;
  final int totalSeconds;
  final double volumeKg;
  final TopExercise? topExercise;

  /// Recordes batidos no período; por exercício e tipo fica só o último
  /// (o maior), do mais recente para o mais antigo.
  final List<PersonalRecord> records;

  /// Maior sequência de semanas seguidas que bateram a meta semanal,
  /// dentro do período.
  final int consecutiveWeeks;

  bool get isEmpty => workouts == 0;

  /// [history] é o histórico inteiro (os recordes dependem do que veio
  /// antes do período).
  factory PeriodStats.from(
    Iterable<Workout> history,
    Period period, {
    int weeklyGoal = 1,
  }) {
    final all = history.toList();
    final inPeriod = all.where((w) => period.contains(w.date)).toList();

    var seconds = 0;
    var volume = 0.0;
    final byExercise =
        <String, (String, int, int)>{}; // id → nome, treinos, séries
    for (final w in inPeriod) {
      seconds += w.durationSeconds;
      volume += w.totalVolume;
      final seen = <String>{};
      for (final e in w.exercises) {
        final sets = e.sets.where((s) => !s.isWarmup).length;
        if (sets == 0) continue;
        final key = e.exerciseId.trim().isEmpty ? e.exerciseName : e.exerciseId;
        final (_, count, total) = byExercise[key] ?? (e.exerciseName, 0, 0);
        byExercise[key] = (
          e.exerciseName,
          count + (seen.add(key) ? 1 : 0),
          total + sets,
        );
      }
    }
    TopExercise? top;
    for (final (name, count, sets) in byExercise.values) {
      if (top == null ||
          count > top.workouts ||
          (count == top.workouts && sets > top.sets)) {
        top = TopExercise(name, count, sets);
      }
    }

    // Recordes: o histórico inteiro decide a marca anterior.
    final latest = <(String, PersonalRecordKind), PersonalRecord>{};
    final dated = recordsFromHistory(all)
        .where((r) => period.contains(r.date))
        .toList()
        .reversed;
    for (final r in dated) {
      latest.putIfAbsent((
        r.record.exerciseName,
        r.record.kind,
      ), () => r.record);
    }

    return PeriodStats(
      period: period,
      workouts: inPeriod.length,
      totalSeconds: seconds,
      volumeKg: volume,
      topExercise: top,
      records: latest.values.toList(),
      consecutiveWeeks: WeekSummary.longestStreak(
        WeekSummary.goalWeeks(inPeriod, goal: weeklyGoal),
        period.start,
        period.end,
      ),
    );
  }
}

/// "12 h 30 min", "45 min", "0 min".
String formatHours(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h == 0) return '$m min';
  return m == 0 ? '$h h' : '$h h $m min';
}
