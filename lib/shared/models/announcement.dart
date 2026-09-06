/// Um aviso postado no mural (Timeline) — coleção global `announcements`,
/// só o admin cria/edita/apaga; qualquer usuário autenticado pode ler e
/// curtir.
class Announcement {
  final String id;
  final String authorName;
  final String title;
  final String body;
  final DateTime createdAt;
  final List<String> likeUids;

  const Announcement({
    required this.id,
    required this.authorName,
    required this.title,
    required this.body,
    required this.createdAt,
    this.likeUids = const [],
  });

  factory Announcement.fromMap(String id, Map<String, dynamic> map) {
    return Announcement(
      id: id,
      authorName: map['authorName'] as String? ?? '',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
      likeUids: (map['likeUids'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'authorName': authorName,
      'title': title,
      'body': body,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'likeUids': likeUids,
    };
  }
}
