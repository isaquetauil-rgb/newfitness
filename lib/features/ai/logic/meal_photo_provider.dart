import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/core/error/app_exception.dart';
import 'package:newfitness/features/ai/data/ai_service.dart';
import 'package:newfitness/shared/models/meal_photo.dart';
import 'package:newfitness/shared/services/firestore_service.dart';
import 'package:newfitness/shared/services/storage_service.dart';

class MealPhotoProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;
  final StorageService _storageService;
  final AiService _aiService;

  MealPhotoProvider({
    FirestoreService? firestoreService,
    StorageService? storageService,
    AiService? aiService,
  }) : _firestoreService = firestoreService ?? getIt<FirestoreService>(),
       _storageService = storageService ?? getIt<StorageService>(),
       _aiService = aiService ?? getIt<AiService>();

  bool _uploading = false;
  bool get isUploading => _uploading;

  Stream<List<MealPhoto>> watchPhotos(String uid) {
    return _firestoreService.watchMealPhotos(uid);
  }

  /// [file] é um [XFile] (do `image_picker`) em vez de `dart:io.File` para
  /// funcionar também no Flutter Web.
  ///
  /// Faz upload da foto, salva o registro e depois pede a análise da IA —
  /// o SERVIDOR grava o resultado (ou o motivo da falha) no documento, e o
  /// card atualiza pelo stream de [watchPhotos].
  ///
  /// Devolve `null` se a análise deu certo, ou a mensagem real do servidor
  /// se não deu (ex: limite do plano) — a foto fica salva de qualquer jeito.
  /// Lança erro só se o envio da foto em si falhar.
  Future<String?> addPhoto(String uid, XFile file, MealType mealType) async {
    _uploading = true;
    notifyListeners();
    try {
      final bytes = await file.readAsBytes();
      final url = await _storageService.uploadMealPhoto(uid, bytes);
      final photo = MealPhoto(
        id: '',
        userId: uid,
        date: DateTime.now(),
        mealType: mealType,
        imageUrl: url,
      );
      final id = await _firestoreService.addMealPhoto(photo);
      _uploading = false;
      notifyListeners();
      return await analyze(id);
    } catch (e) {
      _uploading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Pede (de novo) a análise de uma foto já salva. Devolve `null` se deu
  /// certo, ou a mensagem para mostrar ao usuário.
  Future<String?> analyze(String photoId) async {
    try {
      await _aiService.analyzeMealPhoto(photoId: photoId);
      return null;
    } catch (e) {
      return e is AppException
          ? e.message
          : 'Não foi possível analisar esta foto agora.';
    }
  }

  Future<void> deletePhoto(MealPhoto photo) async {
    await _storageService.deleteByUrl(photo.imageUrl);
    await _firestoreService.deleteMealPhoto(photo.userId, photo.id);
  }
}
