import 'package:flutter/foundation.dart';

import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/shared/models/plan_template.dart';
import 'package:newfitness/shared/services/firestore_service.dart';

/// Modelos de plano de treino do instrutor — reutilizáveis entre alunos
/// (ver [PlanTemplate]). Só o instrutor usa isso, diferente de
/// `TrainingPlanProvider` (compartilhado com o aluno), por isso fica em
/// `instructor/logic`.
class PlanTemplateProvider extends ChangeNotifier {
  PlanTemplateProvider({FirestoreService? firestoreService})
    : _firestoreService = firestoreService ?? getIt<FirestoreService>();

  final FirestoreService _firestoreService;

  Stream<List<PlanTemplate>> watchTemplates(String instructorUid) {
    return _firestoreService.watchPlanTemplates(instructorUid);
  }

  Future<void> saveTemplate(PlanTemplate template) {
    return _firestoreService.savePlanTemplate(template);
  }

  Future<void> deleteTemplate(String instructorUid, String templateId) {
    return _firestoreService.deletePlanTemplate(instructorUid, templateId);
  }
}
