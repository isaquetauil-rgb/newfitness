/// Exercícios sem grupo muscular (ficam fora do mapa muscular): achar e
/// completar. Lógica pura.
library;

import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/models/logged_exercise.dart';
import 'package:newfitness/shared/models/workout.dart';

/// Um exercício do histórico do aluno que o mapa não consegue colocar no
/// corpo: sem retrato de músculos no treino e fora da biblioteca (próprio
/// do aluno ou apagado antes do arquivamento existir).
class ExerciseWithoutGroup {
  const ExerciseWithoutGroup(this.exerciseId, this.name, this.workouts);
  final String exerciseId;
  final String name;

  /// Em quantos treinos aparece.
  final int workouts;
}

List<ExerciseWithoutGroup> exercisesWithoutGroup(
  Iterable<Workout> workouts,
  Exercise? Function(String exerciseId) lookup,
) {
  final names = <String, String>{};
  final counts = <String, int>{};
  for (final w in workouts) {
    final seen = <String>{};
    for (final e in w.exercises) {
      if ((e.muscleGroup ?? '').trim().isNotEmpty) continue;
      if (e.exerciseId.trim().isEmpty) continue;
      final found = lookup(e.exerciseId);
      if (found != null && found.muscleGroup.trim().isNotEmpty) continue;
      names.putIfAbsent(e.exerciseId, () => e.exerciseName);
      if (seen.add(e.exerciseId)) {
        counts[e.exerciseId] = (counts[e.exerciseId] ?? 0) + 1;
      }
    }
  }
  return [
    for (final id in names.keys)
      ExerciseWithoutGroup(id, names[id]!, counts[id] ?? 0),
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}

/// Treinos que mudam ao dar o grupo [muscleGroup] ao exercício
/// [exerciseId] (só os que têm esse exercício sem grupo).
List<Workout> withMuscleGroup(
  Iterable<Workout> workouts,
  String exerciseId,
  String muscleGroup,
) {
  final out = <Workout>[];
  for (final w in workouts) {
    var changed = false;
    final exercises = <LoggedExercise>[];
    for (final e in w.exercises) {
      if (e.exerciseId == exerciseId && (e.muscleGroup ?? '').trim().isEmpty) {
        exercises.add(e.copyWith(muscleGroup: muscleGroup));
        changed = true;
      } else {
        exercises.add(e);
      }
    }
    if (!changed) continue;
    out.add(
      Workout(
        id: w.id,
        userId: w.userId,
        date: w.date,
        name: w.name,
        exercises: exercises,
        durationSeconds: w.durationSeconds,
        source: w.source,
        importedFrom: w.importedFrom,
        importKey: w.importKey,
        notes: w.notes,
      ),
    );
  }
  return out;
}

/// Exercícios próprios do personal sem grupo muscular.
List<Exercise> customWithoutGroup(Iterable<Exercise> exercises) => [
  for (final e in exercises)
    if (!e.archived && e.muscleGroup.trim().isEmpty) e,
];

/// Cópia de [e] com o grupo muscular preenchido.
Exercise withExerciseGroup(Exercise e, String muscleGroup) =>
    Exercise.fromMap(e.id, {...e.toMap(), 'muscleGroup': muscleGroup});
