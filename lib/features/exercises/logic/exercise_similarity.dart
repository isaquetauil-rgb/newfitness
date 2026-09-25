import 'package:newfitness/shared/models/exercise.dart';

/// Um candidato a substituto de um exercício, com a pontuação e o motivo
/// (mostrados na `ExerciseAlternativesSheet` para o usuário entender por que
/// aquela sugestão apareceu).
class ExerciseAlternative {
  final Exercise exercise;
  final double score; // 0.0 a 1.0 — 1.0 = curado manualmente (ou IA).
  final String reason;
  final bool curated;

  const ExerciseAlternative({
    required this.exercise,
    required this.score,
    required this.reason,
    this.curated = false,
  });
}

/// Encontra exercícios alternativos/equivalentes a [target] dentro de
/// [pool] (biblioteca global + biblioteca privada do instrutor, por
/// exemplo).
///
/// Funciona em duas camadas, hoje 100% sem IA:
/// 1. Curadoria manual: os ids em `target.alternativeExerciseIds` sempre
///    aparecem primeiro, com pontuação máxima.
/// 2. Similaridade estruturada: para completar até [limit], o restante do
///    [pool] é pontuado por grupo muscular, músculos secundários, padrão de
///    movimento, equipamento, nível de dificuldade e objetivo (ver
///    [_scoreSimilarity]) e ordenado do mais parecido para o menos.
///
/// Arquitetura pensada para depois receber uma 3ª camada opcional (IA): uma
/// função assíncrona equivalente poderia chamar uma Cloud Function (mesmo
/// padrão de `functions/src/anthropic.ts`) para reordenar ou completar esta
/// lista e/ou para sugerir novos valores de `movementPattern`/`objectives`/
/// `alternativeExerciseIds` a serem gravados no exercício — mas a troca
/// nunca depende disso: o cálculo aqui já é suficiente sozinho.
List<ExerciseAlternative> findExerciseAlternatives(
  Exercise target,
  List<Exercise> pool, {
  int limit = 8,
  double minScore = 0.3,
  Set<String> excludeIds = const {},
}) {
  final byId = {for (final e in pool) e.id: e};
  final results = <ExerciseAlternative>[];
  final usedIds = <String>{target.id, ...excludeIds};

  for (final id in target.alternativeExerciseIds) {
    final candidate = byId[id];
    if (candidate == null || !usedIds.add(candidate.id)) continue;
    results.add(
      ExerciseAlternative(
        exercise: candidate,
        score: 1.0,
        reason: 'Selecionado como substituto deste exercício',
        curated: true,
      ),
    );
  }

  final scored = <ExerciseAlternative>[];
  for (final candidate in pool) {
    if (usedIds.contains(candidate.id)) continue;
    final (score, reason) = _scoreSimilarity(target, candidate);
    if (score < minScore) continue;
    scored.add(
      ExerciseAlternative(exercise: candidate, score: score, reason: reason),
    );
  }
  scored.sort((a, b) => b.score.compareTo(a.score));

  results.addAll(scored);
  if (results.length > limit) return results.sublist(0, limit);
  return results;
}

/// Resolve `target.variationExerciseIds` para os [Exercise] correspondentes
/// dentro de [pool] — puramente curado (sem pontuação automática), já que
/// variação (mesmo movimento, ângulo/equipamento diferente) é uma relação
/// mais específica do que similaridade geral. Ver [findExerciseAlternatives]
/// para os substitutos (curados + calculados por semelhança).
List<Exercise> findExerciseVariations(Exercise target, List<Exercise> pool) {
  final byId = {for (final e in pool) e.id: e};
  return [
    for (final id in target.variationExerciseIds)
      if (id != target.id && byId[id] != null) byId[id]!,
  ];
}

(double, String) _scoreSimilarity(Exercise target, Exercise candidate) {
  double score = 0;
  final reasons = <String>[];

  final sameMuscleGroup =
      target.muscleGroup.isNotEmpty &&
      _normalized(target.muscleGroup) == _normalized(candidate.muscleGroup);
  if (sameMuscleGroup) {
    score += 0.4;
    reasons.add('mesmo grupo muscular');
  }

  final secondaryOverlap = _overlapRatio(
    target.secondaryMuscles,
    candidate.secondaryMuscles,
  );
  if (secondaryOverlap > 0) {
    score += 0.2 * secondaryOverlap;
    reasons.add('músculos secundários parecidos');
  } else if (!sameMuscleGroup &&
      _normalized(target.muscleGroup).isNotEmpty &&
      candidate.secondaryMuscles.any(
        (m) => _normalized(m) == _normalized(target.muscleGroup),
      )) {
    // Ex: alvo é "Tríceps" isolado, candidato é "Peito" com tríceps como
    // secundário (supino fechado) — ainda vale como alternativa parcial.
    score += 0.15;
    reasons.add('ativa o mesmo músculo como secundário');
  }

  final sameMovementPattern =
      target.movementPattern.isNotEmpty &&
      _normalized(target.movementPattern) ==
          _normalized(candidate.movementPattern);
  if (sameMovementPattern) {
    score += 0.2;
    reasons.add('mesmo padrão de movimento');
  }

  final sameEquipment =
      target.equipment.isNotEmpty &&
      _normalized(target.equipment) == _normalized(candidate.equipment);
  if (sameEquipment) {
    score += 0.1;
    reasons.add('mesmo equipamento');
  }

  final objectiveOverlap = _overlapRatio(
    target.objectives,
    candidate.objectives,
  );
  if (objectiveOverlap > 0) {
    score += 0.1 * objectiveOverlap;
    reasons.add('mesmo objetivo');
  }

  if (target.difficultyLevel.isNotEmpty &&
      target.difficultyLevel == candidate.difficultyLevel) {
    score += 0.1;
    reasons.add('mesmo nível de dificuldade');
  }

  if (score > 1) score = 1;
  final reason = reasons.isEmpty
      ? 'Possível alternativa'
      : reasons.first[0].toUpperCase() + reasons.first.substring(1);
  return (score, reason);
}

double _overlapRatio(List<String> a, List<String> b) {
  if (a.isEmpty || b.isEmpty) return 0;
  final setA = a.map(_normalized).toSet();
  final setB = b.map(_normalized).toSet();
  final intersection = setA.intersection(setB).length;
  if (intersection == 0) return 0;
  final union = setA.union(setB).length;
  return intersection / union;
}

String _normalized(String value) => value.trim().toLowerCase();
