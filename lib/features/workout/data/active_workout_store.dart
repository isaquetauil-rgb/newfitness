import 'dart:convert';

import 'package:newfitness/core/logging/app_logger.dart';
import 'package:newfitness/core/storage/local_prefs.dart';
import 'package:newfitness/shared/models/workout.dart';

final _log = AppLogger.of('ActiveWorkoutStore');

/// Rascunho local do treino EM ANDAMENTO, para não perder as séries já
/// digitadas se o app for fechado (ou morto pelo sistema) no meio do treino.
///
/// Não é fonte de verdade: o registro definitivo continua sendo o documento
/// em `users/{uid}/workouts`, gravado só ao finalizar. Guarda apenas o que o
/// próprio [Workout] já tem (nome, exercícios, séries/carga/reps) + o dono e
/// o horário de início — nada de token, e-mail ou outros dados da conta.
class ActiveWorkoutStore {
  ActiveWorkoutStore(this._prefs);

  final LocalPrefs _prefs;

  static const _version = 1;

  Future<void> save(Workout workout, DateTime startedAt) async {
    try {
      await _prefs.setActiveWorkoutJson(
        jsonEncode({
          'v': _version,
          'userId': workout.userId,
          'startedAt': startedAt.millisecondsSinceEpoch,
          'workout': workout.toMap(),
        }),
      );
    } catch (e, st) {
      _log.warning('Falha ao salvar o treino em andamento', e, st);
    }
  }

  /// Devolve o rascunho de [uid], ou null. Um rascunho de OUTRO usuário (ou
  /// corrompido/de outra versão) é descartado e nunca restaurado.
  Future<(Workout, DateTime)?> load(String uid) async {
    final raw = _prefs.activeWorkoutJson;
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final owner = map['userId'] as String?;
      if (map['v'] != _version || owner == null || owner != uid) {
        await clear();
        return null;
      }
      final workout = Workout.fromMap(
        '',
        map['workout'] as Map<String, dynamic>,
      );
      if (workout.userId != uid) {
        await clear();
        return null;
      }
      final startedAt = DateTime.fromMillisecondsSinceEpoch(
        map['startedAt'] as int,
      );
      return (workout, startedAt);
    } catch (e, st) {
      _log.warning('Rascunho de treino inválido — descartado', e, st);
      await clear();
      return null;
    }
  }

  Future<void> clear() async {
    try {
      await _prefs.clearActiveWorkout();
    } catch (e, st) {
      _log.warning('Falha ao limpar o treino em andamento', e, st);
    }
  }
}
