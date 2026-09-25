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
    _subscribe();
  }

  bool _seedChecked = false;

  void _subscribe() {
    _sub?.cancel();
    _sub = _firestoreService.watchExercises().listen(
      (list) {
        _exercises = list;
        notifyListeners();
        if (!_seedChecked) {
          _seedChecked = true;
          if (list.isEmpty) _seedDefaultExercises();
        }
      },
      onError: (_) {
        // Sem permissão (ex: logout) ou sem conexão: a tela usa a lista de
        // exemplo local (ver sample_exercises.dart) como fallback até o
        // próximo [restart].
      },
    );
  }

  /// Refaz a assinatura da biblioteca — chamado quando o usuário logado
  /// muda (ver `app.dart`): um listener do Firestore que recebeu
  /// permission-denied (ex: no logout) morre e não volta sozinho.
  void restart() {
    _seedChecked = false;
    _subscribe();
  }

  List<Exercise> _exercises = [];
  List<Exercise> get exercises => _exercises;

  /// Semeia a coleção `exercises` com [sampleExercises] só quando ela está
  /// vazia — mesmo padrão de `ExerciseTaxonomyProvider`. Antes a
  /// sincronização rodava a cada abertura do app e sobrescrevia as edições
  /// que o admin fazia pela tela de administração (e recriava exercícios
  /// padrão que ele tinha apagado). Só o admin consegue gravar aqui (ver
  /// `firestore.rules`); para os demais a tentativa falha e é ignorada.
  Future<void> _seedDefaultExercises() async {
    try {
      for (final exercise in sampleExercises) {
        await _firestoreService.seedExercise(exercise);
      }
      _log.info('Biblioteca de exercícios semeada com os dados padrão.');
    } catch (e, st) {
      _log.warning('Falha ao semear a biblioteca de exercícios', e, st);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
