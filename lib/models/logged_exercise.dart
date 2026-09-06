import 'workout_set.dart';

/// Um exercício dentro de um treino em andamento (ou já concluído),
/// junto com todas as séries realizadas.
class LoggedExercise {
  final String exerciseId;
  final String exerciseName;
  final List<WorkoutSet> sets;

  LoggedExercise({
    required this.exerciseId,
    required this.exerciseName,
    List<WorkoutSet>? sets,
  }) : sets = sets ?? [WorkoutSet()];

  double get totalVolume =>
      sets.fold(0, (sum, s) => sum + (s.reps * s.weightKg));

  factory LoggedExercise.fromMap(Map<String, dynamic> map) {
    return LoggedExercise(
      exerciseId: map['exerciseId'] as String? ?? '',
      exerciseName: map['exerciseName'] as String? ?? '',
      sets: (map['sets'] as List<dynamic>?)
              ?.map((s) => WorkoutSet.fromMap(s as Map<String, dynamic>))
              .toList() ??
          [WorkoutSet()],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'exerciseId': exerciseId,
      'exerciseName': exerciseName,
      'sets': sets.map((s) => s.toMap()).toList(),
    };
  }
}
