import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/core/logging/app_logger.dart';
import 'package:newfitness/core/storage/local_prefs.dart';
import 'package:newfitness/features/workout/data/active_workout_store.dart';
import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/models/logged_exercise.dart';
import 'package:newfitness/shared/models/training_plan.dart';
import 'package:newfitness/shared/models/workout.dart';
import 'package:newfitness/shared/models/workout_set.dart';
import 'package:newfitness/shared/services/firestore_service.dart';

const _uuid = Uuid();
final _log = AppLogger.of('WorkoutProvider');

/// Resultado de [WorkoutProvider.finishWorkout].
enum WorkoutFinishResult {
  /// Treino gravado no histórico (e progresso registrado).
  saved,

  /// Treino (de plano ou livre) encerrado sem nenhuma série realizada: não
  /// vira sessão (nada é gravado, não conta como dia treinado nem gera
  /// progresso) — só sai do modo de treino.
  endedWithoutSets,

  /// A gravação falhou; o treino em andamento continua intacto.
  failed,
}

/// Gerencia o treino em andamento (sessão atual) e o histórico salvo.
class WorkoutProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;

  /// Rascunho local do treino em andamento (sobrevive a fechar o app). Nulo
  /// quando não há armazenamento local disponível (ex: testes).
  final ActiveWorkoutStore? _store;

  WorkoutProvider({
    FirestoreService? firestoreService,
    ActiveWorkoutStore? store,
  }) : _firestoreService = firestoreService ?? getIt<FirestoreService>(),
       _store =
           store ??
           (getIt.isRegistered<LocalPrefs>() && getIt.isReadySync<LocalPrefs>()
               ? ActiveWorkoutStore(getIt<LocalPrefs>())
               : null);

  /// Notifica a UI e atualiza o rascunho local.
  void _changed() {
    notifyListeners();
    final workout = _activeWorkout;
    final startedAt = _startedAt;
    if (workout != null && startedAt != null) {
      unawaited(_store?.save(workout, startedAt));
    }
  }

  /// Restaura o treino em andamento de [userId] salvo localmente (ex: o app
  /// foi fechado no meio do treino). Nunca restaura o de outro usuário, e
  /// não mexe num treino que já esteja ativo.
  Future<bool> restoreFor(String userId) async {
    if (_activeWorkout != null || _store == null) return false;
    final restored = await _store.load(userId);
    if (restored == null || _activeWorkout != null) return false;
    _activeWorkout = restored.$1;
    _startedAt = restored.$2;
    notifyListeners();
    return true;
  }

  Workout? _activeWorkout;
  DateTime? _startedAt;
  bool _saving = false;

  Workout? get activeWorkout => _activeWorkout;
  bool get hasActiveWorkout => _activeWorkout != null;
  bool get isSaving => _saving;

  /// [source] só é passado por [startFromPlan]; treino livre fica sem
  /// origem.
  void startWorkout(
    String userId, {
    String name = 'Treino',
    WorkoutSource? source,
  }) {
    _activeWorkout = Workout(
      id: '',
      userId: userId,
      date: DateTime.now(),
      name: name,
      exercises: [],
      source: source,
    );
    _startedAt = DateTime.now();
    _changed();
  }

  /// Exercício adicionado à mão — nunca tem prescrição, mesmo num treino
  /// que veio de um plano.
  void addExercise(Exercise exercise) {
    if (_activeWorkout == null) return;
    _activeWorkout!.exercises.add(
      LoggedExercise(exerciseId: exercise.id, exerciseName: exercise.name),
    );
    _changed();
  }

  /// Inicia o treino a partir de um sub-treino específico do plano (ex:
  /// "Treino A"), identificado por [subWorkoutIndex] — o aluno cai direto
  /// na tela de registro de séries já com os exercícios prescritos.
  ///
  /// Cada exercício recebe uma CÓPIA da prescrição do plano
  /// ([LoggedExercise.prescription]) e o número de séries prescrito, todas
  /// VAZIAS (0 reps, 0 kg, não concluídas): a meta é só orientação na tela;
  /// o que conta como realizado é o que o aluno digitar. O treino guarda a
  /// origem ([Workout.source]).
  void startFromPlan(String userId, TrainingPlan plan, int subWorkoutIndex) {
    final subWorkout = plan.workouts[subWorkoutIndex];
    startWorkout(
      userId,
      name: '${plan.title} · ${subWorkout.label}',
      source: WorkoutSource(
        planId: plan.id,
        planTitle: plan.title,
        subWorkoutLabel: subWorkout.label,
      ),
    );
    for (final planExercise in subWorkout.exercises) {
      _activeWorkout!.exercises.add(
        LoggedExercise(
          exerciseId: planExercise.exerciseId,
          exerciseName: planExercise.exerciseName,
          sets: List.generate(
            planExercise.targetSets.clamp(1, 20),
            (_) => WorkoutSet(),
          ),
          // Cópia independente (não a mesma instância do plano).
          prescription: PlanExercise.fromMap(planExercise.toMap()),
        ),
      );
    }
    _changed();
  }

  void addSet(int exerciseIndex) {
    _activeWorkout?.exercises[exerciseIndex].sets.add(WorkoutSet());
    _changed();
  }

  void removeSet(int exerciseIndex, int setIndex) {
    _activeWorkout?.exercises[exerciseIndex].sets.removeAt(setIndex);
    _changed();
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
    _changed();
  }

  void removeExercise(int exerciseIndex) {
    _activeWorkout?.exercises.removeAt(exerciseIndex);
    _changed();
  }

  /// Substitui o exercício em [exerciseIndex] por [newExercise] (ver
  /// "Trocar exercício" em `WorkoutScreen`), preservando as séries já
  /// preenchidas (peso/reps/concluída) e registrando o exercício original —
  /// ele continua existindo normalmente na biblioteca, só deixa de ser o
  /// prescrito nesta entrada específica do treino.
  void substituteExercise(int exerciseIndex, Exercise newExercise) {
    final current = _activeWorkout?.exercises[exerciseIndex];
    if (current == null) return;
    final originId = current.replacedExerciseId ?? current.exerciseId;
    final originName = current.replacedExerciseName ?? current.exerciseName;
    // Voltar para o exercício ORIGINAL da cadeia (A → B → A) desfaz a
    // troca: sem isso ficava "A no lugar de A".
    final backToOrigin = newExercise.id == originId;
    _activeWorkout!.exercises[exerciseIndex] = LoggedExercise(
      exerciseId: newExercise.id,
      exerciseName: newExercise.name,
      sets: current.sets.map((s) => s.copy()).toList(),
      replacedExerciseId: backToOrigin ? null : originId,
      replacedExerciseName: backToOrigin ? null : originName,
      // A prescrição continua sendo a do exercício ORIGINAL — não é
      // convertida para o novo exercício.
      prescription: current.prescription,
    );
    _changed();
  }

  void cancelWorkout() {
    _activeWorkout = null;
    _startedAt = null;
    unawaited(_store?.clear());
    notifyListeners();
  }

  Future<WorkoutFinishResult> finishWorkout() async {
    if (_activeWorkout == null) return WorkoutFinishResult.failed;
    final realized = withoutEmptySets(_activeWorkout!.exercises);
    // Regra do produto: um treino só vira sessão concluída se tiver ao
    // menos UMA série realizada (mesma regra de série vazia da limpeza
    // abaixo) — vale para treino de plano e livre. Sem nenhuma, não grava
    // `Workout`: não aparece no histórico, no calendário/semana (que contam
    // treinos gravados), nas estatísticas do admin, nem gera progresso.
    if (!hasRealizedSets(realized)) {
      _activeWorkout = null;
      _startedAt = null;
      await _store?.clear();
      notifyListeners();
      return WorkoutFinishResult.endedWithoutSets;
    }
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
        exercises: realized,
        durationSeconds: duration,
        source: _activeWorkout!.source,
      );
      await _firestoreService.saveWorkout(toSave);
      // Não bloqueia a finalização do treino nem falha ela se der errado —
      // é um rollup derivado, o treino em si já está salvo e é a fonte da
      // verdade (ver `FirestoreService.recordExerciseProgress`).
      unawaited(
        _firestoreService
            .recordExerciseProgress(toSave)
            .catchError(
              (e, st) => _log.warning('Falha ao registrar progresso', e, st),
            ),
      );
      _activeWorkout = null;
      _startedAt = null;
      _saving = false;
      unawaited(_store?.clear());
      notifyListeners();
      return WorkoutFinishResult.saved;
    } catch (e) {
      _saving = false;
      notifyListeners();
      return WorkoutFinishResult.failed;
    }
  }

  Stream<List<Workout>> watchHistory(String userId) {
    return _firestoreService.watchWorkouts(userId);
  }

  /// Séries que não foram realizadas: não concluídas, sem reps e sem
  /// carga (ex: as séries vazias criadas para representar a quantidade
  /// prescrita). Uma série concluída com 0 kg NÃO entra aqui (peso do
  /// corpo), nem qualquer série com reps ou carga.
  static bool isEmptySet(WorkoutSet s) =>
      !s.completed && s.reps == 0 && s.weightKg == 0;

  /// Alguma série foi realizada? (qualquer série que não seja vazia — reps,
  /// carga, ou concluída mesmo com 0 kg, ex: peso do corpo).
  static bool hasRealizedSets(List<LoggedExercise> exercises) =>
      exercises.any((e) => e.sets.any((s) => !isEmptySet(s)));

  /// Cópia de [exercises] sem as séries vazias — usada ao finalizar, para o
  /// histórico contar só o realizado. O exercício é mantido mesmo que fique
  /// sem nenhuma série. A lista do treino em andamento não é alterada (se a
  /// gravação falhar, o aluno continua de onde estava).
  @visibleForTesting
  static List<LoggedExercise> withoutEmptySets(List<LoggedExercise> exercises) {
    return [
      for (final e in exercises)
        e.copyWith(
          sets: [
            for (final s in e.sets)
              if (!isEmptySet(s)) s.copy(),
          ],
        ),
    ];
  }
}
