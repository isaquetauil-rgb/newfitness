import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:newfitness/shared/models/support.dart';

/// Canal de apoio: cada aluno tem uma conversa com a equipe (o admin).
class SupportService {
  SupportService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _threads =>
      _db.collection('support_threads');

  Stream<List<SupportMessage>> watchMessages(String studentUid) => _threads
      .doc(studentUid)
      .collection('messages')
      .orderBy('createdAt')
      .limitToLast(200)
      .snapshots()
      .map(
        (snap) => [
          for (final d in snap.docs) SupportMessage.fromMap(d.id, d.data()),
        ],
      );

  Stream<SupportThread?> watchThread(String studentUid) =>
      _threads.doc(studentUid).snapshots().map((d) {
        final data = d.data();
        return data == null ? null : SupportThread.fromMap(d.id, data);
      });

  /// Caixa de entrada do admin: conversas mais recentes primeiro.
  Stream<List<SupportThread>> watchThreads() => _threads
      .orderBy('lastMessageAt', descending: true)
      .limit(200)
      .snapshots()
      .map(
        (snap) => [
          for (final d in snap.docs) SupportThread.fromMap(d.id, d.data()),
        ],
      );

  /// Grava a mensagem e atualiza o resumo da conversa juntos.
  Future<void> send({
    required String studentUid,
    required String studentName,
    required SupportAuthor from,
    required String text,
  }) {
    final clean = text.trim();
    final now = DateTime.now().millisecondsSinceEpoch;
    final thread = _threads.doc(studentUid);
    final byStudent = from == SupportAuthor.student;
    final batch = _db.batch()
      ..set(thread.collection('messages').doc(), {
        'text': clean,
        'from': supportAuthorToString(from),
        'createdAt': now,
      })
      ..set(thread, {
        'uid': studentUid,
        'name': studentName,
        'lastMessage': supportPreview(clean),
        'lastMessageAt': now,
        'lastFrom': supportAuthorToString(from),
        'unreadByAdmin': byStudent,
        'unreadByStudent': !byStudent,
      }, SetOptions(merge: true));
    return batch.commit();
  }

  /// Marca a conversa como lida por quem está com ela aberta.
  Future<void> markRead(String studentUid, SupportAuthor reader) =>
      _threads.doc(studentUid).update({
        reader == SupportAuthor.admin ? 'unreadByAdmin' : 'unreadByStudent':
            false,
      });
}
