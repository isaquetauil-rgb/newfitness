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

  Stream<List<Exercise>> watchExercises(String instructorUid) {
    return _firestoreService.watchCustomExercises(instructorUid);
  }

  Future<void> saveExercise(String instructorUid, Exercise exercise) {
    return _firestoreService.saveCustomExercise(instructorUid, exercise);
  }

  Future<void> deleteExercise(String instructorUid, String exerciseId) {
    return _firestoreService.deleteCustomExercise(instructorUid, exerciseId);
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
