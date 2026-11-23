import 'package:newfitness/features/exercises/logic/exercise_search.dart';
import 'package:newfitness/shared/models/exercise.dart';

/// Filtro combinável da biblioteca e do seletor de exercícios — cada
/// critério é opcional e todos são combinados com E (o exercício precisa
/// bater em todos os critérios ativos). Dentro de um mesmo critério, as
/// opções marcadas valem com OU (ex.: Halteres ou Polia).
class ExerciseFilter {
  final Set<String> muscleGroups;
  final Set<String> muscles;
  final Set<String> equipment;
  final Set<String> difficultyLevels;
  final Set<String> objectives;
  final Set<String> categories;

  /// true = só unilaterais; false = só bilaterais; null = tanto faz.
  final bool? unilateral;

  /// Busca por nome, nome alternativo e tags (sem diferenciar acento).
  final String query;

  const ExerciseFilter({
    this.muscleGroups = const {},
    this.muscles = const {},
    this.equipment = const {},
    this.difficultyLevels = const {},
    this.objectives = const {},
    this.categories = const {},
    this.unilateral,
    this.query = '',
  });

  /// Nenhum critério nem busca ativos.
  bool get isEmpty => activeCount == 0 && query.trim().isEmpty;

  /// Quantos critérios (sem contar a busca) estão marcados.
  int get activeCount =>
      muscleGroups.length +
      muscles.length +
      equipment.length +
      difficultyLevels.length +
      objectives.length +
      categories.length +
      (unilateral == null ? 0 : 1);

  /// Grupos, equipamentos e categorias são comparados já padronizados: um
  /// exercício antigo com "Pernas" aparece ao filtrar por Quadríceps,
  /// Posteriores de coxa etc.; "Peso do corpo" aparece em "Peso corporal".
  bool matches(Exercise exercise) {
    if (!matchesExerciseQuery(exercise, query)) return false;
    if (muscleGroups.isNotEmpty) {
      final wanted = {for (final g in muscleGroups) ...canonicalGroupsOf(g)};
      if (!canonicalGroupsOf(exercise.muscleGroup).any(wanted.contains)) {
        return false;
      }
    }
    if (muscles.isNotEmpty &&
        !musclesWorkedBy(
          exercise.muscleGroup,
          exercise.secondaryMuscles,
        ).any(muscles.contains)) {
      return false;
    }
    if (equipment.isNotEmpty) {
      final wanted = {for (final e in equipment) canonicalEquipmentName(e)};
      if (!wanted.contains(canonicalEquipmentName(exercise.equipment))) {
        return false;
      }
    }
    if (difficultyLevels.isNotEmpty &&
        !difficultyLevels.contains(exercise.difficultyLevel)) {
      return false;
    }
    if (objectives.isNotEmpty &&
        !exercise.objectives.any(objectives.contains)) {
      return false;
    }
    if (categories.isNotEmpty) {
      final wanted = {for (final c in categories) canonicalCategory(c)};
      if (!wanted.contains(canonicalCategory(exercise.category))) {
        return false;
      }
    }
    if (unilateral != null && exercise.isUnilateral != unilateral) {
      return false;
    }
    return true;
  }

  ExerciseFilter copyWith({
    Set<String>? muscleGroups,
    Set<String>? muscles,
    Set<String>? equipment,
    Set<String>? difficultyLevels,
    Set<String>? objectives,
    Set<String>? categories,
    bool? Function()? unilateral,
    String? query,
  }) {
    return ExerciseFilter(
      muscleGroups: muscleGroups ?? this.muscleGroups,
      muscles: muscles ?? this.muscles,
      equipment: equipment ?? this.equipment,
      difficultyLevels: difficultyLevels ?? this.difficultyLevels,
      objectives: objectives ?? this.objectives,
      categories: categories ?? this.categories,
      unilateral: unilateral == null ? this.unilateral : unilateral(),
      query: query ?? this.query,
    );
  }
}
