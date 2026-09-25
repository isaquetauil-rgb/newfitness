import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/shared/models/body_photo.dart';
import 'package:newfitness/shared/services/firestore_service.dart';
import 'package:newfitness/shared/services/storage_service.dart';

class BodyPhotoProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;
  final StorageService _storageService;
  final DateTime Function() _clock;

  BodyPhotoProvider({
    FirestoreService? firestoreService,
    StorageService? storageService,
    DateTime Function()? clock,
  }) : _firestoreService = firestoreService ?? getIt<FirestoreService>(),
       _storageService = storageService ?? getIt<StorageService>(),
       _clock = clock ?? DateTime.now;

  bool _uploading = false;
  bool get isUploading => _uploading;

  // Cache em memória dos bytes já baixados nesta sessão (fotos privadas não
  // têm URL, então o cache de rede do `Image.network` não se aplica).
  final Map<String, Future<Uint8List>> _bytesCache = {};

  Stream<List<BodyPhoto>> watchPhotos(String uid) {
    return _firestoreService.watchBodyPhotos(uid);
  }

  /// [file] é um [XFile] (do `image_picker`) em vez de `dart:io.File` para
  /// funcionar também no Flutter Web.
  Future<void> addPhoto(
    String uid,
    XFile file, {
    String? position,
    String? note,
    DateTime? date,
  }) async {
    _uploading = true;
    notifyListeners();
    try {
      final bytes = await file.readAsBytes();
      final path = await _storageService.uploadBodyPhoto(uid, bytes);
      final now = _clock();
      final photo = BodyPhoto(
        id: '',
        userId: uid,
        date: date ?? now,
        position: position,
        storagePath: path,
        uploadedByUid: uid,
        createdAt: now,
        note: note,
      );
      await _firestoreService.addBodyPhoto(photo);
    } finally {
      _uploading = false;
      notifyListeners();
    }
  }

  Future<Uint8List> loadBytes(String storagePath) {
    return _bytesCache.putIfAbsent(
      storagePath,
      () => _storageService.getBytes(storagePath).catchError((Object e) {
        _bytesCache.remove(storagePath); // permite tentar de novo depois
        throw e;
      }),
    );
  }

  Future<void> deletePhoto(BodyPhoto photo) async {
    final path = photo.storagePath;
    if (path != null) {
      await _storageService.deleteByPath(path);
      _bytesCache.remove(path);
    } else if (photo.imageUrl != null) {
      await _storageService.deleteByUrl(photo.imageUrl!);
    }
    await _firestoreService.deleteBodyPhoto(photo.userId, photo.id);
  }
}
