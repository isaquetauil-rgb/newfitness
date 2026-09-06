import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/shared/models/body_photo.dart';
import 'package:newfitness/shared/services/firestore_service.dart';
import 'package:newfitness/shared/services/storage_service.dart';

class BodyPhotoProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;
  final StorageService _storageService;

  BodyPhotoProvider({
    FirestoreService? firestoreService,
    StorageService? storageService,
  }) : _firestoreService = firestoreService ?? getIt<FirestoreService>(),
       _storageService = storageService ?? getIt<StorageService>();

  bool _uploading = false;
  bool get isUploading => _uploading;

  Stream<List<BodyPhoto>> watchPhotos(String uid) {
    return _firestoreService.watchBodyPhotos(uid);
  }

  Future<void> addPhoto(String uid, File file, {String? note}) async {
    _uploading = true;
    notifyListeners();
    try {
      final url = await _storageService.uploadBodyPhoto(uid, file);
      final photo = BodyPhoto(
        id: '',
        userId: uid,
        date: DateTime.now(),
        imageUrl: url,
        note: note,
      );
      await _firestoreService.addBodyPhoto(photo);
    } finally {
      _uploading = false;
      notifyListeners();
    }
  }

  Future<void> deletePhoto(BodyPhoto photo) async {
    await _storageService.deleteByUrl(photo.imageUrl);
    await _firestoreService.deleteBodyPhoto(photo.userId, photo.id);
  }
}
