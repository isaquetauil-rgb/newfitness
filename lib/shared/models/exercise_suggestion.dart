/// Uma sugestão de exercício devolvida pela Cloud Function
/// `suggestTrainingPlan` — o instrutor pode adicionar (ou usar pra
/// substituir um exercício) direto num sub-treino de um plano existente do
/// aluno (ver [AiSuggestionSheet]).
class ExerciseSuggestion {
  final String exerciseName;
  final int sets;
  final String reps;
  final int restSeconds;
  final String reason;

  const ExerciseSuggestion({
    required this.exerciseName,
    required this.sets,
    required this.reps,
    required this.restSeconds,
    required this.reason,
  });

  factory ExerciseSuggestion.fromMap(Map<String, dynamic> map) {
    return ExerciseSuggestion(
      exerciseName: map['exerciseName'] as String? ?? 'Exercício',
      sets: (map['sets'] as num?)?.toInt() ?? 3,
      reps: map['reps'] as String? ?? '10-12',
      restSeconds: (map['restSeconds'] as num?)?.toInt() ?? 60,
      reason: map['reason'] as String? ?? '',
    );
  }
}

/// Resultado de um pedido à IA: normalmente uma lista de 3-4
/// [ExerciseSuggestion]; se a IA não devolver um JSON válido, [suggestions]
/// vem vazio e [rawText] traz a resposta crua como fallback.
class TrainingSuggestionResult {
  final List<ExerciseSuggestion> suggestions;
  final String? rawText;

  const TrainingSuggestionResult({this.suggestions = const [], this.rawText});

  factory TrainingSuggestionResult.fromMap(Map<String, dynamic> map) {
    return TrainingSuggestionResult(
      suggestions:
          (map['suggestions'] as List<dynamic>?)
              ?.map(
                // O plugin de Cloud Functions pode devolver os itens da
                // lista como Map<Object?, Object?> em vez de
                // Map<String, dynamic> — por isso o cast explícito.
                (s) => ExerciseSuggestion.fromMap(
                  Map<String, dynamic>.from(s as Map),
                ),
              )
              .toList() ??
          const [],
      rawText: map['rawText'] as String?,
    );
  }
}
