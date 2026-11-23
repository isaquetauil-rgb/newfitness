import 'package:newfitness/shared/models/exercise.dart';

/// Busca por nome sem diferenciar acento nem maiúscula: cada palavra digitada
/// precisa aparecer no nome, no nome alternativo ou nas tags de busca
/// ("triceps corda" acha "Tríceps na polia com corda").
bool matchesExerciseQuery(Exercise exercise, String query) {
  final words = foldAccents(query)
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return true;
  final haystack = foldAccents(
    [exercise.name, exercise.alternateName, ...exercise.searchTags].join(' '),
  );
  return words.every(haystack.contains);
}

/// Biblioteca geral sem as versões que o personal já tem como exercício
/// próprio (custom com `baseExerciseId`). Só deve ser usada para o personal
/// DONO desses exercícios — o aluno vê as duas.
List<Exercise> hideGeneralDuplicates(
  List<Exercise> general,
  List<Exercise> ownCustom,
) {
  final hidden = {
    for (final c in ownCustom)
      if (c.baseExerciseId.isNotEmpty) c.baseExerciseId,
  };
  if (hidden.isEmpty) return general;
  return [
    for (final e in general)
      if (!hidden.contains(e.id)) e,
  ];
}
