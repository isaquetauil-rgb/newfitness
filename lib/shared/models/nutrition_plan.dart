/// Uma refeição dentro de um [NutritionPlan] — ex: "Café da manhã",
/// "Almoço" — com uma descrição livre dos alimentos/quantidades sugeridos.
/// Mais simples que [PlanExercise]/[TrainingSubWorkout] (não tem
/// séries/reps) porque dieta não se divide em "sub-treinos".
class NutritionMeal {
  final String label;
  final String description;
  final String? suggestedTime; // texto livre, ex: "08:00" ou "ao acordar"

  const NutritionMeal({
    required this.label,
    required this.description,
    this.suggestedTime,
  });

  factory NutritionMeal.fromMap(Map<String, dynamic> map) {
    return NutritionMeal(
      label: map['label'] as String? ?? 'Refeição',
      description: map['description'] as String? ?? '',
      suggestedTime: map['suggestedTime'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'description': description,
      'suggestedTime': suggestedTime,
    };
  }
}

/// Um plano alimentar que a nutricionista monta e atribui a um aluno —
/// guardado em `users/{studentUid}/nutrition_plans/{id}` (só a nutricionista
/// vinculada cria/edita; o aluno só lê). Mesmo padrão de [TrainingPlan], mas
/// isolado dele — instrutor não lê isto, nutricionista não lê treinos.
class NutritionPlan {
  final String id;
  final String studentUid;
  final String nutritionistUid;
  final String title;
  final String? instructions;
  final List<NutritionMeal> meals;
  final DateTime createdAt;

  const NutritionPlan({
    required this.id,
    required this.studentUid,
    required this.nutritionistUid,
    required this.title,
    this.instructions,
    this.meals = const [],
    required this.createdAt,
  });

  factory NutritionPlan.fromMap(String id, Map<String, dynamic> map) {
    return NutritionPlan(
      id: id,
      studentUid: map['studentUid'] as String? ?? '',
      nutritionistUid: map['nutritionistUid'] as String? ?? '',
      title: map['title'] as String? ?? 'Plano alimentar',
      instructions: map['instructions'] as String?,
      meals:
          (map['meals'] as List<dynamic>?)
              ?.map((m) => NutritionMeal.fromMap(m as Map<String, dynamic>))
              .toList() ??
          const [],
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentUid': studentUid,
      'nutritionistUid': nutritionistUid,
      'title': title,
      'instructions': instructions,
      'meals': meals.map((m) => m.toMap()).toList(),
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }
}
