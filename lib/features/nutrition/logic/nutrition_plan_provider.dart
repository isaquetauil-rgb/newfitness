import 'package:flutter/foundation.dart';

import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/shared/models/nutrition_plan.dart';
import 'package:newfitness/shared/services/firestore_service.dart';

/// Planos alimentares que a nutricionista monta e atribui a um aluno — ver
/// [NutritionPlan]. Também expõe a lista de alunos vinculados a ela (mesmo
/// papel que `InstructorAiProvider`/`FirestoreService.watchStudents` cumpre
/// pro instrutor, mas em coleção isolada).
class NutritionPlanProvider extends ChangeNotifier {
  NutritionPlanProvider({FirestoreService? firestoreService})
    : _firestoreService = firestoreService ?? getIt<FirestoreService>();

  final FirestoreService _firestoreService;

  Stream<List<Map<String, dynamic>>> watchStudents(String nutritionistUid) {
    return _firestoreService.watchNutritionStudents(nutritionistUid);
  }

  Stream<List<NutritionPlan>> watchPlans(String studentUid) {
    return _firestoreService.watchNutritionPlans(studentUid);
  }

  Future<void> savePlan(NutritionPlan plan) {
    return _firestoreService.saveNutritionPlan(plan);
  }

  Future<void> deletePlan(String studentUid, String planId) {
    return _firestoreService.deleteNutritionPlan(studentUid, planId);
  }
}
