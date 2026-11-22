/// Duração real do treino e treino esquecido aberto. Lógica pura.
///
/// A duração não é mais "hora em que tocou em Finalizar − início": é até a
/// última série concluída (mais o descanso dela). Assim, um treino esquecido
/// aberto não vira uma sessão de dias no histórico nem no Health Connect.
library;

import 'package:newfitness/shared/models/workout.dart';
import 'package:newfitness/shared/models/workout_set.dart';

/// Tempo sem nenhuma série marcada para considerar o treino esquecido.
const Duration staleWorkoutAfter = Duration(hours: 3);

/// Duração máxima de treinos antigos (gravados sem a hora das séries).
const Duration legacyMaxDuration = Duration(hours: 3);

/// Descanso depois de uma série (0 se não houver). Recebe o índice do
/// exercício no treino e a série.
typedef RestFor = int Function(int exerciseIndex, WorkoutSet set);

/// A última série concluída (com hora) e o índice do exercício dela.
({DateTime at, int exerciseIndex, WorkoutSet set})? lastCompletedSet(
  Workout workout,
) {
  ({DateTime at, int exerciseIndex, WorkoutSet set})? last;
  for (var i = 0; i < workout.exercises.length; i++) {
    for (final s in workout.exercises[i].sets) {
      final at = s.completedAt;
      if (!s.completed || at == null) continue;
      if (last == null || at.isAfter(last.at)) {
        last = (at: at, exerciseIndex: i, set: s);
      }
    }
  }
  return last;
}

/// O treino tem alguma série marcada como concluída?
bool hasCompletedSet(Workout workout) =>
    workout.exercises.any((e) => e.sets.any((s) => s.completed));

/// Fim real do treino: hora da última série concluída + o descanso dela.
/// Sem nenhuma série com hora (rascunho antigo), vale o que vier antes:
/// [now] ou [startedAt] + [legacyMaxDuration]. Nunca antes do início nem
/// depois de [now].
DateTime realWorkoutEnd(
  Workout workout,
  DateTime startedAt,
  DateTime now, {
  RestFor? restFor,
}) {
  final last = lastCompletedSet(workout);
  DateTime end;
  if (last == null) {
    final cap = startedAt.add(legacyMaxDuration);
    end = now.isBefore(cap) ? now : cap;
  } else {
    final rest = restFor?.call(last.exerciseIndex, last.set) ?? 0;
    end = last.at.add(Duration(seconds: rest > 0 ? rest : 0));
  }
  if (end.isAfter(now)) end = now;
  if (end.isBefore(startedAt)) end = startedAt;
  return end;
}

/// Momento da última atividade: a última série concluída ou o início.
DateTime lastActivityAt(Workout workout, DateTime startedAt) {
  final last = lastCompletedSet(workout)?.at;
  return last != null && last.isAfter(startedAt) ? last : startedAt;
}

/// O treino em andamento ficou mais de [staleWorkoutAfter] sem nenhuma
/// série marcada?
bool isStaleWorkout(Workout workout, DateTime startedAt, DateTime now) =>
    now.difference(lastActivityAt(workout, startedAt)) > staleWorkoutAfter;

/// Duração a usar de um treino JÁ gravado: a gravada, mas treinos antigos
/// (sem a hora das séries) ficam limitados a [legacyMaxDuration].
int effectiveDurationSeconds(Workout workout) {
  final hasTimes = workout.exercises.any(
    (e) => e.sets.any((s) => s.completedAt != null),
  );
  if (hasTimes) return workout.durationSeconds;
  final cap = legacyMaxDuration.inSeconds;
  return workout.durationSeconds > cap ? cap : workout.durationSeconds;
}
