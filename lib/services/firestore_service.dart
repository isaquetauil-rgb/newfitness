import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/body_photo.dart';
import '../models/chat_message.dart';
import '../models/exercise.dart';
import '../models/meal_photo.dart';
import '../models/reminder.dart';
import '../models/user_profile.dart';
import '../models/workout.dart';

/// Encapsula toda a leitura/escrita no Cloud Firestore.
///
/// Coleções usadas:
///   users/{uid}                -> perfil do usuário
///   users/{uid}/workouts/{id}  -> treinos daquele usuário
///   exercises/{id}             -> biblioteca de exercícios (global)
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------- Perfil ----------

  Future<void> createUserProfile(UserProfile profile) {
    return _db.collection('users').doc(profile.uid).set(profile.toMap());
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromMap(uid, doc.data()!);
  }

  Future<void> updateUserProfile(UserProfile profile) {
    return _db
        .collection('users')
        .doc(profile.uid)
        .set(profile.toMap(), SetOptions(merge: true));
  }

  // ---------- Instrutor / Aluno ----------

  /// Gera um código de convite curto e garante que ele é único entre os
  /// instrutores já cadastrados.
  Future<String> generateUniqueInviteCode() async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // sem O/0/I/1 (evita confusão)
    final random = DateTime.now().microsecondsSinceEpoch;

    for (int attempt = 0; attempt < 10; attempt++) {
      final seed = random + attempt;
      final code = List.generate(6, (i) {
        final index = (seed ~/ (i + 1) + i * 31) % chars.length;
        return chars[index.abs()];
      }).join();

      final existing = await _db
          .collection('users')
          .where('inviteCode', isEqualTo: code)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) return code;
    }
    // Extremamente improvável de chegar aqui, mas garante um valor válido.
    return 'F${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Procura um instrutor pelo código de convite. Retorna null se não existir.
  Future<UserProfile?> findInstructorByCode(String code) async {
    final query = await _db
        .collection('users')
        .where('role', isEqualTo: 'instructor')
        .where('inviteCode', isEqualTo: code.trim().toUpperCase())
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    final doc = query.docs.first;
    return UserProfile.fromMap(doc.id, doc.data());
  }

  /// Vincula um aluno a um instrutor: grava instructorId no perfil do aluno
  /// e adiciona uma entrada denormalizada em users/{instructorId}/students.
  Future<void> linkStudentToInstructor({
    required UserProfile student,
    required String instructorId,
  }) async {
    final batch = _db.batch();

    final studentRef = _db.collection('users').doc(student.uid);
    batch.set(studentRef, {'instructorId': instructorId}, SetOptions(merge: true));

    final studentEntryRef = _db
        .collection('users')
        .doc(instructorId)
        .collection('students')
        .doc(student.uid);
    batch.set(studentEntryRef, {
      'name': student.name,
      'email': student.email,
      'linkedAt': DateTime.now().millisecondsSinceEpoch,
    });

    await batch.commit();
  }

  /// Lista (com atualização em tempo real) os alunos vinculados a um instrutor.
  Stream<List<Map<String, dynamic>>> watchStudents(String instructorId) {
    return _db
        .collection('users')
        .doc(instructorId)
        .collection('students')
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'uid': d.id, ...d.data()}).toList());
  }

  // ---------- Treinos ----------

  CollectionReference<Map<String, dynamic>> _workoutsRef(String uid) =>
      _db.collection('users').doc(uid).collection('workouts');

  Future<String> saveWorkout(Workout workout) async {
    final ref = _workoutsRef(workout.userId);
    if (workout.id.isEmpty) {
      final doc = await ref.add(workout.toMap());
      return doc.id;
    } else {
      await ref.doc(workout.id).set(workout.toMap());
      return workout.id;
    }
  }

  Stream<List<Workout>> watchWorkouts(String uid) {
    return _workoutsRef(uid)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Workout.fromMap(d.id, d.data()))
            .toList());
  }

  Future<void> deleteWorkout(String uid, String workoutId) {
    return _workoutsRef(uid).doc(workoutId).delete();
  }

  // ---------- Biblioteca de exercícios ----------

  Stream<List<Exercise>> watchExercises() {
    return _db.collection('exercises').orderBy('name').snapshots().map(
        (snap) =>
            snap.docs.map((d) => Exercise.fromMap(d.id, d.data())).toList());
  }

  Future<void> seedExercise(Exercise exercise) {
    return _db
        .collection('exercises')
        .doc(exercise.id)
        .set(exercise.toMap(), SetOptions(merge: true));
  }

  // ---------- Lembretes (água / suplementos) ----------

  CollectionReference<Map<String, dynamic>> _remindersRef(String uid) =>
      _db.collection('users').doc(uid).collection('reminders');

  Stream<List<Reminder>> watchReminders(String uid) {
    return _remindersRef(uid).orderBy('hour').snapshots().map((snap) =>
        snap.docs.map((d) => Reminder.fromMap(d.id, d.data())).toList());
  }

  Future<String> saveReminder(String uid, Reminder reminder) async {
    final ref = _remindersRef(uid);
    if (reminder.id.isEmpty) {
      final doc = await ref.add(reminder.toMap());
      return doc.id;
    } else {
      await ref.doc(reminder.id).set(reminder.toMap());
      return reminder.id;
    }
  }

  Future<void> deleteReminder(String uid, String reminderId) {
    return _remindersRef(uid).doc(reminderId).delete();
  }

  // ---------- Fotos de evolução do corpo ----------

  CollectionReference<Map<String, dynamic>> _bodyPhotosRef(String uid) =>
      _db.collection('users').doc(uid).collection('body_photos');

  Stream<List<BodyPhoto>> watchBodyPhotos(String uid) {
    return _bodyPhotosRef(uid)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => BodyPhoto.fromMap(d.id, d.data())).toList());
  }

  Future<void> addBodyPhoto(BodyPhoto photo) {
    return _bodyPhotosRef(photo.userId).add(photo.toMap());
  }

  Future<void> deleteBodyPhoto(String uid, String photoId) {
    return _bodyPhotosRef(uid).doc(photoId).delete();
  }

  // ---------- Chat com IA ----------

  CollectionReference<Map<String, dynamic>> _chatRef(String uid) =>
      _db.collection('users').doc(uid).collection('chat_messages');

  Stream<List<ChatMessage>> watchChatMessages(String uid) {
    return _chatRef(uid).orderBy('createdAt').snapshots().map((snap) =>
        snap.docs.map((d) => ChatMessage.fromMap(d.id, d.data())).toList());
  }

  Future<void> addChatMessage(String uid, ChatMessage message) {
    return _chatRef(uid).add(message.toMap());
  }

  // ---------- Fotos de refeição ----------

  CollectionReference<Map<String, dynamic>> _mealPhotosRef(String uid) =>
      _db.collection('users').doc(uid).collection('meal_photos');

  Stream<List<MealPhoto>> watchMealPhotos(String uid) {
    return _mealPhotosRef(uid)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => MealPhoto.fromMap(d.id, d.data())).toList());
  }

  Future<String> addMealPhoto(MealPhoto photo) async {
    final doc = await _mealPhotosRef(photo.userId).add(photo.toMap());
    return doc.id;
  }

  Future<void> updateMealPhotoAnalysis(String uid, String photoId, String analysis) {
    return _mealPhotosRef(uid).doc(photoId).update({'aiAnalysis': analysis});
  }

  Future<void> deleteMealPhoto(String uid, String photoId) {
    return _mealPhotosRef(uid).doc(photoId).delete();
  }
}
