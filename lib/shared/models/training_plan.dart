/// Um exercício prescrito dentro de um [TrainingPlan] — diferente de
/// [LoggedExercise] (que registra séries já executadas), este guarda
/// metas (séries/reps alvo) definidas pelo instrutor.
class PlanExercise {
  final String exerciseId;
  final String exerciseName;
  final int targetSets;
  final String targetReps; // texto livre p/ permitir faixas, ex: "8-12"
  final String? notes;

  const PlanExercise({
    required this.exerciseId,
    required this.exerciseName,
    required this.targetSets,
    required this.targetReps,
    this.notes,
  });

  factory PlanExercise.fromMap(Map<String, dynamic> map) {
    return PlanExercise(
      exerciseId: map['exerciseId'] as String? ?? '',
      exerciseName: map['exerciseName'] as String? ?? '',
      targetSets: (map['targetSets'] as num?)?.toInt() ?? 3,
      targetReps: map['targetReps'] as String? ?? '',
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'exerciseId': exerciseId,
      'exerciseName': exerciseName,
      'targetSets': targetSets,
      'targetReps': targetReps,
      'notes': notes,
    };
  }
}

/// Um plano de treino que um instrutor monta e atribui a um aluno —
/// guardado em `users/{studentUid}/training_plans/{id}` (só o instrutor
/// vinculado ao aluno pode criar/editar; o aluno só lê).
class TrainingPlan {
  final String id;
  final String studentUid;
  final String instructorUid;
  final String title;
  final String? instructions; // texto livre — pode vir de uma sugestão de IA
  final List<PlanExercise> exercises;
  final DateTime createdAt;

  const TrainingPlan({
    required this.id,
    required this.studentUid,
    required this.instructorUid,
    required this.title,
    this.instructions,
    this.exercises = const [],
    required this.createdAt,
  });

  factory TrainingPlan.fromMap(String id, Map<String, dynamic> map) {
    return TrainingPlan(
      id: id,
      studentUid: map['studentUid'] as String? ?? '',
      instructorUid: map['instructorUid'] as String? ?? '',
      title: map['title'] as String? ?? 'Plano de treino',
      instructions: map['instructions'] as String?,
      exercises:
          (map['exercises'] as List<dynamic>?)
              ?.map((e) => PlanExercise.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentUid': studentUid,
      'instructorUid': instructorUid,
      'title': title,
      'instructions': instructions,
      'exercises': exercises.map((e) => e.toMap()).toList(),
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }
}
