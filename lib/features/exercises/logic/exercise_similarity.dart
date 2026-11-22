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

// ---------- Casamento por NOME (importação do Hevy/Strong) ----------

/// Um exercício da biblioteca que pode ser o [name] vindo de outro app.
class ExerciseNameMatch {
  const ExerciseNameMatch(this.exercise, this.score);
  final Exercise exercise;

  /// 0 a 1. A partir de [autoNameMatchScore] o app já escolhe sozinho.
  final double score;
}

/// Pontuação a partir da qual o casamento é automático (o aluno ainda pode
/// trocar na prévia).
const double autoNameMatchScore = 0.75;

const _stopWords = {
  'de',
  'da',
  'do',
  'das',
  'dos',
  'com',
  'na',
  'no',
  'em',
  'e',
  'a',
  'o',
  'the',
  'of',
  'with',
  'on',
  'and',
};

/// Equipamento → palavra canônica. Vale para o texto entre parênteses do
/// Hevy/Strong ("(Barbell)"), para o campo `equipment` da biblioteca e para
/// palavras do id ("dumbbell_row").
const _equipmentWords = {
  'barbell': 'barbell',
  'barra': 'barbell',
  'bar': 'barbell',
  'dumbbell': 'dumbbell',
  'dumbbells': 'dumbbell',
  'halteres': 'dumbbell',
  'halter': 'dumbbell',
  'cable': 'cable',
  'polia': 'cable',
  'cabo': 'cable',
  'machine': 'machine',
  'maquina': 'machine',
  'smith': 'machine',
  'bodyweight': 'bodyweight',
  'band': 'band',
  'elastico': 'band',
  'kettlebell': 'kettlebell',
};

String _plain(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[áàâã]'), 'a')
    .replaceAll(RegExp('[éê]'), 'e')
    .replaceAll('í', 'i')
    .replaceAll(RegExp('[óôõ]'), 'o')
    .replaceAll('ú', 'u')
    .replaceAll('ç', 'c');

Set<String> _tokens(String s) => {
  for (final t in _plain(s).split(RegExp('[^a-z0-9]+')))
    if (t.isNotEmpty && !_stopWords.contains(t))
      // "raises" ≈ "raise", "biceps" ≈ "bicep".
      t.length > 4 && t.endsWith('s') ? t.substring(0, t.length - 1) : t,
};

String? _equipmentOf(Iterable<String> tokens) {
  for (final t in tokens) {
    final e = _equipmentWords[t];
    if (e != null) return e;
  }
  return null;
}

/// Exercícios de [pool] cujo nome lembra [name] (ex.: "Bench Press
/// (Barbell)" → Supino reto, id `bench_press`), do mais parecido para o
/// menos. Compara as palavras com o id, o nome, o nome alternativo e as
/// tags de busca, e usa o equipamento entre parênteses para desempatar.
List<ExerciseNameMatch> matchExercisesByName(
  String name,
  List<Exercise> pool, {
  int limit = 5,
  double minScore = 0.3,
}) {
  final paren = RegExp(r'\(([^)]*)\)').allMatches(name);
  final wantedEquipment = _equipmentOf({
    for (final m in paren) ..._tokens(m.group(1)!),
  });
  final core = _tokens(name.replaceAll(RegExp(r'\([^)]*\)'), ' '))
    ..removeWhere(_equipmentWords.containsKey);
  if (core.isEmpty) return const [];

  final results = <ExerciseNameMatch>[];
  for (final e in pool) {
    final idTokens = _tokens(e.id.replaceAll('_', ' '));
    final candidates = [
      idTokens,
      _tokens(e.name),
      if (e.alternateName.isNotEmpty) _tokens(e.alternateName),
      for (final tag in e.searchTags) _tokens(tag),
    ];
    var best = 0.0;
    for (final c in candidates) {
      final words = c.where((t) => !_equipmentWords.containsKey(t)).toSet();
      if (words.isEmpty) continue;
      final inter = words.intersection(core).length;
      if (inter == 0) continue;
      final jaccard = inter / words.union(core).length;
      if (jaccard > best) best = jaccard;
    }
    if (best == 0) continue;
    if (wantedEquipment != null) {
      final has = _equipmentOf(idTokens) ?? _equipmentOf(_tokens(e.equipment));
      if (has == wantedEquipment) {
        best += 0.1;
      } else if (has != null) {
        best -= 0.2;
      }
    }
    final score = best.clamp(0.0, 1.0);
    if (score >= minScore) results.add(ExerciseNameMatch(e, score));
  }
  results.sort((a, b) => b.score.compareTo(a.score));
  return results.length > limit ? results.sublist(0, limit) : results;
}

/// Grupo muscular sugerido para um exercício sem grupo, pelo nome: o grupo
/// do exercício da biblioteca mais parecido ([matchExercisesByName]).
/// `null` se nada parecer com o nome.
String? suggestMuscleGroup(String name, List<Exercise> pool) {
  final matches = matchExercisesByName(name, pool, limit: 3);
  for (final m in matches) {
    final group = m.exercise.muscleGroup.trim();
    if (group.isNotEmpty) return group;
  }
  return null;
}
