import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/core/logging/app_logger.dart';
import 'package:newfitness/core/storage/local_prefs.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:newfitness/features/notifications/data/notification_service.dart';
import 'package:newfitness/features/workout/data/active_workout_store.dart';
import 'package:newfitness/features/workout/data/rest_alerts.dart';
import 'package:newfitness/features/workout/logic/rest_timer_controller.dart';
import 'package:newfitness/features/workout/logic/warmup.dart';
import 'package:newfitness/shared/utils/one_rep_max.dart';
import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/models/logged_exercise.dart';
import 'package:newfitness/shared/models/training_plan.dart';
import 'package:newfitness/shared/models/workout.dart';
import 'package:newfitness/shared/models/workout_set.dart';
import 'package:newfitness/shared/models/workout_templates.dart';
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
    RestTimerController? restTimer,
    Future<void> Function(bool on)? keepScreenOn,
  }) : _firestoreService = firestoreService ?? getIt<FirestoreService>(),
       _store =
           store ??
           (_prefsReady ? ActiveWorkoutStore(getIt<LocalPrefs>()) : null),
       restTimer = restTimer ?? _defaultRestTimer(),
       _keepScreenOn = keepScreenOn ?? _defaultKeepScreenOn;

  static bool get _prefsReady =>
      getIt.isRegistered<LocalPrefs>() && getIt.isReadySync<LocalPrefs>();

  /// No app: avisos reais (notificação + vibração) e as preferências salvas.
  /// Sem os serviços registrados (testes), um cronômetro silencioso.
  static RestTimerController _defaultRestTimer() {
    if (!getIt.isRegistered<NotificationService>()) {
      return RestTimerController();
    }
    final prefs = _prefsReady ? getIt<LocalPrefs>() : null;
    return RestTimerController(
      alerts: LocalRestAlerts(getIt<NotificationService>()),
      settings: prefs == null
          ? const RestTimerSettings()
          : RestTimerSettings(
              autoStart: prefs.restAutoStart,
              sound: prefs.restSound,
              vibration: prefs.restVibration,
            ),
    );
  }

  static Future<void> _defaultKeepScreenOn(bool on) =>
      WakelockPlus.toggle(enable: on);

  /// Cronômetro de descanso entre séries do treino em andamento.
  final RestTimerController restTimer;

  /// Mantém a tela acesa enquanto há treino ativo (wakelock_plus).
  final Future<void> Function(bool on) _keepScreenOn;
  bool _screenKeptOn = false;

  void _setScreenOn(bool on) {
    if (_screenKeptOn == on) return;
    _screenKeptOn = on;
    unawaited(
      Future.sync(() => _keepScreenOn(on)).catchError((Object e) {
        _log.fine('Não foi possível mudar a tela acesa: $e');
      }),
    );
  }

  /// Encerra o que pertence ao treino ativo: descanso e tela acesa.
  void _endSession() {
    restTimer.skip();
    _setScreenOn(false);
  }

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
    _setScreenOn(true);
    notifyListeners();
    return true;
  }

  Workout? _activeWorkout;
  DateTime? _startedAt;
  bool _saving = false;
  Workout? _lastSaved;

  /// Treino gravado pelo último [finishWorkout], para o resumo na tela.
  Workout? get lastSaved => _lastSaved;

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
    restTimer.skip();
    _setScreenOn(true);
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
    // Bi-set/tri-set: os exercícios do mesmo grupo ficam juntos.
    for (final planExercise in groupSupersets(subWorkout.exercises)) {
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

  /// Inicia um treino pronto do catálogo: a sugestão de séries e repetições
  /// funciona como a prescrição de um plano.
  void startFromTemplate(
    String userId,
    WorkoutTemplate template,
    int subWorkoutIndex,
  ) => startFromPlan(userId, template.toPlan(userId), subWorkoutIndex);

  /// Começa de novo um treino do histórico: mesmos exercícios e quantidade
  /// de séries, todas vazias.
  void repeatWorkout(String userId, Workout workout) {
    startWorkout(userId, name: workout.name, source: workout.source);
    for (final exercise in workout.exercises) {
      _activeWorkout!.exercises.add(
        LoggedExercise(
          exerciseId: exercise.exerciseId,
          exerciseName: exercise.exerciseName,
          sets: List.generate(
            exercise.sets.length.clamp(1, 20),
            (_) => WorkoutSet(),
          ),
          prescription: exercise.prescription,
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

  /// Melhores marcas de cada exercício antes deste treino (por
  /// `exerciseId`), vindas de `progress_records` — a tela atualiza. Usadas
  /// para detectar recordes ao marcar séries e no resumo final.
  Map<String, RecordBaseline> _baselines = const {};

  void setRecordBaselines(Map<String, RecordBaseline> baselines) {
    _baselines = baselines;
  }

  List<PersonalRecord> _lastRecords = const [];

  /// Recordes batidos no treino gravado pelo último [finishWorkout].
  List<PersonalRecord> get lastSavedRecords => _lastRecords;

  /// Atualiza a série. Quando ela acaba de ser marcada como feita, devolve
  /// os recordes que ela bateu (vazio se nenhum), para a tela comemorar.
  List<PersonalRecordKind> updateSet(
    int exerciseIndex,
    int setIndex, {
    int? reps,
    double? weightKg,
    bool? completed,
  }) {
    final exercise = _activeWorkout?.exercises[exerciseIndex];
    final set = exercise?.sets[setIndex];
    if (exercise == null || set == null) return const [];
    final justCompleted = completed == true && !set.completed;
    if (reps != null) set.reps = reps;
    if (weightKg != null) set.weightKg = weightKg;
    if (completed != null) set.completed = completed;
    // Mexeu na série ou marcou como feita: a sugestão vira o realizado.
    if (reps != null || weightKg != null || completed == true) {
      set.suggested = false;
    }
    // Marcar a série como feita já começa o descanso indicado (se o início
    // automático estiver ligado nas configurações).
    // Em bi-set/tri-set, só depois do último exercício do grupo.
    if (justCompleted && isLastOfSuperset(exerciseIndex)) {
      restTimer.onSetCompleted(exercise.prescription?.restSeconds ?? 60);
    }
    _changed();
    if (!justCompleted) return const [];
    // Outras séries feitas hoje no mesmo exercício (inclusive se ele
    // aparece mais de uma vez no treino).
    final others = [
      for (final e in _activeWorkout!.exercises)
        if (e.exerciseId == exercise.exerciseId) ...e.sets,
    ];
    return detectSetRecords(set, others, _baselines[exercise.exerciseId]);
  }

  /// Exercícios do treino em andamento que já receberam a sugestão — para
  /// não preencher de novo se o aluno apagar os campos.
  final _prefilled = Expando<bool>('prefilled');

  /// Preenche as séries vazias do exercício com a sugestão de carga (marcadas
  /// como [WorkoutSet.suggested]). Só uma vez por exercício; séries que o
  /// aluno já preencheu ficam como estão.
  void prefillSuggestion(int exerciseIndex, double weightKg, int reps) {
    final exercises = _activeWorkout?.exercises;
    if (exercises == null || exerciseIndex >= exercises.length) return;
    final exercise = exercises[exerciseIndex];
    if (_prefilled[exercise] == true) return;
    _prefilled[exercise] = true;
    var changed = false;
    for (final set in exercise.sets) {
      if (!set.isWarmup &&
          !set.completed &&
          set.reps == 0 &&
          set.weightKg == 0) {
        set
          ..weightKg = weightKg
          ..reps = reps
          ..suggested = true;
        changed = true;
      }
    }
    if (changed) _changed();
  }

  /// Grupo de bi-set/tri-set do exercício (da prescrição), ou `null`.
  String? supersetGroupOf(int exerciseIndex) {
    final exercises = _activeWorkout?.exercises;
    if (exercises == null || exerciseIndex >= exercises.length) return null;
    return exercises[exerciseIndex].prescription?.supersetGroup;
  }

  /// Índices dos exercícios do treino no mesmo grupo de [exerciseIndex]
  /// (só ele mesmo, se não está em grupo).
  List<int> supersetMembers(int exerciseIndex) {
    final group = supersetGroupOf(exerciseIndex);
    if (group == null) return [exerciseIndex];
    final exercises = _activeWorkout!.exercises;
    return [
      for (int i = 0; i < exercises.length; i++)
        if (exercises[i].prescription?.supersetGroup == group) i,
    ];
  }

  /// O exercício fecha a rodada do bi-set (é o último do grupo)? Fora de
  /// grupo, sempre.
  bool isLastOfSuperset(int exerciseIndex) =>
      supersetMembers(exerciseIndex).last == exerciseIndex;

  /// Troca o tipo da série (normal, aquecimento, drop, falha).
  void setSetType(int exerciseIndex, int setIndex, SetType type) {
    final set = _activeWorkout?.exercises[exerciseIndex].sets[setIndex];
    if (set == null || set.type == type) return;
    set.type = type;
    _changed();
  }

  /// Monta séries de aquecimento antes da primeira série de trabalho, a
  /// partir da carga dela (ver [generateWarmupSets]). Substitui o
  /// aquecimento ainda não feito. Devolve quantas séries criou (0 se não há
  /// carga de trabalho preenchida).
  int generateWarmup(int exerciseIndex) {
    final exercise = _activeWorkout?.exercises[exerciseIndex];
    if (exercise == null) return 0;
    final work = exercise.sets
        .where((s) => !s.isWarmup && s.weightKg > 0)
        .map((s) => s.weightKg)
        .firstOrNull;
    if (work == null) return 0;
    final warmups = generateWarmupSets(work);
    if (warmups.isEmpty) return 0;
    exercise.sets.removeWhere((s) => s.isWarmup && !s.completed);
    final firstWork = exercise.sets.indexWhere((s) => !s.isWarmup);
    exercise.sets.insertAll(
      firstWork < 0 ? exercise.sets.length : firstWork,
      warmups,
    );
    _changed();
    return warmups.length;
  }

  /// Atalho para [RestTimerController.skip].
  void skipRest() => restTimer.skip();

  @override
  void dispose() {
    _setScreenOn(false);
    restTimer.dispose();
    super.dispose();
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
    _endSession();
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
      _endSession();
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
      _lastSaved = toSave;
      _lastRecords = recordsOfTheDay(realized, _baselines);
      _endSession();
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
  ///
  /// Série só com a sugestão de carga, sem o aluno mexer nem marcar como
  /// feita, também é vazia.
  static bool isEmptySet(WorkoutSet s) =>
      !s.completed && (s.suggested || (s.reps == 0 && s.weightKg == 0));

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
