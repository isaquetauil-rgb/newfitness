/// Limites de upload — os mesmos de `storage.rules`. O app confere ANTES de
/// enviar (e, no vídeo, antes de carregar o arquivo na memória) para dar
/// uma mensagem clara; a trava de verdade é a regra do Storage.
class UploadLimits {
  UploadLimits._();

  static const maxMealPhotoBytes = 5 * 1024 * 1024;
  static const maxExerciseVideoBytes = 50 * 1024 * 1024;

  /// Duração máxima da gravação do vídeo de exercício — com ela, um vídeo
  /// em 1080p fica abaixo de [maxExerciseVideoBytes].
  static const maxExerciseVideoDuration = Duration(seconds: 20);

  /// Extensões de vídeo aceitas e o tipo gravado no Storage.
  static const exerciseVideoTypes = {
    'mp4': 'video/mp4',
    'mov': 'video/quicktime',
    'webm': 'video/webm',
  };

  static const mealPhotoRejected =
      'Foto recusada. Envie uma imagem JPEG, PNG ou WebP até 5 MB.';
  static const mealPhotoTooBig =
      'A foto passa de 5 MB. Envie uma imagem JPEG, PNG ou WebP até 5 MB.';
  static const videoTooBig =
      'Vídeo maior que 50 MB. Grave um vídeo mais curto (até 20 s) ou em 1080p.';
  static const videoUnsupported =
      'Formato não suportado. Use MP4, MOV ou WebM.';
  static const videoRejected =
      'Vídeo recusado. Envie MP4, MOV ou WebM de até 50 MB (até 20 s).';

  /// Mensagem para o usuário se o vídeo não puder ser enviado, ou `null`.
  static String? exerciseVideoProblem(String extension, int sizeBytes) {
    if (!exerciseVideoTypes.containsKey(extension.toLowerCase())) {
      return videoUnsupported;
    }
    if (sizeBytes > maxExerciseVideoBytes) return videoTooBig;
    return null;
  }

  /// Mensagem para o usuário se a foto de refeição não puder ser enviada.
  static String? mealPhotoProblem(int sizeBytes) =>
      sizeBytes > maxMealPhotoBytes ? mealPhotoTooBig : null;
}
