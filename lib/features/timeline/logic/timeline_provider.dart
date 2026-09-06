import 'package:flutter/foundation.dart';

import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/shared/models/announcement.dart';
import 'package:newfitness/shared/services/firestore_service.dart';

/// Mural de avisos (Timeline) — leitura liberada pra qualquer usuário
/// autenticado; criar/apagar um aviso é exclusivo do admin (ver
/// `firestore.rules`), curtir é liberado pra qualquer um.
class TimelineProvider extends ChangeNotifier {
  TimelineProvider({FirestoreService? firestoreService})
    : _firestoreService = firestoreService ?? getIt<FirestoreService>();

  final FirestoreService _firestoreService;

  Stream<List<Announcement>> watchAnnouncements() {
    return _firestoreService.watchAnnouncements();
  }

  Future<void> createAnnouncement({
    required String authorName,
    required String title,
    required String body,
  }) {
    return _firestoreService.createAnnouncement(
      Announcement(
        id: '',
        authorName: authorName,
        title: title,
        body: body,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> deleteAnnouncement(String id) {
    return _firestoreService.deleteAnnouncement(id);
  }

  Future<void> toggleLike(Announcement announcement, String uid) {
    final liked = !announcement.likeUids.contains(uid);
    return _firestoreService.toggleAnnouncementLike(
      announcement.id,
      uid,
      liked,
    );
  }
}
