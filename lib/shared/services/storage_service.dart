import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../../core/error/app_exception.dart';
import '../../core/logging/app_logger.dart';

final _log = AppLogger.of('StorageService');

/// Encapsula upload de arquivos para o Firebase Storage.
///
/// Recebe bytes (`Uint8List`) em vez de `dart:io.File` de propósito: o
/// `File` do `image_picker` não existe/não funciona no Flutter Web (lá o
/// resultado é uma URL `blob:`), então ler os bytes uma vez no chamador
/// (via `XFile.readAsBytes()`, que funciona em todas as plataformas) e
/// fazer upload com `putData` é a forma que roda igual em
/// Android/iOS/Web.
class StorageService {
  StorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  /// Envia uma foto de evolução do corpo e retorna a URL pública de download.
  Future<String> uploadBodyPhoto(String uid, Uint8List bytes) {
    return _upload('users/$uid/body_photos', bytes);
  }

  /// Envia uma foto de refeição e retorna a URL pública de download.
  Future<String> uploadMealPhoto(String uid, Uint8List bytes) {
    return _upload('users/$uid/meal_photos', bytes);
  }

  Future<String> _upload(String folder, Uint8List bytes) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('$folder/$fileName');
      final task = await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
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
