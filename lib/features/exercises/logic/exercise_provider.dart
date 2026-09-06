import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/core/logging/app_logger.dart';
import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/models/sample_exercises.dart';
import 'package:newfitness/shared/services/firestore_service.dart';

final _log = AppLogger.of('ExerciseProvider');

/// Mantém a lista de exercícios da biblioteca (vinda do Firestore) em cache
/// e notifica a UI quando ela é atualizada.
class ExerciseProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;
  StreamSubscription<List<Exercise>>? _sub;
  bool _seeding = false;

  ExerciseProvider({FirestoreService? firestoreService})
    : _firestoreService = firestoreService ?? getIt<FirestoreService>() {
    _sub = _firestoreService.watchExercises().listen(
      (list) {
        _exercises = list;
        notifyListeners();
        if (list.isEmpty) _seedIfEmpty();
      },
      onError: (_) {
        // Sem conexão com o Firestore ainda configurado: a tela usa a
        // lista de exemplo local (ver sample_exercises.dart) como fallback.
      },
    );
  }

  List<Exercise> _exercises = [];
  List<Exercise> get exercises => _exercises;

  /// Popula a coleção `exercises` do Firestore com a biblioteca padrão na
  /// primeira vez que ela está vazia — assim o app já nasce com uma
  /// biblioteca de verdade, em vez de depender só do fallback local
  /// ([sampleExercises], usado enquanto isso não acontece).
  Future<void> _seedIfEmpty() async {
    if (_seeding) return;
    _seeding = true;
    try {
      for (final exercise in sampleExercises) {
        await _firestoreService.seedExercise(exercise);
      }
      _log.info('Biblioteca de exercícios populada com os dados padrão.');
    } catch (e, st) {
      _log.warning('Falha ao popular a biblioteca de exercícios', e, st);
    } finally {
      _seeding = false;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
