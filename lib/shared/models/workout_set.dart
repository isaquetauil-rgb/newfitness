/// Tipo da série. Gravado em `type` como texto; séries antigas (sem o campo)
/// são [SetType.normal].
enum SetType {
  normal,

  /// Leve, antes das séries de trabalho: não conta no volume, no recorde
  /// nem na sugestão de carga.
  warmup,

  /// Drop set: logo depois de outra série, com carga menor.
  drop,

  /// Até a falha.
  failure,
}

extension SetTypeText on SetType {
  /// Nome em pt-BR.
  String get label => switch (this) {
    SetType.normal => 'Normal',
    SetType.warmup => 'Aquecimento',
    SetType.drop => 'Drop',
    SetType.failure => 'Até a falha',
  };

  /// Letra curta para a linha da série ("A", "D", "F"); vazia na normal.
  String get letter => switch (this) {
    SetType.normal => '',
    SetType.warmup => 'A',
    SetType.drop => 'D',
    SetType.failure => 'F',
  };
}

SetType setTypeFromString(String? value) => switch (value) {
  'warmup' => SetType.warmup,
  'drop' => SetType.drop,
  'failure' => SetType.failure,
  _ => SetType.normal,
};

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

  SetType type;

  WorkoutSet({
    this.reps = 0,
    this.weightKg = 0,
    this.completed = false,
    this.suggested = false,
    this.type = SetType.normal,
  });

  bool get isWarmup => type == SetType.warmup;

  /// Conta para volume, recordes e sugestão de carga (tudo menos aquecimento).
  bool get countsForStats => type != SetType.warmup;

  factory WorkoutSet.fromMap(Map<String, dynamic> map) {
    return WorkoutSet(
      reps: (map['reps'] as num?)?.toInt() ?? 0,
      weightKg: (map['weightKg'] as num?)?.toDouble() ?? 0,
      completed: map['completed'] as bool? ?? false,
      suggested: map['suggested'] as bool? ?? false,
      type: setTypeFromString(map['type'] as String?),
    );
  }

  /// `type` só é gravado quando não é normal (dados antigos continuam iguais).
  Map<String, dynamic> toMap() {
    return {
      'reps': reps,
      'weightKg': weightKg,
      'completed': completed,
      if (suggested) 'suggested': true,
      if (type != SetType.normal) 'type': type.name,
    };
  }

  WorkoutSet copy() => WorkoutSet(
    reps: reps,
    weightKg: weightKg,
    completed: completed,
    suggested: suggested,
    type: type,
  );
}
