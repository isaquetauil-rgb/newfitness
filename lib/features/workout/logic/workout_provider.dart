import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/models/logged_exercise.dart';
import 'package:newfitness/shared/models/training_plan.dart';
import 'package:newfitness/shared/models/workout.dart';
import 'package:newfitness/shared/models/workout_set.dart';
import 'package:newfitness/shared/services/firestore_service.dart';

const _uuid = Uuid();

/// Gerencia o treino em andamento (sessão atual) e o histórico salvo.
class WorkoutProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;

  WorkoutProvider({FirestoreService? firestoreService})
    : _firestoreService = firestoreService ?? getIt<FirestoreService>();

  Workout? _activeWorkout;
  DateTime? _startedAt;
  bool _saving = false;

  Workout? get activeWorkout => _activeWorkout;
  bool get hasActiveWorkout => _activeWorkout != null;
  bool get isSaving => _saving;

  void startWorkout(String userId, {String name = 'Treino'}) {
    _activeWorkout = Workout(
      id: '',
      userId: userId,
      date: DateTime.now(),
      name: name,
      exercises: [],
    );
    _startedAt = DateTime.now();
    notifyListeners();
  }

  void addExercise(Exercise exercise) {
    if (_activeWorkout == null) return;
    _activeWorkout!.exercises.add(
      LoggedExercise(exerciseId: exercise.id, exerciseName: exercise.name),
    );
    notifyListeners();
  }

  /// Inicia um treino já com os exercícios de um [TrainingPlan] prescrito
  /// pelo instrutor — o aluno cai direto na tela de registro de séries.
  void startFromPlan(String userId, TrainingPlan plan) {
    startWorkout(userId, name: plan.title);
    for (final planExercise in plan.exercises) {
      _activeWorkout!.exercises.add(
        LoggedExercise(
          exerciseId: planExercise.exerciseId,
          exerciseName: planExercise.exerciseName,
        ),
      );
    }
    notifyListeners();
  }

  void addSet(int exerciseIndex) {
    _activeWorkout?.exercises[exerciseIndex].sets.add(WorkoutSet());
    notifyListeners();
  }

  void removeSet(int exerciseIndex, int setIndex) {
    _activeWorkout?.exercises[exerciseIndex].sets.removeAt(setIndex);
    notifyListeners();
  }

  void updateSet(
    int exerciseIndex,
    int setIndex, {
    int? reps,
    double? weightKg,
    bool? completed,
  }) {
    final set = _activeWorkout?.exercises[exerciseIndex].sets[setIndex];
    if (set == null) return;
    if (reps != null) set.reps = reps;
    if (weightKg != null) set.weightKg = weightKg;
    if (completed != null) set.completed = completed;
    notifyListeners();
  }

  void removeExercise(int exerciseIndex) {
    _activeWorkout?.exercises.removeAt(exerciseIndex);
    notifyListeners();
  }

  void cancelWorkout() {
    _activeWorkout = null;
    _startedAt = null;
    notifyListeners();
  }

  Future<bool> finishWorkout() async {
    if (_activeWorkout == null) return false;
    _saving = true;
    notifyListeners();
    try {
      final duration = _startedAt == null
          ? 0
          : DateTime.now().difference(_startedAt!).inSeconds;
      final toSave = Workout(
        id: _uuid.v4(),
        userId: _activeWorkout!.userId,
        date: _activeWorkout!.date,
        name: _activeWorkout!.name,
        exercises: _activeWorkout!.exercises,
        durationSeconds: duration,
      );
      await _firestoreService.saveWorkout(toSave);
      _activeWorkout = null;
      _startedAt = null;
      _saving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _saving = false;
      notifyListeners();
      return false;
    }
  }

  Stream<List<Workout>> watchHistory(String userId) {
    return _firestoreService.watchWorkouts(userId);
  }
}
