import 'package:flutter/foundation.dart';

import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/services/firestore_service.dart';
import 'package:newfitness/shared/services/storage_service.dart';

/// Biblioteca privada de exercícios do instrutor (ver
/// `FirestoreService.watchCustomExercises`) — diferente da biblioteca global
/// curada pelo admin (`ExerciseProvider`). O instrutor pode usar tanto um
/// link do YouTube quanto um vídeo próprio, enviado pelo celular e guardado
/// no Firebase Storage (`StorageService.uploadExerciseVideo`).
class CustomExerciseProvider extends ChangeNotifier {
  CustomExerciseProvider({
    FirestoreService? firestoreService,
    StorageService? storageService,
  }) : _firestoreService = firestoreService ?? getIt<FirestoreService>(),
       _storageService = storageService ?? getIt<StorageService>();

  final FirestoreService _firestoreService;
  final StorageService _storageService;

  bool _uploadingVideo = false;
  bool get isUploadingVideo => _uploadingVideo;

  /// Exercícios do instrutor. Arquivados ficam de fora, a não ser com
  /// [includeArchived] (para achar exercícios de treinos antigos).
  Stream<List<Exercise>> watchExercises(
    String instructorUid, {
    bool includeArchived = false,
  }) {
    final all = _firestoreService.watchCustomExercises(instructorUid);
    if (includeArchived) return all;
    return all.map(
      (list) => [
        for (final e in list)
          if (!e.archived) e,
      ],
    );
  }

  Future<void> saveExercise(String instructorUid, Exercise exercise) {
    return _firestoreService.saveCustomExercise(instructorUid, exercise);
  }

  /// "Apagar" = ARQUIVAR: some da biblioteca e dos seletores, mas treinos
  /// antigos continuam achando o exercício.
  Future<void> deleteExercise(String instructorUid, String exerciseId) {
    return _firestoreService.archiveCustomExercise(instructorUid, exerciseId);
  }

  /// Envia o vídeo gravado/selecionado pelo instrutor e devolve a URL de
  /// download — a tela usa essa URL como `videoUrl` do exercício, exatamente
  /// como faria com um link colado do YouTube.
  Future<String> uploadVideo(
    String instructorUid,
    Uint8List bytes, {
    String extension = 'mp4',
  }) async {
    _uploadingVideo = true;
    notifyListeners();
    try {
      return await _storageService.uploadExerciseVideo(
        instructorUid,
        bytes,
        extension: extension,
      );
    } finally {
      _uploadingVideo = false;
      notifyListeners();
    }
  }
}
