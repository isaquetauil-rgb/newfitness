import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:newfitness/core/di/injector.dart';
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

  /// Faz upload da foto, salva o registro e depois pede a análise da IA
  /// (a análise chega um pouco depois, via update do documento).
  Future<void> addPhoto(String uid, File file, MealType mealType) async {
    _uploading = true;
    notifyListeners();
    try {
      final url = await _storageService.uploadMealPhoto(uid, file);
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

      // Análise da IA acontece em segundo plano; se falhar, a foto
      // continua salva normalmente, só sem o comentário.
      try {
        final analysis = await _aiService.analyzeMealPhoto(
          image: file,
          mealType: mealType.label,
        );
        await _firestoreService.updateMealPhotoAnalysis(uid, id, analysis);
      } catch (_) {
        // Falha silenciosa na análise — a foto já está salva.
      }
    } catch (e) {
      _uploading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deletePhoto(MealPhoto photo) async {
    await _storageService.deleteByUrl(photo.imageUrl);
    await _firestoreService.deleteMealPhoto(photo.userId, photo.id);
  }
}
