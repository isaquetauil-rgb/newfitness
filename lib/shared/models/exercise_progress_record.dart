import 'logged_exercise.dart';

/// Entrada agregada de um exercício dentro de um treino — ver
/// [aggregateProgressInputs].
class ExerciseProgressInput {
  final String exerciseName;
  final double topSetLoadKg;
  final double totalVolume;

  const ExerciseProgressInput({
    required this.exerciseName,
    required this.topSetLoadKg,
    required this.totalVolume,
  });
}

/// Agrega os exercícios de um treino por `exerciseId` antes de gravar o
/// progresso (ver `FirestoreService.recordExerciseProgress`) — assim um
/// exercício que aparece mais de uma vez no mesmo treino (ex: adicionado
/// duas vezes por engano, ou um bloco tipo bi-set) conta como UMA sessão,
/// com a maior carga de topo entre as entradas e o volume somado, em vez de
/// contar (e duplicar o histórico) uma vez por entrada. Exercícios sem
/// nenhuma carga/volume registrado (ex: adicionado mas nenhuma série
/// preenchida) são ignorados. Lógica pura, sem Firestore — por isso
/// diretamente testável.
Map<String, ExerciseProgressInput> aggregateProgressInputs(
  List<LoggedExercise> exercises,
) {
  final aggregated = <String, ExerciseProgressInput>{};
  for (final exercise in exercises) {
    // Sem ID não há documento de progresso possível (`progress_records/{id}`)
    // — ex: exercício sugerido pela IA que não existe na biblioteca. Ele é
    // ignorado aqui (não trava os demais) e dois exercícios sem ID nunca
    // são somados como se fossem o mesmo.
    if (exercise.exerciseId.trim().isEmpty) continue;
    final topSetLoad = exercise.sets.fold<double>(
      0,
      (max, s) => s.weightKg > max ? s.weightKg : max,
    );
    final totalVolume = exercise.totalVolume;
    if (topSetLoad <= 0 && totalVolume <= 0) continue;

    final current = aggregated[exercise.exerciseId];
    aggregated[exercise.exerciseId] = ExerciseProgressInput(
      exerciseName: exercise.exerciseName,
      topSetLoadKg: current == null || topSetLoad > current.topSetLoadKg
          ? topSetLoad
          : current.topSetLoadKg,
      totalVolume: (current?.totalVolume ?? 0) + totalVolume,
    );
  }
  return aggregated;
}

/// Um ponto de progresso: o resumo de um exercício dentro de um treino
/// finalizado específico — carga do melhor set daquele dia e o volume total
/// do exercício naquele treino (reps × peso somado de todas as séries).
class ProgressPoint {
  final DateTime date;
  final double topSetLoadKg;
  final double totalVolume;

  const ProgressPoint({
    required this.date,
    required this.topSetLoadKg,
    required this.totalVolume,
  });

  factory ProgressPoint.fromMap(Map<String, dynamic> map) {
    return ProgressPoint(
      date: DateTime.fromMillisecondsSinceEpoch(
        map['date'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      topSetLoadKg: (map['topSetLoadKg'] as num?)?.toDouble() ?? 0,
      totalVolume: (map['totalVolume'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date.millisecondsSinceEpoch,
      'topSetLoadKg': topSetLoadKg,
      'totalVolume': totalVolume,
    };
  }
}

/// Rollup de evolução de UM exercício para UM aluno — `users/{uid}/
/// progress_records/{exerciseId}`, um documento por exercício, atualizado
/// (nunca recriado do zero) a cada treino finalizado que contenha aquele
/// exercício (ver `WorkoutProvider.finishWorkout` e
/// `FirestoreService.recordExerciseProgress`).
///
/// Existe pra responder "como evoluiu minha carga nesse exercício" com 1
/// leitura, em vez de escanear todo o histórico de treinos do usuário toda
/// vez que a tela de progresso abre.
class ExerciseProgressRecord {
  final String exerciseId;
  final String exerciseName;
  final double bestLoadKg;
  final double lastLoadKg;
  final DateTime lastPerformedAt;
  final int totalSessions;

  /// Histórico limitado (mais recentes por último) — usado pra desenhar um
  /// gráfico de evolução; ver `_historyLimit` em `FirestoreService`.
  final List<ProgressPoint> history;

  const ExerciseProgressRecord({
    required this.exerciseId,
    required this.exerciseName,
    required this.bestLoadKg,
    required this.lastLoadKg,
    required this.lastPerformedAt,
    required this.totalSessions,
    this.history = const [],
  });

  factory ExerciseProgressRecord.fromMap(String id, Map<String, dynamic> map) {
    return ExerciseProgressRecord(
      exerciseId: id,
      exerciseName: map['exerciseName'] as String? ?? '',
      bestLoadKg: (map['bestLoadKg'] as num?)?.toDouble() ?? 0,
      lastLoadKg: (map['lastLoadKg'] as num?)?.toDouble() ?? 0,
      lastPerformedAt: DateTime.fromMillisecondsSinceEpoch(
        map['lastPerformedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      totalSessions: (map['totalSessions'] as num?)?.toInt() ?? 0,
      history:
          (map['history'] as List<dynamic>?)
              ?.map(
                (e) =>
                    ProgressPoint.fromMap(Map<String, dynamic>.from(e as Map)),
              )
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'exerciseName': exerciseName,
      'bestLoadKg': bestLoadKg,
      'lastLoadKg': lastLoadKg,
      'lastPerformedAt': lastPerformedAt.millisecondsSinceEpoch,
      'totalSessions': totalSessions,
      'history': history.map((p) => p.toMap()).toList(),
    };
  }

  /// Calcula o novo rollup depois de mais um treino com este exercício —
  /// lógica pura (sem Firestore), usada por
  /// `FirestoreService.recordExerciseProgress` e diretamente testável.
  /// [existing] é `null` na primeira vez que o exercício é registrado.
  static ExerciseProgressRecord merge({
    required ExerciseProgressRecord? existing,
    required String exerciseId,
    required String exerciseName,
    required DateTime date,
    required double topSetLoadKg,
    required double totalVolume,
    int historyLimit = 50,
  }) {
    final history = [
      ...?existing?.history,
      ProgressPoint(
        date: date,
        topSetLoadKg: topSetLoadKg,
        totalVolume: totalVolume,
      ),
    ];
    final trimmedHistory = history.length > historyLimit
        ? history.sublist(history.length - historyLimit)
        : history;

    return ExerciseProgressRecord(
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      bestLoadKg: existing == null || topSetLoadKg > existing.bestLoadKg
          ? topSetLoadKg
          : existing.bestLoadKg,
      lastLoadKg: topSetLoadKg,
      lastPerformedAt: date,
      totalSessions: (existing?.totalSessions ?? 0) + 1,
      history: trimmedHistory,
    );
  }
}
