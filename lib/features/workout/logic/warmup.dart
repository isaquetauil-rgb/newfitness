/// Séries de aquecimento e agrupamento de bi-set/tri-set. Lógica pura: sem
/// Flutter e sem Firebase.
library;

import 'package:newfitness/shared/models/training_plan.dart';
import 'package:newfitness/shared/models/workout_set.dart';

/// Séries de aquecimento antes da carga de trabalho [workKg]:
/// - a partir de 40 kg: 40%, 60% e 80% (10, 6 e 3 reps);
/// - abaixo disso: 50% e 75% (8 e 4 reps).
///
/// Arredonda para o passo das anilhas ([stepKg]; padrão 2,5 kg a partir de
/// 20 kg e 0,5 kg abaixo). Descarta séries que arredondam para 0, para a
/// própria carga de trabalho ou que repetem a anterior.
List<WorkoutSet> generateWarmupSets(double workKg, {double? stepKg}) {
  if (workKg <= 0) return const [];
  final step = stepKg ?? (workKg >= 20 ? 2.5 : 0.5);
  final plan = workKg >= 40
      ? const [(0.4, 10), (0.6, 6), (0.8, 3)]
      : const [(0.5, 8), (0.75, 4)];

  final sets = <WorkoutSet>[];
  for (final (pct, reps) in plan) {
    final kg = _round(workKg * pct, step);
    if (kg <= 0 || kg >= workKg) continue;
    if (sets.isNotEmpty && sets.last.weightKg == kg) continue;
    sets.add(WorkoutSet(weightKg: kg, reps: reps, type: SetType.warmup));
  }
  return sets;
}

double _round(double kg, double step) =>
    double.parse(((kg / step).round() * step).toStringAsFixed(2));

/// Deixa juntos os exercícios do mesmo bi-set/tri-set
/// ([PlanExercise.supersetGroup]), na posição do primeiro do grupo. A ordem
/// entre eles e a dos demais exercícios é mantida.
List<PlanExercise> groupSupersets(List<PlanExercise> exercises) {
  final result = <PlanExercise>[];
  final placed = <String>{};
  for (final e in exercises) {
    final group = e.supersetGroup;
    if (group == null) {
      result.add(e);
    } else if (placed.add(group)) {
      result.addAll(exercises.where((x) => x.supersetGroup == group));
    }
  }
  return result;
}

/// "Bi-set A" (2 exercícios), "Tri-set A" (3) ou "Circuito A" (4+).
String supersetLabel(String group, int size) => switch (size) {
  <= 2 => 'Bi-set $group',
  3 => 'Tri-set $group',
  _ => 'Circuito $group',
};

/// Grupos que o personal pode escolher no editor.
const supersetGroups = ['A', 'B', 'C', 'D'];
