import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/body_photo.dart';
import '../models/exercise.dart';
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
        .map(
          (snap) =>
              snap.docs.map((d) => Workout.fromMap(d.id, d.data())).toList(),
        );
  }

  Future<void> deleteWorkout(String uid, String workoutId) {
    return _workoutsRef(uid).doc(workoutId).delete();
  }

  // ---------- Biblioteca de exercícios ----------

  Stream<List<Exercise>> watchExercises() {
    return _db
        .collection('exercises')
        .orderBy('name')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => Exercise.fromMap(d.id, d.data())).toList(),
        );
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
    return _remindersRef(uid)
        .orderBy('hour')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => Reminder.fromMap(d.id, d.data())).toList(),
        );
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
        .map(
          (snap) =>
              snap.docs.map((d) => BodyPhoto.fromMap(d.id, d.data())).toList(),
        );
  }

  Future<void> addBodyPhoto(BodyPhoto photo) {
    return _bodyPhotosRef(photo.userId).add(photo.toMap());
  }

  Future<void> deleteBodyPhoto(String uid, String photoId) {
    return _bodyPhotosRef(uid).doc(photoId).delete();
  }
}
