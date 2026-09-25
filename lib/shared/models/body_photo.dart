/// Posições padrão de uma foto de evolução. O campo é uma string livre
/// ([BodyPhoto.position]) — novas posições podem ser adicionadas aqui sem
/// migrar dados; uma chave desconhecida é exibida como "Outra".
class PhotoPosition {
  PhotoPosition._();

  static const front = 'front';
  static const back = 'back';
  static const rightSide = 'right_side';
  static const leftSide = 'left_side';
  static const other = 'other';

  static const all = [front, back, rightSide, leftSide, other];

  static const labels = {
    front: 'Frente',
    back: 'Costas',
    rightSide: 'Lado direito',
    leftSide: 'Lado esquerdo',
    other: 'Outra',
  };

  static String labelOf(String? key) =>
      key == null ? 'Sem posição' : (labels[key] ?? 'Outra');
}

/// Uma foto de evolução do corpo, tirada em uma data, salva no Storage.
///
/// Fotos novas guardam só o [storagePath] (arquivo privado, lido pelo SDK
/// passando pelas Storage Rules a cada acesso). Fotos antigas guardavam uma
/// URL de download pública ([imageUrl]) — continuam sendo exibidas.
class BodyPhoto {
  final String id;
  final String userId;
  final DateTime date;
  final String? position; // ver [PhotoPosition]
  final String? storagePath;
  final String? imageUrl; // legado
  final String? uploadedByUid;
  final DateTime? createdAt;
  final String? note;

  const BodyPhoto({
    required this.id,
    required this.userId,
    required this.date,
    this.position,
    this.storagePath,
    this.imageUrl,
    this.uploadedByUid,
    this.createdAt,
    this.note,
  });

  factory BodyPhoto.fromMap(String id, Map<String, dynamic> map) {
    final imageUrl = map['imageUrl'] as String?;
    return BodyPhoto(
      id: id,
      userId: map['userId'] as String? ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(
        map['date'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      position: map['position'] as String?,
      storagePath: map['storagePath'] as String?,
      imageUrl: (imageUrl == null || imageUrl.isEmpty) ? null : imageUrl,
      uploadedByUid: map['uploadedByUid'] as String?,
      createdAt: map['createdAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : null,
      note: map['note'] as String?,
    );
  }

  /// Os nomes aqui precisam bater com a lista `hasOnly` de `body_photos` em
  /// `firestore.rules`. Campos nulos não são gravados.
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'date': date.millisecondsSinceEpoch,
      'position': ?position,
      'storagePath': ?storagePath,
      'imageUrl': ?imageUrl,
      'uploadedByUid': ?uploadedByUid,
      'createdAt': ?createdAt?.millisecondsSinceEpoch,
      'note': ?note,
    };
  }
}
