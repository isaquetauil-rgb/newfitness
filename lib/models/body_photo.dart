/// Uma foto de evolução do corpo, tirada em uma data, salva no Storage.
class BodyPhoto {
  final String id;
  final String userId;
  final DateTime date;
  final String imageUrl;
  final String? note;

  const BodyPhoto({
    required this.id,
    required this.userId,
    required this.date,
    required this.imageUrl,
    this.note,
  });

  factory BodyPhoto.fromMap(String id, Map<String, dynamic> map) {
    return BodyPhoto(
      id: id,
      userId: map['userId'] as String? ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(
        map['date'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      imageUrl: map['imageUrl'] as String? ?? '',
      note: map['note'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'date': date.millisecondsSinceEpoch,
      'imageUrl': imageUrl,
      'note': note,
    };
  }
}
