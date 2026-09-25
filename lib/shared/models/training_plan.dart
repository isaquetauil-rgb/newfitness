/// Um exercício prescrito dentro de um [TrainingSubWorkout] — diferente de
/// [LoggedExercise] (que registra séries já executadas), este guarda metas
/// (séries/reps/peso/descanso alvo) definidas pelo instrutor.
class PlanExercise {
  final String exerciseId;
  final String exerciseName;
  final int targetSets;
  final String targetReps; // texto livre p/ permitir faixas, ex: "8-12"
  final String
  targetWeightsKg; // texto livre, 1 valor por série, ex: "40/50/60"
  final int restSeconds;
  final String? notes;

  /// Preenchido quando este exercício substituiu outro no plano (ver
  /// "Trocar exercício" em `PlanEditorScreen`) — guarda o exercício
  /// originalmente prescrito pelo instrutor, não o imediatamente anterior,
  /// então uma segunda troca continua apontando para a origem da cadeia.
  /// `null` quando nunca foi trocado.
  final String? replacedExerciseId;
  final String? replacedExerciseName;

  const PlanExercise({
    required this.exerciseId,
    required this.exerciseName,
    required this.targetSets,
    required this.targetReps,
    this.targetWeightsKg = '',
    this.restSeconds = 60,
    this.notes,
    this.replacedExerciseId,
    this.replacedExerciseName,
  });

  factory PlanExercise.fromMap(Map<String, dynamic> map) {
    return PlanExercise(
      exerciseId: map['exerciseId'] as String? ?? '',
      exerciseName: map['exerciseName'] as String? ?? '',
      targetSets: (map['targetSets'] as num?)?.toInt() ?? 3,
      targetReps: map['targetReps'] as String? ?? '',
      targetWeightsKg: map['targetWeightsKg'] as String? ?? '',
      restSeconds: (map['restSeconds'] as num?)?.toInt() ?? 60,
      notes: map['notes'] as String?,
      replacedExerciseId: map['replacedExerciseId'] as String?,
      replacedExerciseName: map['replacedExerciseName'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'exerciseId': exerciseId,
      'exerciseName': exerciseName,
      'targetSets': targetSets,
      'targetReps': targetReps,
      'targetWeightsKg': targetWeightsKg,
      'restSeconds': restSeconds,
      'notes': notes,
      'replacedExerciseId': replacedExerciseId,
      'replacedExerciseName': replacedExerciseName,
    };
  }

  /// Usado por "Trocar exercício" no editor de plano: troca o exercício
  /// mantendo séries/reps/peso/descanso/observações já preenchidos.
  PlanExercise copyWith({
    String? exerciseId,
    String? exerciseName,
    String? replacedExerciseId,
    String? replacedExerciseName,
  }) {
    return PlanExercise(
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      targetSets: targetSets,
      targetReps: targetReps,
      targetWeightsKg: targetWeightsKg,
      restSeconds: restSeconds,
      notes: notes,
      replacedExerciseId: replacedExerciseId ?? this.replacedExerciseId,
      replacedExerciseName: replacedExerciseName ?? this.replacedExerciseName,
    );
  }
}

/// Um sub-treino nomeado dentro de um plano (ex: "Treino A", "Treino B") —
/// cada um com sua própria lista de exercícios, seguindo o padrão comum de
/// divisão de treino por grupo muscular/dia.
class TrainingSubWorkout {
  final String label;
  final List<PlanExercise> exercises;

  const TrainingSubWorkout({required this.label, this.exercises = const []});

  factory TrainingSubWorkout.fromMap(Map<String, dynamic> map) {
    return TrainingSubWorkout(
      label: map['label'] as String? ?? 'Treino',
      exercises:
          (map['exercises'] as List<dynamic>?)
              ?.map((e) => PlanExercise.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'exercises': exercises.map((e) => e.toMap()).toList(),
    };
  }
}

/// Um plano de treino que um instrutor monta e atribui a um aluno —
/// guardado em `users/{studentUid}/training_plans/{id}` (só o instrutor
/// vinculado ao aluno pode criar/editar; o aluno só lê). Pode conter vários
/// sub-treinos nomeados (Treino A/B/C...), cada um iniciado separadamente
/// pelo aluno.
class TrainingPlan {
  final String id;
  final String studentUid;
  final String instructorUid;
  final String title;
  final String? instructions; // texto livre — pode vir de uma sugestão de IA
  final List<TrainingSubWorkout> workouts;
  final DateTime createdAt;

  const TrainingPlan({
    required this.id,
    required this.studentUid,
    required this.instructorUid,
    required this.title,
    this.instructions,
    this.workouts = const [],
    required this.createdAt,
  });

  factory TrainingPlan.fromMap(String id, Map<String, dynamic> map) {
    return TrainingPlan(
      id: id,
      studentUid: map['studentUid'] as String? ?? '',
      instructorUid: map['instructorUid'] as String? ?? '',
      title: map['title'] as String? ?? 'Plano de treino',
      instructions: map['instructions'] as String?,
      workouts:
          (map['workouts'] as List<dynamic>?)
              ?.map(
                (w) => TrainingSubWorkout.fromMap(w as Map<String, dynamic>),
              )
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
      'workouts': workouts.map((w) => w.toMap()).toList(),
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }
}
