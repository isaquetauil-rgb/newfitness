import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../../core/error/app_exception.dart';
import '../../core/logging/app_logger.dart';
import 'upload_limits.dart';

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

  /// Envia uma foto de evolução do corpo e retorna o CAMINHO no Storage
  /// (não uma URL de download). Foto corporal é dado sensível: uma URL de
  /// download tem token embutido e abre para qualquer um que tenha o link,
  /// ignorando as Storage Rules. Guardando só o caminho, a leitura é feita
  /// com [getBytes], que passa pelas regras a cada acesso.
  Future<String> uploadBodyPhoto(String uid, Uint8List bytes) async {
    final path =
        'users/$uid/body_photos/${DateTime.now().millisecondsSinceEpoch}.jpg';
    try {
      await _storage
          .ref()
          .child(path)
          .putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      return path;
    } catch (e, st) {
      _log.warning('Falha ao enviar foto de evolução', e, st);
      throw NetworkException(
        'Não foi possível enviar o arquivo. Tente novamente.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  /// Baixa um arquivo privado pelo caminho — sujeito às Storage Rules.
  Future<Uint8List> getBytes(
    String path, {
    int maxSize = 15 * 1024 * 1024,
  }) async {
    try {
      final data = await _storage.ref().child(path).getData(maxSize);
      if (data == null) throw StateError('Arquivo vazio: $path');
      return data;
    } catch (e, st) {
      _log.info('Falha ao baixar "$path"', e, st);
      throw NetworkException(
        'Não foi possível carregar a imagem.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  Future<void> deleteByPath(String path) async {
    try {
      await _storage.ref().child(path).delete();
    } catch (e, st) {
      _log.info('Arquivo já não existia ou falhou ao remover: $path', e, st);
    }
  }

  /// Envia uma foto de refeição e retorna a URL pública de download.
  /// JPEG até 5 MB (limite de `storage.rules`).
  Future<String> uploadMealPhoto(String uid, Uint8List bytes) async {
    final problem = UploadLimits.mealPhotoProblem(bytes.length);
    if (problem != null) throw ValidationException(problem);
    return _upload(
      'users/$uid/meal_photos',
      bytes,
      rejectedMessage: UploadLimits.mealPhotoRejected,
    );
  }

  /// Envia o vídeo próprio de um exercício gravado/selecionado pelo
  /// instrutor e retorna a URL pública de download — alternativa a colar um
  /// link do YouTube (ver `Exercise.videoUrl`, que aceita os dois formatos).
  /// Só MP4, MOV ou WebM até 50 MB (limites de `storage.rules`).
  Future<String> uploadExerciseVideo(
    String instructorUid,
    Uint8List bytes, {
    String extension = 'mp4',
  }) async {
    final ext = extension.toLowerCase();
    final problem = UploadLimits.exerciseVideoProblem(ext, bytes.length);
    if (problem != null) throw ValidationException(problem);
    return _upload(
      'users/$instructorUid/exercise_videos',
      bytes,
      extension: ext,
      contentType: UploadLimits.exerciseVideoTypes[ext]!,
      rejectedMessage: UploadLimits.videoRejected,
    );
  }

  /// [rejectedMessage]: mostrada quando as regras do Storage recusam o
  /// arquivo (código `unauthorized` — tipo, tamanho ou permissão).
  Future<String> _upload(
    String folder,
    Uint8List bytes, {
    String extension = 'jpg',
    String contentType = 'image/jpeg',
    required String rejectedMessage,
  }) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$extension';
      final ref = _storage.ref().child('$folder/$fileName');
      final task = await ref.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );
      return await task.ref.getDownloadURL();
    } catch (e, st) {
      if (e is FirebaseException && e.code == 'unauthorized') {
        _log.warning('Upload recusado pelas regras em "$folder"', e, st);
        throw ValidationException(rejectedMessage, cause: e, stackTrace: st);
      }
      _log.warning('Falha ao enviar arquivo para "$folder"', e, st);
      throw NetworkException(
        'Não foi possível enviar o arquivo. Tente novamente.',
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
