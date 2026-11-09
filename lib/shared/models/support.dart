/// Quem escreveu uma mensagem do canal de apoio.
enum SupportAuthor { student, admin }

SupportAuthor supportAuthorFromString(String? value) =>
    value == 'admin' ? SupportAuthor.admin : SupportAuthor.student;

String supportAuthorToString(SupportAuthor author) =>
    author == SupportAuthor.admin ? 'admin' : 'student';

/// `support_threads/{uid}/messages/{id}` — mensagens não são editadas nem
/// apagadas (ver `firestore.rules`).
class SupportMessage {
  final String id;
  final String text;
  final SupportAuthor from;
  final DateTime createdAt;

  const SupportMessage({
    required this.id,
    required this.text,
    required this.from,
    required this.createdAt,
  });

  factory SupportMessage.fromMap(String id, Map<String, dynamic> map) =>
      SupportMessage(
        id: id,
        text: map['text'] as String? ?? '',
        from: supportAuthorFromString(map['from'] as String?),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (map['createdAt'] as num?)?.toInt() ?? 0,
        ),
      );
}

/// `support_threads/{uid}` — resumo da conversa de um aluno com a equipe,
/// usado na caixa de entrada do admin.
class SupportThread {
  final String uid;
  final String name;
  final String lastMessage;
  final DateTime lastMessageAt;
  final SupportAuthor lastFrom;
  final bool unreadByAdmin;
  final bool unreadByStudent;

  const SupportThread({
    required this.uid,
    required this.name,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.lastFrom,
    this.unreadByAdmin = false,
    this.unreadByStudent = false,
  });

  factory SupportThread.fromMap(String uid, Map<String, dynamic> map) =>
      SupportThread(
        uid: uid,
        name: map['name'] as String? ?? 'Aluno',
        lastMessage: map['lastMessage'] as String? ?? '',
        lastMessageAt: DateTime.fromMillisecondsSinceEpoch(
          (map['lastMessageAt'] as num?)?.toInt() ?? 0,
        ),
        lastFrom: supportAuthorFromString(map['lastFrom'] as String?),
        unreadByAdmin: map['unreadByAdmin'] as bool? ?? false,
        unreadByStudent: map['unreadByStudent'] as bool? ?? false,
      );
}

/// Limites iguais aos de `firestore.rules`.
const int supportMessageMaxLength = 1000;
const int supportPreviewMaxLength = 140;

/// Prévia da última mensagem, para a lista do admin.
String supportPreview(String text) {
  final clean = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  return clean.length <= supportPreviewMaxLength
      ? clean
      : '${clean.substring(0, supportPreviewMaxLength - 1)}…';
}
