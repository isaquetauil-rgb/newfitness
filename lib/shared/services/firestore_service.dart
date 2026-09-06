import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/error/app_exception.dart';
import '../../core/logging/app_logger.dart';
import '../models/body_photo.dart';
import '../models/chat_message.dart';
import '../models/exercise.dart';
import '../models/meal_photo.dart';
import '../models/announcement.dart';
import '../models/reminder.dart';
import '../models/training_plan.dart';
import '../models/user_profile.dart';
import '../models/workout.dart';

final _log = AppLogger.of('FirestoreService');

/// Encapsula toda a leitura/escrita no Cloud Firestore.
///
/// Coleções usadas (ver [FirestorePaths]):
///   users/{uid}                -> perfil do usuário
///   users/{uid}/workouts/{id}  -> treinos daquele usuário
///   exercises/{id}             -> biblioteca de exercícios (global)
class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<T> _guard<T>(String op, Future<T> Function() action) async {
    try {
      return await action();
    } catch (e, st) {
      _log.warning('Falha em "$op"', e, st);
      throw _mapError(op, e, st);
    }
  }

  Stream<T> _guardStream<T>(String op, Stream<T> stream) {
    return stream.handleError((Object e, StackTrace st) {
      _log.warning('Falha em "$op"', e, st);
      throw _mapError(op, e, st);
    });
  }

  AppException _mapError(String op, Object e, StackTrace st) {
    if (e is FirebaseException) {
      if (e.code == 'permission-denied') {
        return AuthException(
          'Você não tem permissão para fazer isso.',
          cause: e,
          stackTrace: st,
        );
      }
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        return NetworkException(
          'Sem conexão com o servidor. Tente novamente.',
          cause: e,
          stackTrace: st,
        );
      }
    }
    return UnknownException(
      'Erro ao executar "$op".',
      cause: e,
      stackTrace: st,
    );
  }

  // ---------- Perfil ----------

  Future<void> createUserProfile(UserProfile profile) {
    return _guard('createUserProfile', () {
      return _db
          .collection(FirestorePaths.users)
          .doc(profile.uid)
          .set(profile.toMap());
    });
  }

  Future<UserProfile?> getUserProfile(String uid) {
    return _guard('getUserProfile', () async {
      final doc = await _db.collection(FirestorePaths.users).doc(uid).get();
      if (!doc.exists) return null;
      return UserProfile.fromMap(uid, doc.data()!);
    });
  }

  Future<void> updateUserProfile(UserProfile profile) {
    return _guard('updateUserProfile', () {
      return _db
          .collection(FirestorePaths.users)
          .doc(profile.uid)
          .set(profile.toMap(), SetOptions(merge: true));
    });
  }

  /// Lista todos os usuários cadastrados — só o admin tem permissão para
  /// isso (ver `firestore.rules`).
  Stream<List<UserProfile>> watchAllUsers() {
    return _guardStream(
      'watchAllUsers',
      _db
          .collection(FirestorePaths.users)
          .orderBy('name')
          .snapshots()
          .map(
            (snap) => snap.docs
                .map((d) => UserProfile.fromMap(d.id, d.data()))
                .toList(),
          ),
    );
  }

  // ---------- Instrutor / Aluno ----------

  /// Gera um código de convite curto e garante que ele é único entre os
  /// instrutores já cadastrados.
  Future<String> generateUniqueInviteCode() {
    return _guard('generateUniqueInviteCode', () async {
      const chars =
          'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // sem O/0/I/1 (evita confusão)
      final random = DateTime.now().microsecondsSinceEpoch;

      for (int attempt = 0; attempt < 10; attempt++) {
        final seed = random + attempt;
        final code = List.generate(6, (i) {
          final index = (seed ~/ (i + 1) + i * 31) % chars.length;
          return chars[index.abs()];
        }).join();

        final existing = await _db
            .collection(FirestorePaths.users)
            .where('inviteCode', isEqualTo: code)
            .limit(1)
            .get();
        if (existing.docs.isEmpty) return code;
      }
      // Extremamente improvável de chegar aqui, mas garante um valor válido.
      return 'F${DateTime.now().millisecondsSinceEpoch}';
    });
  }

  /// Procura um instrutor pelo código de convite. Retorna null se não existir.
  Future<UserProfile?> findInstructorByCode(String code) {
    return _guard('findInstructorByCode', () async {
      final query = await _db
          .collection(FirestorePaths.users)
          .where('role', isEqualTo: 'instructor')
          .where('inviteCode', isEqualTo: code.trim().toUpperCase())
          .limit(1)
          .get();
      if (query.docs.isEmpty) return null;
      final doc = query.docs.first;
      return UserProfile.fromMap(doc.id, doc.data());
    });
  }

  /// Vincula um aluno a um instrutor: grava instructorId no perfil do aluno
  /// e adiciona uma entrada denormalizada em users/{instructorId}/students.
  Future<void> linkStudentToInstructor({
    required UserProfile student,
    required String instructorId,
  }) {
    return _guard('linkStudentToInstructor', () async {
      final batch = _db.batch();

      final studentRef = _db.collection(FirestorePaths.users).doc(student.uid);
      batch.set(studentRef, {
        'instructorId': instructorId,
      }, SetOptions(merge: true));

      final studentEntryRef = _db
          .collection(FirestorePaths.students(instructorId))
          .doc(student.uid);
      batch.set(studentEntryRef, {
        'name': student.name,
        'email': student.email,
        'linkedAt': DateTime.now().millisecondsSinceEpoch,
      });

      await batch.commit();
    });
  }

  /// Lista (com atualização em tempo real) os alunos vinculados a um instrutor.
  Stream<List<Map<String, dynamic>>> watchStudents(String instructorId) {
    return _guardStream(
      'watchStudents',
      _db
          .collection(FirestorePaths.students(instructorId))
          .orderBy('name')
          .snapshots()
          .map(
            (snap) => snap.docs.map((d) => {'uid': d.id, ...d.data()}).toList(),
          ),
    );
  }

  // ---------- Treinos ----------

  CollectionReference<Map<String, dynamic>> _workoutsRef(String uid) =>
      _db.collection(FirestorePaths.workouts(uid));

  Future<String> saveWorkout(Workout workout) {
    return _guard('saveWorkout', () async {
      final ref = _workoutsRef(workout.userId);
      if (workout.id.isEmpty) {
        final doc = await ref.add(workout.toMap());
        return doc.id;
      } else {
        await ref.doc(workout.id).set(workout.toMap());
        return workout.id;
      }
    });
  }

  Stream<List<Workout>> watchWorkouts(String uid) {
    return _guardStream(
      'watchWorkouts',
      _workoutsRef(uid)
          .orderBy('date', descending: true)
          .snapshots()
          .map(
            (snap) =>
                snap.docs.map((d) => Workout.fromMap(d.id, d.data())).toList(),
          ),
    );
  }

  Future<void> deleteWorkout(String uid, String workoutId) {
    return _guard(
      'deleteWorkout',
      () => _workoutsRef(uid).doc(workoutId).delete(),
    );
  }

  // ---------- Biblioteca de exercícios ----------

  Stream<List<Exercise>> watchExercises() {
    return _guardStream(
      'watchExercises',
      _db
          .collection(FirestorePaths.exercises)
          .orderBy('name')
          .snapshots()
          .map(
            (snap) =>
                snap.docs.map((d) => Exercise.fromMap(d.id, d.data())).toList(),
          ),
    );
  }

  Future<void> seedExercise(Exercise exercise) {
    return _guard('seedExercise', () {
      return _db
          .collection(FirestorePaths.exercises)
          .doc(exercise.id)
          .set(exercise.toMap(), SetOptions(merge: true));
    });
  }

  Future<void> deleteExercise(String id) {
    return _guard(
      'deleteExercise',
      () => _db.collection(FirestorePaths.exercises).doc(id).delete(),
    );
  }

  // ---------- Lembretes (água / suplementos) ----------

  CollectionReference<Map<String, dynamic>> _remindersRef(String uid) =>
      _db.collection(FirestorePaths.reminders(uid));

  Stream<List<Reminder>> watchReminders(String uid) {
    return _guardStream(
      'watchReminders',
      _remindersRef(uid)
          .orderBy('hour')
          .snapshots()
          .map(
            (snap) =>
                snap.docs.map((d) => Reminder.fromMap(d.id, d.data())).toList(),
          ),
    );
  }

  Future<String> saveReminder(String uid, Reminder reminder) {
    return _guard('saveReminder', () async {
      final ref = _remindersRef(uid);
      if (reminder.id.isEmpty) {
        final doc = await ref.add(reminder.toMap());
        return doc.id;
      } else {
        await ref.doc(reminder.id).set(reminder.toMap());
        return reminder.id;
      }
    });
  }

  Future<void> deleteReminder(String uid, String reminderId) {
    return _guard(
      'deleteReminder',
      () => _remindersRef(uid).doc(reminderId).delete(),
    );
  }

  // ---------- Fotos de evolução do corpo ----------

  CollectionReference<Map<String, dynamic>> _bodyPhotosRef(String uid) =>
      _db.collection(FirestorePaths.bodyPhotos(uid));

  Stream<List<BodyPhoto>> watchBodyPhotos(String uid) {
    return _guardStream(
      'watchBodyPhotos',
      _bodyPhotosRef(uid)
          .orderBy('date', descending: true)
          .snapshots()
          .map(
            (snap) => snap.docs
                .map((d) => BodyPhoto.fromMap(d.id, d.data()))
                .toList(),
          ),
    );
  }

  Future<void> addBodyPhoto(BodyPhoto photo) {
    return _guard(
      'addBodyPhoto',
      () => _bodyPhotosRef(photo.userId).add(photo.toMap()),
    );
  }

  Future<void> deleteBodyPhoto(String uid, String photoId) {
    return _guard(
      'deleteBodyPhoto',
      () => _bodyPhotosRef(uid).doc(photoId).delete(),
    );
  }

  // ---------- Chat com IA ----------

  CollectionReference<Map<String, dynamic>> _chatRef(String uid) =>
      _db.collection(FirestorePaths.chatMessages(uid));

  Stream<List<ChatMessage>> watchChatMessages(String uid) {
    return _guardStream(
      'watchChatMessages',
      _chatRef(uid)
          .orderBy('createdAt')
          .snapshots()
          .map(
            (snap) => snap.docs
                .map((d) => ChatMessage.fromMap(d.id, d.data()))
                .toList(),
          ),
    );
  }

  Future<void> addChatMessage(String uid, ChatMessage message) {
    return _guard('addChatMessage', () => _chatRef(uid).add(message.toMap()));
  }

  // ---------- Fotos de refeição ----------

  CollectionReference<Map<String, dynamic>> _mealPhotosRef(String uid) =>
      _db.collection(FirestorePaths.mealPhotos(uid));

  Stream<List<MealPhoto>> watchMealPhotos(String uid) {
    return _guardStream(
      'watchMealPhotos',
      _mealPhotosRef(uid)
          .orderBy('date', descending: true)
          .snapshots()
          .map(
            (snap) => snap.docs
                .map((d) => MealPhoto.fromMap(d.id, d.data()))
                .toList(),
          ),
    );
  }

  Future<String> addMealPhoto(MealPhoto photo) {
    return _guard('addMealPhoto', () async {
      final doc = await _mealPhotosRef(photo.userId).add(photo.toMap());
      return doc.id;
    });
  }

  Future<void> updateMealPhotoAnalysis(
    String uid,
    String photoId,
    String analysis,
  ) {
    return _guard(
      'updateMealPhotoAnalysis',
      () => _mealPhotosRef(uid).doc(photoId).update({'aiAnalysis': analysis}),
    );
  }

  Future<void> deleteMealPhoto(String uid, String photoId) {
    return _guard(
      'deleteMealPhoto',
      () => _mealPhotosRef(uid).doc(photoId).delete(),
    );
  }

  // ---------- Planos de treino (instrutor -> aluno) ----------

  CollectionReference<Map<String, dynamic>> _trainingPlansRef(String uid) =>
      _db.collection(FirestorePaths.trainingPlans(uid));

  Stream<List<TrainingPlan>> watchTrainingPlans(String studentUid) {
    return _guardStream(
      'watchTrainingPlans',
      _trainingPlansRef(studentUid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (snap) => snap.docs
                .map((d) => TrainingPlan.fromMap(d.id, d.data()))
                .toList(),
          ),
    );
  }

  Future<void> saveTrainingPlan(TrainingPlan plan) {
    return _guard('saveTrainingPlan', () async {
      final ref = _trainingPlansRef(plan.studentUid);
      if (plan.id.isEmpty) {
        await ref.add(plan.toMap());
      } else {
        await ref.doc(plan.id).set(plan.toMap());
      }
    });
  }

  Future<void> deleteTrainingPlan(String studentUid, String planId) {
    return _guard(
      'deleteTrainingPlan',
      () => _trainingPlansRef(studentUid).doc(planId).delete(),
    );
  }

  /// Atualiza a nota do instrutor sobre um aluno (ex: "dor lombar
  /// crônica"), usada como contexto para as sugestões de IA. Guardada
  /// junto da entrada denormalizada em `users/{instructorId}/students`.
  Future<void> updateStudentNote(
    String instructorId,
    String studentUid,
    String note,
  ) {
    return _guard('updateStudentNote', () {
      return _db
          .collection(FirestorePaths.students(instructorId))
          .doc(studentUid)
          .set({'notes': note}, SetOptions(merge: true));
    });
  }

  // ---------- Estatísticas (painel de administração) ----------
  //
  // Usa aggregate queries (`.count()`) — o Firestore conta no servidor sem
  // baixar os documentos, então isso é barato mesmo com muitos registros.

  Future<int> countUsers() {
    return _guard('countUsers', () async {
      final snap = await _db.collection(FirestorePaths.users).count().get();
      return snap.count ?? 0;
    });
  }

  Future<int> countUsersByRole(String role) {
    return _guard('countUsersByRole', () async {
      final snap = await _db
          .collection(FirestorePaths.users)
          .where('role', isEqualTo: role)
          .count()
          .get();
      return snap.count ?? 0;
    });
  }

  Future<int> countExercises() {
    return _guard('countExercises', () async {
      final snap = await _db.collection(FirestorePaths.exercises).count().get();
      return snap.count ?? 0;
    });
  }

  /// Total de treinos registrados por todos os usuários — usa uma
  /// *collection group query* (soma a subcoleção `workouts` de todo mundo
  /// de uma vez).
  Future<int> countWorkoutsLogged() {
    return _guard('countWorkoutsLogged', () async {
      final snap = await _db.collectionGroup('workouts').count().get();
      return snap.count ?? 0;
    });
  }

  // ---------- Timeline (mural de avisos) ----------

  CollectionReference<Map<String, dynamic>> get _announcementsRef =>
      _db.collection('announcements');

  Stream<List<Announcement>> watchAnnouncements() {
    return _guardStream(
      'watchAnnouncements',
      _announcementsRef
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (snap) => snap.docs
                .map((d) => Announcement.fromMap(d.id, d.data()))
                .toList(),
          ),
    );
  }

  Future<void> createAnnouncement(Announcement announcement) {
    return _guard(
      'createAnnouncement',
      () => _announcementsRef.add(announcement.toMap()),
    );
  }

  Future<void> deleteAnnouncement(String id) {
    return _guard(
      'deleteAnnouncement',
      () => _announcementsRef.doc(id).delete(),
    );
  }

  Future<void> toggleAnnouncementLike(String id, String uid, bool liked) {
    return _guard('toggleAnnouncementLike', () {
      return _announcementsRef.doc(id).update({
        'likeUids': liked
            ? FieldValue.arrayUnion([uid])
            : FieldValue.arrayRemove([uid]),
      });
    });
  }
}
