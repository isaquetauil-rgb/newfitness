import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:newfitness/shared/models/health_screening.dart';

/// Grava e lê o questionário de saúde em `users/{uid}/health_screenings`.
class HealthScreeningService {
  HealthScreeningService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('health_screenings');

  /// Resposta mais recente do aluno, ou null se ele nunca respondeu.
  Future<HealthScreening?> latest(String uid) async {
    final snap = await _col(uid)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return HealthScreening.fromMap(doc.id, doc.data());
  }

  Stream<HealthScreening?> watchLatest(String uid) => _col(uid)
      .orderBy('createdAt', descending: true)
      .limit(1)
      .snapshots()
      .map(
        (snap) => snap.docs.isEmpty
            ? null
            : HealthScreening.fromMap(
                snap.docs.first.id,
                snap.docs.first.data(),
              ),
      );

  Future<void> save(String uid, HealthScreening screening) =>
      _col(uid).add(screening.toMap());
}
