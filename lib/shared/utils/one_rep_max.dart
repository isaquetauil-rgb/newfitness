/// 1RM estimado e detecção de recordes. Lógica pura: sem Flutter e sem
/// Firebase.
library;

import 'package:newfitness/shared/models/logged_exercise.dart';
import 'package:newfitness/shared/models/workout_set.dart';

import 'format.dart';

// Quem usa recordes quase sempre mostra peso junto.
export 'format.dart';

/// Faixa de reps em que a estimativa vale: acima de 12 ela erra demais.
const int e1rmMaxReps = 12;

/// 1RM estimado pela fórmula de Epley: peso × (1 + reps/30). Com 1 rep, o
/// 1RM é o próprio peso. `null` sem carga ou fora de 1 a 12 reps.
double? epley1rm(double weightKg, int reps) {
  if (weightKg <= 0 || reps < 1 || reps > e1rmMaxReps) return null;
  if (reps == 1) return weightKg;
  return weightKg * (1 + reps / 30);
}

/// Maior 1RM estimado entre as séries, ou `null` se nenhuma vale.
/// Aquecimento não conta.
double? bestE1rm(Iterable<WorkoutSet> sets) {
  double? best;
  for (final s in sets) {
    if (!s.countsForStats) continue;
    final e = epley1rm(s.weightKg, s.reps);
    if (e != null && (best == null || e > best)) best = e;
  }
  return best;
}

/// Maior carga entre as séries (0 se nenhuma tem carga). Aquecimento não
/// conta.
double bestLoad(Iterable<WorkoutSet> sets) => sets.fold(
  0,
  (max, s) => s.countsForStats && s.weightKg > max ? s.weightKg : max,
);

/// Maior tempo entre as séries por tempo (0 se nenhuma). Aquecimento não
/// conta.
int bestSeconds(Iterable<WorkoutSet> sets) =>
    sets.fold(0, (max, s) => !s.isWarmup && s.seconds > max ? s.seconds : max);

/// Melhores marcas já registradas de um exercício, antes do treino de hoje.
/// `null` = ainda não há marca (ex.: registros antigos sem 1RM).
class RecordBaseline {
  const RecordBaseline({this.bestLoadKg, this.bestE1rmKg, this.bestSeconds});

  final double? bestLoadKg;
  final double? bestE1rmKg;

  /// Maior tempo, nos exercícios por tempo.
  final int? bestSeconds;
}

/// Carga, 1RM estimado ou (exercício por tempo) maior tempo.
enum PersonalRecordKind { load, e1rm, duration }

class PersonalRecord {
  const PersonalRecord({
    required this.exerciseName,
    required this.kind,
    this.valueKg = 0,
    this.seconds = 0,
  });

  final String exerciseName;
  final PersonalRecordKind kind;
  final double valueKg;

  /// Recorde de tempo ([PersonalRecordKind.duration]).
  final int seconds;

  /// "Supino reto: carga 62,5 kg", "Supino reto: 1RM estimado 75 kg",
  /// "Prancha: maior tempo 45 s".
  String get label => switch (kind) {
    PersonalRecordKind.load => '$exerciseName: carga ${formatKg(valueKg)}',
    PersonalRecordKind.e1rm =>
      '$exerciseName: 1RM estimado ${formatKg(valueKg)}',
    PersonalRecordKind.duration =>
      '$exerciseName: maior tempo ${formatSeconds(seconds)}',
  };

  @override
  bool operator ==(Object other) =>
      other is PersonalRecord &&
      other.exerciseName == exerciseName &&
      other.kind == kind &&
      other.valueKg == valueKg &&
      other.seconds == seconds;

  @override
  int get hashCode => Object.hash(exerciseName, kind, valueKg, seconds);

  @override
  String toString() => label;
}

/// A série [set], acabada de marcar como feita, bateu algum recorde? Compara
/// com a marca registrada ([baseline]) e com as outras séries já feitas hoje
/// no mesmo exercício ([others]), para não comemorar duas vezes a mesma
/// carga. Sem marca anterior (primeira vez no exercício) não há recorde.
List<PersonalRecordKind> detectSetRecords(
  WorkoutSet set,
  Iterable<WorkoutSet> others,
  RecordBaseline? baseline,
) {
  if (baseline == null) return const [];
  // Exercício por tempo: o recorde é o maior tempo.
  if (set.isTimed) {
    final previous = baseline.bestSeconds;
    if (set.isWarmup || previous == null || previous <= 0) return const [];
    final today = bestSeconds(
      others.where((s) => s.completed && !identical(s, set)),
    );
    final bar = today > previous ? today : previous;
    return set.seconds > bar ? const [PersonalRecordKind.duration] : const [];
  }
  if (!set.countsForStats || set.weightKg <= 0 || set.reps <= 0) {
    return const [];
  }
  final doneOthers = others.where((s) => s.completed && !identical(s, set));
  final kinds = <PersonalRecordKind>[];

  final previousLoad = baseline.bestLoadKg;
  if (previousLoad != null && previousLoad > 0) {
    final today = bestLoad(doneOthers);
    final bar = today > previousLoad ? today : previousLoad;
    if (set.weightKg > bar) kinds.add(PersonalRecordKind.load);
  }

  final previousE1rm = baseline.bestE1rmKg;
  final e = epley1rm(set.weightKg, set.reps);
  if (previousE1rm != null && previousE1rm > 0 && e != null) {
    final today = bestE1rm(doneOthers) ?? 0;
    final bar = today > previousE1rm ? today : previousE1rm;
    if (e > bar + 1e-9) kinds.add(PersonalRecordKind.e1rm);
  }
  return kinds;
}

/// Recordes do treino inteiro, para o resumo final: por exercício, a maior
/// carga e o maior 1RM estimado do dia comparados com a marca anterior.
/// [baselines] é indexado por `exerciseId`.
List<PersonalRecord> recordsOfTheDay(
  List<LoggedExercise> exercises,
  Map<String, RecordBaseline> baselines,
) {
  // Junta entradas repetidas do mesmo exercício (ex.: bi-set).
  final byId = <String, (String, List<WorkoutSet>)>{};
  for (final e in exercises) {
    if (e.exerciseId.trim().isEmpty) continue;
    final entry = byId.putIfAbsent(e.exerciseId, () => (e.exerciseName, []));
    entry.$2.addAll(e.sets);
  }

  final records = <PersonalRecord>[];
  byId.forEach((id, entry) {
    final (name, sets) = entry;
    final baseline = baselines[id];
    if (baseline == null) return;
    final load = bestLoad(sets);
    final previousLoad = baseline.bestLoadKg;
    if (previousLoad != null && previousLoad > 0 && load > previousLoad) {
      records.add(
        PersonalRecord(
          exerciseName: name,
          kind: PersonalRecordKind.load,
          valueKg: load,
        ),
      );
    }
    final secs = bestSeconds(sets);
    final previousSecs = baseline.bestSeconds;
    if (previousSecs != null && previousSecs > 0 && secs > previousSecs) {
      records.add(
        PersonalRecord(
          exerciseName: name,
          kind: PersonalRecordKind.duration,
          seconds: secs,
        ),
      );
    }
    final e = bestE1rm(sets);
    final previousE1rm = baseline.bestE1rmKg;
    if (e != null &&
        previousE1rm != null &&
        previousE1rm > 0 &&
        e > previousE1rm + 1e-9) {
      records.add(
        PersonalRecord(
          exerciseName: name,
          kind: PersonalRecordKind.e1rm,
          valueKg: roundKg(e),
        ),
      );
    }
  });
  return records;
}

/// Arredonda para 0,1 kg (para mostrar e gravar o 1RM estimado).
double roundKg(double kg) => (kg * 10).round() / 10;
