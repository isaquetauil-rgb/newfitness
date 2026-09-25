import 'package:flutter/foundation.dart';

import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/shared/models/physical_assessment.dart';
import 'package:newfitness/shared/services/firestore_service.dart';

/// Avaliações físicas de um usuário — ver [PhysicalAssessment]. Tanto o
/// próprio aluno quanto o instrutor vinculado podem lançar; só o autor edita
/// ou apaga a própria avaliação (regras do Firestore garantem isso).
class PhysicalAssessmentProvider extends ChangeNotifier {
  PhysicalAssessmentProvider({
    FirestoreService? firestoreService,
    DateTime Function()? clock,
  }) : _firestoreService = firestoreService ?? getIt<FirestoreService>(),
       _clock = clock ?? DateTime.now;

  final FirestoreService _firestoreService;
  final DateTime Function() _clock;

  Stream<List<PhysicalAssessment>> watchAssessments(String uid) {
    return _firestoreService.watchPhysicalAssessments(uid);
  }

  /// Carimba autor e data de criação — campos controlados pelo sistema (as
  /// regras exigem `createdByUid == quem grava`).
  Future<void> addAssessment(
    PhysicalAssessment assessment, {
    required String authorUid,
    String? authorName,
  }) {
    final now = _clock();
    return _firestoreService.addPhysicalAssessment(
      assessment.copyWith(
        createdByUid: authorUid,
        createdByName: authorName,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// [edited] vem do formulário; autor, origem e criação são preservados de
  /// [original] (as regras recusam qualquer mudança neles).
  Future<void> updateAssessment(
    PhysicalAssessment original,
    PhysicalAssessment edited,
  ) {
    return _firestoreService.updatePhysicalAssessment(
      PhysicalAssessment(
        id: original.id,
        userId: original.userId,
        date: edited.date,
        weightKg: edited.weightKg,
        heightCm: edited.heightCm,
        bodyFatPercent: edited.bodyFatPercent,
        bodyFatMethod: edited.bodyFatMethod,
        muscleMassKg: edited.muscleMassKg,
        measurementsCm: edited.measurementsCm,
        notes: edited.notes,
        recordedBy: original.recordedBy,
        createdByUid: original.createdByUid,
        createdByName: original.createdByName,
        createdAt: original.createdAt,
        updatedAt: _clock(),
      ),
    );
  }

  Future<void> deleteAssessment(String uid, String assessmentId) {
    return _firestoreService.deletePhysicalAssessment(uid, assessmentId);
  }

  /// Espelha a regra de autoria de `firestore.rules`, só para a UI decidir
  /// se mostra editar/apagar. Avaliações antigas (sem `createdByUid`) seguem
  /// a origem: 'self' → o aluno, 'instructor' → o instrutor.
  static bool canModify(
    PhysicalAssessment a, {
    required String viewerUid,
    required bool viewerIsOwner,
  }) {
    if (a.createdByUid != null) return a.createdByUid == viewerUid;
    return viewerIsOwner
        ? a.recordedBy == AssessmentSource.self
        : a.recordedBy == AssessmentSource.instructor;
  }
}
