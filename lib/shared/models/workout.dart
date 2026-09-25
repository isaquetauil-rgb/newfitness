import 'logged_exercise.dart';

/// De qual plano/sub-treino um treino foi iniciado (ver
/// `WorkoutProvider.startFromPlan`). Cópia dos dados no momento do início —
/// o histórico continua mostrando a origem mesmo se o plano for renomeado
/// ou apagado depois. Ausente em treino livre e em treinos antigos.
class WorkoutSource {
  final String planId;
  final String planTitle;
  final String subWorkoutLabel;

  const WorkoutSource({
    required this.planId,
    required this.planTitle,
    required this.subWorkoutLabel,
  });

  factory WorkoutSource.fromMap(Map<String, dynamic> map) {
    return WorkoutSource(
      planId: map['planId'] as String? ?? '',
      planTitle: map['planTitle'] as String? ?? '',
      subWorkoutLabel: map['subWorkoutLabel'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'planId': planId,
      'planTitle': planTitle,
      'subWorkoutLabel': subWorkoutLabel,
    };
  }
}

/// Um treino completo: uma sessão feita em uma data, com vários exercícios.
class Workout {
  final String id;
  final String userId;
  final DateTime date;
  final String name;
  final List<LoggedExercise> exercises;
  final int durationSeconds;

  /// Origem do treino quando iniciado a partir de um plano; `null` em
  /// treino livre.
  final WorkoutSource? source;

  Workout({
    required this.id,
    required this.userId,
    required this.date,
    this.name = 'Treino',
    List<LoggedExercise>? exercises,
    this.durationSeconds = 0,
    this.source,
  }) : exercises = exercises ?? [];

  /// Volume total do treino (soma de reps * peso de todas as séries).
  double get totalVolume => exercises.fold(0, (sum, e) => sum + e.totalVolume);

  int get totalSets => exercises.fold(0, (sum, e) => sum + e.sets.length);

  factory Workout.fromMap(String id, Map<String, dynamic> map) {
    final rawSource = map['source'];
    return Workout(
      id: id,
      userId: map['userId'] as String? ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(
        map['date'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      name: map['name'] as String? ?? 'Treino',
      exercises:
          (map['exercises'] as List<dynamic>?)
              ?.map(
                (e) =>
                    LoggedExercise.fromMap(Map<String, dynamic>.from(e as Map)),
              )
              .toList() ??
          [],
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      source: rawSource is Map
          ? WorkoutSource.fromMap(Map<String, dynamic>.from(rawSource))
          : null,
    );
  }

  /// `source` é omitido quando nulo (treino livre/antigo).
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'date': date.millisecondsSinceEpoch,
      'name': name,
      'exercises': exercises.map((e) => e.toMap()).toList(),
      'durationSeconds': durationSeconds,
      'source': ?source?.toMap(),
    };
  }
}
