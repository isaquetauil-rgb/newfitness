import 'logged_exercise.dart';

/// Um treino completo: uma sessão feita em uma data, com vários exercícios.
class Workout {
  final String id;
  final String userId;
  final DateTime date;
  final String name;
  final List<LoggedExercise> exercises;
  final int durationSeconds;

  Workout({
    required this.id,
    required this.userId,
    required this.date,
    this.name = 'Treino',
    List<LoggedExercise>? exercises,
    this.durationSeconds = 0,
  }) : exercises = exercises ?? [];

  /// Volume total do treino (soma de reps * peso de todas as séries).
  double get totalVolume =>
      exercises.fold(0, (sum, e) => sum + e.totalVolume);

  int get totalSets =>
      exercises.fold(0, (sum, e) => sum + e.sets.length);

  factory Workout.fromMap(String id, Map<String, dynamic> map) {
    return Workout(
      id: id,
      userId: map['userId'] as String? ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(
        map['date'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      name: map['name'] as String? ?? 'Treino',
      exercises: (map['exercises'] as List<dynamic>?)
              ?.map((e) => LoggedExercise.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'date': date.millisecondsSinceEpoch,
      'name': name,
      'exercises': exercises.map((e) => e.toMap()).toList(),
      'durationSeconds': durationSeconds,
    };
  }
}
