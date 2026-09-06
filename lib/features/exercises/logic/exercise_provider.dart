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
    _syncCanonicalExercises();
  }

  List<Exercise> _exercises = [];
  List<Exercise> get exercises => _exercises;

  /// Sincroniza a coleção `exercises` do Firestore com [sampleExercises]
  /// (merge-set, um write pequeno por exercício) toda vez que o app abre —
  /// não só quando a coleção está vazia. Isso corrige automaticamente
  /// documentos criados por uma versão anterior da biblioteca (ex: sem
  /// descrição/passo-a-passo) em vez de deixá-los desatualizados para
  /// sempre, já que o app não tem uma tela própria de edição da
  /// biblioteca compartilhada.
  Future<void> _syncCanonicalExercises() async {
    try {
      for (final exercise in sampleExercises) {
        await _firestoreService.seedExercise(exercise);
      }
      _log.info('Biblioteca de exercícios sincronizada com os dados padrão.');
    } catch (e, st) {
      _log.warning('Falha ao sincronizar a biblioteca de exercícios', e, st);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
