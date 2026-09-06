import 'package:flutter/foundation.dart';

import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/shared/models/training_plan.dart';
import 'package:newfitness/shared/services/firestore_service.dart';

/// Planos de treino atribuídos por um instrutor a um aluno. Usado tanto
/// pelo instrutor (criar/editar, em `features/instructor`) quanto pelo
/// aluno (ver e iniciar um treino a partir de um plano, em
/// `features/workout`) — por isso fica em `workout/logic`, não em
/// `instructor`.
class TrainingPlanProvider extends ChangeNotifier {
  TrainingPlanProvider({FirestoreService? firestoreService})
    : _firestoreService = firestoreService ?? getIt<FirestoreService>();

  final FirestoreService _firestoreService;

  Stream<List<TrainingPlan>> watchPlans(String studentUid) {
    return _firestoreService.watchTrainingPlans(studentUid);
  }

  Future<void> savePlan(TrainingPlan plan) {
    return _firestoreService.saveTrainingPlan(plan);
  }

  Future<void> deletePlan(String studentUid, String planId) {
    return _firestoreService.deleteTrainingPlan(studentUid, planId);
  }
}
