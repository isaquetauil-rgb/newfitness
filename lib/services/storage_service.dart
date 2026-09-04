import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

/// Encapsula upload de arquivos para o Firebase Storage.
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Envia uma foto de evolução do corpo e retorna a URL pública de download.
  Future<String> uploadBodyPhoto(String uid, File file) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref().child('users/$uid/body_photos/$fileName');
    final task = await ref.putFile(file);
    return task.ref.getDownloadURL();
  }

  Future<void> deleteByUrl(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {
      // Se o arquivo já não existir, ignora — o registro no Firestore
      // ainda será removido normalmente.
    }
  }
}
