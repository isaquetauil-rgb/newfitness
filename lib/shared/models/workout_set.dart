/// Uma série individual de um exercício (ex: 10 repetições com 40kg).
class WorkoutSet {
  int reps;
  double weightKg;
  bool completed;

  /// Peso e reps vieram da sugestão de carga e o aluno ainda não mexeu nem
  /// marcou a série como feita. Enquanto for `true`, a série conta como vazia
  /// (não vai para o histórico). Só é gravado quando `true` (no rascunho
  /// local do treino em andamento); no histórico nunca aparece.
  bool suggested;

  WorkoutSet({
    this.reps = 0,
    this.weightKg = 0,
    this.completed = false,
    this.suggested = false,
  });

  factory WorkoutSet.fromMap(Map<String, dynamic> map) {
    return WorkoutSet(
      reps: (map['reps'] as num?)?.toInt() ?? 0,
      weightKg: (map['weightKg'] as num?)?.toDouble() ?? 0,
      completed: map['completed'] as bool? ?? false,
      suggested: map['suggested'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reps': reps,
      'weightKg': weightKg,
      'completed': completed,
      if (suggested) 'suggested': true,
    };
  }

  WorkoutSet copy() => WorkoutSet(
    reps: reps,
    weightKg: weightKg,
    completed: completed,
    suggested: suggested,
  );
}
