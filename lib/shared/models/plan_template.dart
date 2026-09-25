import 'training_plan.dart';

/// Um modelo de plano de treino salvo pelo instrutor, sem aluno associado —
/// reaproveita a mesma estrutura de sub-treinos/exercícios de [TrainingPlan]
/// para poder ser clonado num plano de verdade e só ter séries/reps/peso
/// ajustados por aluno. Guardado em `users/{instructorUid}/plan_templates/{id}`.
class PlanTemplate {
  final String id;
  final String instructorUid;
  final String title;
  final String? instructions;
  final List<TrainingSubWorkout> workouts;
  final DateTime createdAt;

  const PlanTemplate({
    required this.id,
    required this.instructorUid,
    required this.title,
    this.instructions,
    this.workouts = const [],
    required this.createdAt,
  });

  factory PlanTemplate.fromMap(String id, Map<String, dynamic> map) {
    return PlanTemplate(
      id: id,
      instructorUid: map['instructorUid'] as String? ?? '',
      title: map['title'] as String? ?? 'Modelo de treino',
      instructions: map['instructions'] as String?,
      workouts:
          (map['workouts'] as List<dynamic>?)
              ?.map(
                (w) => TrainingSubWorkout.fromMap(w as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'instructorUid': instructorUid,
      'title': title,
      'instructions': instructions,
      'workouts': workouts.map((w) => w.toMap()).toList(),
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }
}
