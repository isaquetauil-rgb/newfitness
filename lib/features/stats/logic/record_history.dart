/// Recordes recalculados a partir do histórico, treino a treino, com a
/// mesma regra do resumo do fim do treino ([recordsOfTheDay]). Lógica pura.
library;

import 'package:newfitness/shared/models/workout.dart';
import 'package:newfitness/shared/models/workout_set.dart';
import 'package:newfitness/shared/utils/one_rep_max.dart';

/// Um recorde e o treino em que foi batido.
class DatedRecord {
  const DatedRecord(this.date, this.record);
  final DateTime date;
  final PersonalRecord record;
}

/// Refaz o histórico do mais antigo para o mais recente e devolve cada
/// recorde batido. Como no app, a primeira vez num exercício só cria a
/// marca (não é recorde).
List<DatedRecord> recordsFromHistory(Iterable<Workout> workouts) {
  final ordered = workouts.toList()..sort((a, b) => a.date.compareTo(b.date));
  final baselines = <String, RecordBaseline>{};
  final out = <DatedRecord>[];

  for (final workout in ordered) {
    for (final r in recordsOfTheDay(workout.exercises, baselines)) {
      out.add(DatedRecord(workout.date, r));
    }
    // Atualiza as marcas com o que foi feito neste treino.
    // Junta entradas repetidas do mesmo exercício (ex.: bi-set).
    final setsById = <String, List<WorkoutSet>>{};
    for (final e in workout.exercises) {
      if (e.exerciseId.trim().isEmpty) continue;
      (setsById[e.exerciseId] ??= []).addAll(e.sets);
    }
    for (final MapEntry(key: id, value: sets) in setsById.entries) {
      final old = baselines[id];
      final load = bestLoad(sets);
      final e1rm = bestE1rm(sets);
      final secs = bestSeconds(sets);
      baselines[id] = RecordBaseline(
        bestLoadKg: _max(old?.bestLoadKg, load),
        bestE1rmKg: _max(old?.bestE1rmKg, e1rm),
        bestSeconds: _maxInt(old?.bestSeconds, secs),
      );
    }
  }
  return out;
}

double _max(double? a, double? b) => (a ?? 0) > (b ?? 0) ? a! : (b ?? 0);
int _maxInt(int? a, int b) => (a ?? 0) > b ? a! : b;
