import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

import '../../core/error/app_exception.dart';
import '../../core/logging/app_logger.dart';

final _log = AppLogger.of('StorageService');

/// Encapsula upload de arquivos para o Firebase Storage.
class StorageService {
  StorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  /// Envia uma foto de evolução do corpo e retorna a URL pública de download.
  Future<String> uploadBodyPhoto(String uid, File file) {
    return _upload('users/$uid/body_photos', file);
  }

  /// Envia uma foto de refeição e retorna a URL pública de download.
  Future<String> uploadMealPhoto(String uid, File file) {
    return _upload('users/$uid/meal_photos', file);
  }

  Future<String> _upload(String folder, File file) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('$folder/$fileName');
      final task = await ref.putFile(file);
      return await task.ref.getDownloadURL();
    } catch (e, st) {
      _log.warning('Falha ao enviar arquivo para "$folder"', e, st);
      throw NetworkException(
        'Não foi possível enviar a foto. Tente novamente.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  Future<void> deleteByUrl(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (e, st) {
      // Se o arquivo já não existir, ignora — o registro no Firestore
      // ainda será removido normalmente. Só logamos para diagnóstico.
      _log.info('Arquivo já não existia ou falhou ao remover: $url', e, st);
    }
  }
}
