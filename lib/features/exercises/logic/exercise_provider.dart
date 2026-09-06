import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/services/firestore_service.dart';

/// Mantém a lista de exercícios da biblioteca (vinda do Firestore) em cache
/// e notifica a UI quando ela é atualizada.
class ExerciseProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;
  StreamSubscription<List<Exercise>>? _sub;

  ExerciseProvider({FirestoreService? firestoreService})
    : _firestoreService = firestoreService ?? getIt<FirestoreService>() {
    _sub = _firestoreService.watchExercises().listen(
      (list) {
        _exercises = list;
        notifyListeners();
      },
      onError: (_) {
        // Sem conexão com o Firestore ainda configurado: a tela usa a
        // lista de exemplo local (ver sample_exercises.dart) como fallback.
      },
    );
  }

  List<Exercise> _exercises = [];
  List<Exercise> get exercises => _exercises;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
