import 'package:newfitness/shared/models/exercise.dart';

/// Filtro combinável para a biblioteca de exercícios (requisito: "filtrar
/// exercícios por músculo, equipamento, dificuldade e objetivo") — cada
/// critério é opcional e todos são combinados com E (um exercício precisa
/// bater em todos os critérios ativos).
class ExerciseFilter {
  final Set<String> muscleGroups;
  final Set<String> equipment;
  final Set<String> difficultyLevels;
  final Set<String> objectives;
  final Set<String> categories;

  const ExerciseFilter({
    this.muscleGroups = const {},
    this.equipment = const {},
    this.difficultyLevels = const {},
    this.objectives = const {},
    this.categories = const {},
  });

  bool get isEmpty =>
      muscleGroups.isEmpty &&
      equipment.isEmpty &&
      difficultyLevels.isEmpty &&
      objectives.isEmpty &&
      categories.isEmpty;

  int get activeCount =>
      muscleGroups.length +
      equipment.length +
      difficultyLevels.length +
      objectives.length +
      categories.length;

  /// Grupos, equipamentos e categorias são comparados já padronizados: um
  /// exercício antigo com "Pernas" aparece ao filtrar por Quadríceps,
  /// Posteriores de coxa etc.; "Peso do corpo" aparece em "Peso corporal".
  bool matches(Exercise exercise) {
    if (muscleGroups.isNotEmpty) {
      final wanted = {for (final g in muscleGroups) ...canonicalGroupsOf(g)};
      if (!canonicalGroupsOf(exercise.muscleGroup).any(wanted.contains)) {
        return false;
      }
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
    return true;
  }

  ExerciseFilter copyWith({
    Set<String>? muscleGroups,
    Set<String>? equipment,
    Set<String>? difficultyLevels,
    Set<String>? objectives,
    Set<String>? categories,
  }) {
    return ExerciseFilter(
      muscleGroups: muscleGroups ?? this.muscleGroups,
      equipment: equipment ?? this.equipment,
      difficultyLevels: difficultyLevels ?? this.difficultyLevels,
      objectives: objectives ?? this.objectives,
      categories: categories ?? this.categories,
    );
  }
}
