import 'package:flutter/foundation.dart';

import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/shared/models/exercise_progress_record.dart';
import 'package:newfitness/shared/services/firestore_service.dart';

/// Leitura da evolução por exercício (`users/{uid}/progress_records`) — a
/// escrita acontece em `FirestoreService.recordExerciseProgress`, chamada
/// por `WorkoutProvider.finishWorkout` a cada treino salvo. Usado tanto pelo
/// próprio aluno (`ProgressScreen`) quanto pelo instrutor olhando o
/// histórico de um aluno vinculado (`StudentDetailScreen`).
class ProgressRecordProvider extends ChangeNotifier {
  ProgressRecordProvider({FirestoreService? firestoreService})
    : _firestoreService = firestoreService ?? getIt<FirestoreService>();

  final FirestoreService _firestoreService;

  Stream<List<ExerciseProgressRecord>> watchRecords(String uid) {
    return _firestoreService.watchProgressRecords(uid);
  }

  Stream<ExerciseProgressRecord?> watchRecord(String uid, String exerciseId) {
    return _firestoreService.watchProgressRecord(uid, exerciseId);
  }
}
