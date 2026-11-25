import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/app/widgets/rename_dialog.dart';

import 'package:newfitness/app/routes/app_routes.dart';
import 'package:newfitness/app/widgets/drawer_menu_button.dart';
import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/features/achievements/presentation/achievements_screen.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/body_map/presentation/body_map_screen.dart';
import 'package:newfitness/features/exercises/logic/exercise_pool.dart';
import 'package:newfitness/features/exercises/logic/exercise_provider.dart';
import 'package:newfitness/features/exercises/presentation/exercise_alternatives_sheet.dart';
import 'package:newfitness/features/health/presentation/free_workout_gate.dart';
import 'package:newfitness/features/instructor/logic/custom_exercise_provider.dart';
import 'package:newfitness/features/progress/logic/progress_record_provider.dart';
import 'package:newfitness/features/stats/presentation/share_screens.dart';
import 'package:newfitness/features/workout/logic/prescription_format.dart';
import 'package:newfitness/shared/utils/one_rep_max.dart';
import 'package:newfitness/features/workout/logic/progression/suggest_next.dart';
import 'package:newfitness/features/workout/logic/progression/workout_suggestion.dart';
import 'package:newfitness/features/workout/logic/training_plan_provider.dart';
import 'package:newfitness/features/workout/logic/plate_calculator.dart';
import 'package:newfitness/features/workout/logic/warmup.dart';
import 'package:newfitness/features/workout/logic/workout_provider.dart';
import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/models/exercise_progress_record.dart';
import 'package:newfitness/shared/models/logged_exercise.dart';
import 'package:newfitness/shared/models/plate_setup.dart';
import 'package:newfitness/shared/models/sample_exercises.dart';
import 'package:newfitness/shared/models/training_plan.dart';
import 'package:newfitness/shared/models/user_profile.dart';
import 'package:newfitness/shared/models/workout.dart';
import 'package:newfitness/shared/models/workout_set.dart';
import 'package:newfitness/shared/models/workout_templates.dart';

import 'plate_calculator_sheet.dart';
import 'rest_timer_sheet.dart';

class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final workout = context.watch<WorkoutProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: workout.hasActiveWorkout
            ? InkWell(
                key: const ValueKey('rename-workout'),
                onTap: () async {
                  final name = await showRenameDialog(
                    context,
                    title: 'Nome do treino',
                    initial: workout.activeWorkout!.name,
                  );
                  if (name != null) {
                    workout.renameWorkout(name);
                  }
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        workout.activeWorkout!.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.edit_outlined, size: 18),
                  ],
                ),
              )
            : const Text('Treino'),
        actions: workout.hasActiveWorkout
            ? [
                IconButton(
                  icon: const Icon(Icons.timer_outlined),
                  tooltip: 'Cronômetro de descanso',
                  onPressed: () => showRestTimerSheet(context),
                ),
                TextButton(
                  onPressed: () => _confirmCancel(context),
                  child: const Text('Cancelar'),
                ),
              ]
            : null,
      ),
      body: workout.hasActiveWorkout
          ? Column(
              children: [
                // Fica fixo no topo enquanto a lista rola.
                RestTimerBar(controller: workout.restTimer),
                const Expanded(child: _ActiveWorkoutBody()),
              ],
            )
          : const _StartWorkoutBody(),
      floatingActionButton: workout.hasActiveWorkout
          ? FloatingActionButton.extended(
              onPressed: workout.isSaving
                  ? null
                  : () => finishActiveWorkout(context),
              icon: workout.isSaving
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check),
              label: const Text('Finalizar treino'),
            )
          : null,
    );
  }

  void _confirmCancel(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar treino?'),
        content: const Text('O progresso deste treino será perdido.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () {
              context.read<WorkoutProvider>().cancelWorkout();
              Navigator.pop(ctx);
            },
            child: const Text('Cancelar treino'),
          ),
        ],
      ),
    );
  }
}

class _StartWorkoutBody extends StatelessWidget {
  const _StartWorkoutBody();

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthProvider>().user?.uid ?? '';
    final planProvider = context.watch<TrainingPlanProvider>();

    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const Icon(Icons.fitness_center, size: 72, color: Colors.grey),
        const SizedBox(height: 16),
        const Text(
          'Nenhum treino em andamento',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'Escolha um treino pronto, siga o plano do seu personal ou monte '
          'um treino livre.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        Center(
          child: FilledButton.icon(
            onPressed: () => context.push(AppRoutes.workoutTemplates),
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Ver treinos prontos'),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: OutlinedButton.icon(
            key: const ValueKey('start-free-workout'),
            onPressed: () async {
              // Bloqueio do personal e aviso de responsabilidade (uma vez).
              if (!await ensureFreeWorkoutAllowed(context)) return;
              if (context.mounted) {
                context.read<WorkoutProvider>().startWorkout(uid);
              }
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Iniciar treino livre'),
          ),
        ),
        if (uid.isNotEmpty)
          StreamBuilder<List<TrainingPlan>>(
            stream: planProvider.watchPlans(uid),
            builder: (context, snapshot) {
              final plans = snapshot.data ?? [];
              if (plans.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Plano do seu instrutor',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    for (final plan in plans)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plan.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (plan.instructions != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  plan.instructions!,
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                              ],
                              for (
                                int w = 0;
                                w < plan.workouts.length;
                                w++
                              ) ...[
                                const SizedBox(height: 12),
                                const Divider(height: 1),
                                const SizedBox(height: 8),
                                Text(
                                  plan.workouts[w].label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                for (final e in plan.workouts[w].exercises)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2,
                                    ),
                                    child: Text(
                                      prescriptionSummaryLine(e),
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () => context
                                        .read<WorkoutProvider>()
                                        .startFromPlan(uid, plan, w),
                                    icon: const Icon(
                                      Icons.play_arrow,
                                      size: 18,
                                    ),
                                    label: Text(
                                      'Iniciar ${plan.workouts[w].label}',
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class _ActiveWorkoutBody extends StatefulWidget {
  const _ActiveWorkoutBody();

  @override
  State<_ActiveWorkoutBody> createState() => _ActiveWorkoutBodyState();
}

class _ActiveWorkoutBodyState extends State<_ActiveWorkoutBody> {
  // Biblioteca privada do instrutor (a própria, se instrutor; a do
  // instrutor vinculado, se aluno) — só para saber se um exercício é
  // unilateral e mostrar "(cada lado)" na prescrição.
  Stream<List<Exercise>>? _customStream;
  String? _customStreamUid;

  Stream<List<Exercise>> _customFor(String uid) {
    if (_customStream == null || _customStreamUid != uid) {
      _customStreamUid = uid;
      _customStream = context.read<CustomExerciseProvider>().watchExercises(
        uid,
      );
    }
    return _customStream!;
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    final customLibraryUid = profile == null
        ? null
        : profile.role == UserRole.instructor
        ? profile.uid
        : profile.instructorId;
    if (customLibraryUid == null) return _buildList(context, const []);
    return StreamBuilder<List<Exercise>>(
      stream: _customFor(customLibraryUid),
      builder: (context, snapshot) =>
          _buildList(context, snapshot.data ?? const []),
    );
  }

  // Última carga e recorde de cada exercício, para mostrar durante o treino.
  Stream<List<ExerciseProgressRecord>>? _records;
  String? _recordsUid;

  Stream<List<ExerciseProgressRecord>> _recordsFor(String uid) {
    if (_records == null || _recordsUid != uid) {
      _recordsUid = uid;
      try {
        _records = context.read<ProgressRecordProvider>().watchRecords(uid);
      } on ProviderNotFoundException {
        _records = const Stream.empty();
      }
    }
    return _records!;
  }

  /// Texto do bi-set/tri-set no card do exercício, ou `null` se sozinho.
  String? _supersetText(WorkoutProvider provider, int index) {
    final group = provider.supersetGroupOf(index);
    if (group == null) return null;
    final members = provider.supersetMembers(index);
    if (members.length < 2) return null;
    final pos = members.indexOf(index) + 1;
    final last = pos == members.length;
    return '${supersetLabel(group, members.length)} · $pos de '
        '${members.length} — '
        '${last ? 'depois deste, descanse' : 'sem descanso, vá para o próximo'}';
  }

  // Treinos já salvos, para a sugestão de carga.
  Stream<List<Workout>>? _history;
  String? _historyUid;

  Stream<List<Workout>> _historyFor(String uid) {
    if (_history == null || _historyUid != uid) {
      _historyUid = uid;
      try {
        _history = context.read<WorkoutProvider>().watchHistory(uid);
      } catch (_) {
        _history = const Stream.empty();
      }
    }
    return _history!;
  }

  Widget _buildList(BuildContext context, List<Exercise> custom) {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) {
      return _buildExercises(context, custom, const {}, const []);
    }
    return StreamBuilder<List<ExerciseProgressRecord>>(
      stream: _recordsFor(uid),
      builder: (context, records) => StreamBuilder<List<Workout>>(
        stream: _historyFor(uid),
        builder: (context, history) => _buildExercises(context, custom, {
          for (final record in records.data ?? const <ExerciseProgressRecord>[])
            record.exerciseId: record,
        }, history.data ?? const []),
      ),
    );
  }

  Widget _buildExercises(
    BuildContext context,
    List<Exercise> custom,
    Map<String, ExerciseProgressRecord> records,
    List<Workout> history,
  ) {
    final provider = context.watch<WorkoutProvider>();
    final exercises = provider.activeWorkout!.exercises;
    // Marcas de antes do treino, para comemorar recordes (não notifica).
    provider.setRecordBaselines({
      for (final r in records.values) r.exerciseId: r.baseline,
    });
    final global = context.watch<ExerciseProvider>().exercises;
    final library = <String, Exercise>{
      for (final e in [
        ...(global.isNotEmpty ? global : sampleExercises),
        ...custom,
      ])
        e.id: e,
    };
    // Exercícios com barra e anilhas: ganham a calculadora no campo de peso.
    final barbellIds = {
      for (final e in library.values)
        if (e.equipment.trim().toLowerCase() == 'barra' &&
            e.loadUnit != 'peso do corpo' &&
            !e.tracksDuration &&
            !e.tracksDistance)
          e.id,
    };
    final unilateralIds = {
      for (final e in library.values)
        if (e.isUnilateral) e.id,
    };

    // Sugestão de carga por exercício; preenche os campos uma vez.
    final suggestions = <int, ProgressionSuggestion>{};
    if (history.isNotEmpty) {
      for (int i = 0; i < exercises.length; i++) {
        final s = suggestionForLogged(
          exercises[i],
          history,
          library: library[exercises[i].exerciseId],
        );
        if (s != null) suggestions[i] = s;
      }
      if (suggestions.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final p = context.read<WorkoutProvider>();
          if (!p.hasActiveWorkout) return;
          suggestions.forEach(
            (i, s) => p.prefillSuggestion(i, s.weightKg, s.targetReps),
          );
        });
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Preencha cada série e toque em Finalizar treino para salvar.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
        for (int i = 0; i < exercises.length; i++)
          // A chave amarra cada card (e os campos de texto dentro dele) ao
          // exercício, não à posição — sem ela, remover um exercício fazia
          // os cards seguintes exibirem os valores digitados no anterior.
          _ExerciseCard(
            key: ObjectKey(exercises[i]),
            exerciseIndex: i,
            exercise: exercises[i],
            record: records[exercises[i].exerciseId],
            suggestion: suggestions[i],
            superset: _supersetText(provider, i),
            isUnilateral: unilateralIds.contains(exercises[i].exerciseId),
            isBarbell: barbellIds.contains(exercises[i].exerciseId),
            isTimed: isTimedExercise(
              exercises[i],
              library: library[exercises[i].exerciseId],
            ),
            isTemplate:
                provider.activeWorkout!.source?.planId.startsWith(
                  templatePlanPrefix,
                ) ??
                false,
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            final exercise = await context.push<Exercise>(
              AppRoutes.workoutExercisePicker,
            );
            if (exercise != null && context.mounted) {
              context.read<WorkoutProvider>().addExercise(exercise);
            }
          },
          icon: const Icon(Icons.add),
          label: const Text('Adicionar exercício'),
        ),
      ],
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final int exerciseIndex;
  final LoggedExercise exercise;

  /// O exercício REALIZADO é unilateral (mostra "(cada lado)" na
  /// prescrição; o modelo da série não muda).
  final bool isUnilateral;

  /// Veio de um treino pronto: a meta é sugestão, não prescrição.
  final bool isTemplate;

  /// Histórico deste exercício, para mostrar a última carga.
  final ExerciseProgressRecord? record;

  /// Sugestão de carga para hoje (já preenchida nos campos).
  final ProgressionSuggestion? suggestion;

  /// "Bi-set A · 1 de 2 — alterne; descanso depois do último", ou `null`.
  final String? superset;

  /// Exercício com barra: mostra a calculadora de anilhas no peso.
  final bool isBarbell;

  /// Exercício medido em segundos: a coluna "Reps" vira "Seg".
  final bool isTimed;

  const _ExerciseCard({
    super.key,
    required this.exerciseIndex,
    required this.exercise,
    this.isUnilateral = false,
    this.isTemplate = false,
    this.record,
    this.suggestion,
    this.superset,
    this.isBarbell = false,
    this.isTimed = false,
  });

  void _generateWarmup(BuildContext context) {
    // Fecha o teclado antes de mexer na lista: o campo em foco muda de
    // posição quando as séries de aquecimento entram.
    FocusScope.of(context).unfocus();
    final result = context.read<WorkoutProvider>().generateWarmup(
      exerciseIndex,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.alreadyHasWarmup
              ? 'Este exercício já tem aquecimento.'
              : result.count == 0
              ? 'Preencha a carga da série de trabalho para gerar o '
                    'aquecimento.'
              : '${result.count} séries de aquecimento adicionadas.',
        ),
      ),
    );
  }

  void _removeWarmup(BuildContext context) {
    FocusScope.of(context).unfocus();
    final provider = context.read<WorkoutProvider>();
    final removed = provider.removeWarmup(exerciseIndex);
    if (removed.isEmpty) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            removed.length == 1
                ? 'Aquecimento retirado.'
                : '${removed.length} séries de aquecimento retiradas.',
          ),
          action: SnackBarAction(
            label: 'Desfazer',
            onPressed: () => provider.restoreSets(exerciseIndex, removed),
          ),
        ),
      );
  }

  /// Apaga a série [setIndex] e oferece "Desfazer".
  static void deleteSet(BuildContext context, int exerciseIndex, int setIndex) {
    FocusScope.of(context).unfocus();
    final provider = context.read<WorkoutProvider>();
    final removed = provider.removeSet(exerciseIndex, setIndex);
    if (removed == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            removed.isWarmup
                ? 'Série de aquecimento excluída.'
                : 'Série excluída.',
          ),
          action: SnackBarAction(
            label: 'Desfazer',
            onPressed: () =>
                provider.insertSet(exerciseIndex, setIndex, removed),
          ),
        ),
      );
  }

  Future<void> _renameExercise(BuildContext context) async {
    final provider = context.read<WorkoutProvider>();
    final name = await showRenameDialog(
      context,
      title: 'Nome do exercício neste treino',
      initial: exercise.exerciseName,
    );
    if (name != null) provider.renameExercise(exerciseIndex, name);
  }

  void _explainSuggestion(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Por que essa carga?'),
        content: Text(
          '${suggestion!.reason}\n\nÉ só uma sugestão: ajuste peso e reps '
          'como fizer sentido para você hoje.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  Future<void> _swapExercise(BuildContext context) async {
    final provider = context.read<WorkoutProvider>();
    // Para achar o exercício atual, a lista completa; para as opções, sem
    // as versões gerais que o personal dono já tem como próprias.
    final all = await loadExercisePool(context);
    if (!context.mounted) return;
    final pool = await loadExercisePool(context, hideOwnerDuplicates: true);
    if (!context.mounted) return;
    final current = all.firstWhere(
      (e) => e.id == exercise.exerciseId,
      orElse: () => Exercise(
        id: exercise.exerciseId,
        name: exercise.exerciseName,
        muscleGroup: '',
        equipment: '',
        description: '',
        videoUrl: '',
      ),
    );
    final chosen = await showExerciseAlternativesSheet(
      context,
      current: current,
      pool: pool,
    );
    if (chosen != null && context.mounted) {
      provider.substituteExercise(exerciseIndex, chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<WorkoutProvider>();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    exercise.exerciseName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  key: ValueKey('rename-exercise-$exerciseIndex'),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: 'Renomear exercício',
                  onPressed: () => _renameExercise(context),
                ),
                IconButton(
                  icon: const Icon(Icons.swap_horiz, size: 20),
                  tooltip: 'Trocar exercício',
                  onPressed: () => _swapExercise(context),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => provider.removeExercise(exerciseIndex),
                ),
              ],
            ),
            if (superset != null)
              Padding(
                key: const ValueKey('superset-label'),
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  superset!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ),
              ),
            if (exercise.replacedExerciseName != null)
              Text(
                'No lugar de ${exercise.replacedExerciseName}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            if (isTimed && (record?.bestSeconds ?? 0) > 0)
              Text(
                'Recorde de tempo: ${formatSeconds(record!.bestSeconds!)}',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              )
            else if (record != null && record!.lastLoadKg > 0)
              Text(
                'Última vez: ${formatKg(record!.lastLoadKg)} · '
                'recorde: ${formatKg(record!.bestLoadKg)}',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (suggestion != null)
              Row(
                key: const ValueKey('load-suggestion'),
                children: [
                  Expanded(
                    child: Text(
                      'Sugestão de hoje: ${formatKg(suggestion!.weightKg)} × '
                      '${suggestion!.targetReps}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.info_outline, size: 20),
                    tooltip: 'Por que essa carga?',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _explainSuggestion(context),
                  ),
                ],
              ),
            if (exercise.prescription != null) ...[
              const SizedBox(height: 8),
              _PrescriptionBlock(
                exercise: exercise,
                isUnilateral: isUnilateral,
                isTemplate: isTemplate,
              ),
              const SizedBox(height: 12),
              Text(
                'Realizado',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(
                  width: 32,
                  child: Text('Nº', style: TextStyle(color: Colors.grey)),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      isTimed ? 'Kg (opcional)' : 'Kg',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
                if (isBarbell) const SizedBox(width: _plateButtonWidth),
                const SizedBox(width: 8),
                Expanded(
                  child: Center(
                    child: Text(
                      isTimed ? 'Segundos' : 'Reps',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
            for (int s = 0; s < exercise.sets.length; s++)
              Dismissible(
                key: ObjectKey(exercise.sets[s]),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
                onDismissed: (_) =>
                    _ExerciseCard.deleteSet(context, exerciseIndex, s),
                child: _SetRow(
                  exerciseIndex: exerciseIndex,
                  setIndex: s,
                  isBarbell: isBarbell,
                  isTimed: isTimed,
                  repsHint: exercise.prescription?.targetReps.trim() ?? '',
                  // Numera só as séries de trabalho (aquecimento mostra "A").
                  setNumber: exercise.sets
                      .take(s + 1)
                      .where((x) => !x.isWarmup)
                      .length,
                ),
              ),
            Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: () => provider.addSet(exerciseIndex),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Adicionar série'),
                ),
                if (exercise.sets.isNotEmpty)
                  TextButton.icon(
                    key: const ValueKey('remove-last-set'),
                    onPressed: () => _ExerciseCard.deleteSet(
                      context,
                      exerciseIndex,
                      exercise.sets.length - 1,
                    ),
                    icon: const Icon(Icons.remove, size: 18),
                    label: const Text('Excluir série'),
                  ),
                // Aquecimento por carga não se aplica a exercício por tempo.
                if (!isTimed && exercise.sets.any((x) => x.isWarmup))
                  TextButton.icon(
                    key: const ValueKey('remove-warmup'),
                    onPressed: () => _removeWarmup(context),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Tirar aquecimento'),
                  )
                else if (!isTimed)
                  TextButton.icon(
                    key: const ValueKey('generate-warmup'),
                    onPressed: () => _generateWarmup(context),
                    icon: const Icon(
                      Icons.local_fire_department_outlined,
                      size: 18,
                    ),
                    label: const Text('Gerar aquecimento'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Meta do plano para este exercício — só apresentação do que o instrutor
/// prescreveu. Não preenche os campos de execução e não compara com o
/// realizado.
class _PrescriptionBlock extends StatelessWidget {
  const _PrescriptionBlock({
    required this.exercise,
    required this.isUnilateral,
    this.isTemplate = false,
  });

  final LoggedExercise exercise;
  final bool isUnilateral;
  final bool isTemplate;

  @override
  Widget build(BuildContext context) {
    final p = exercise.prescription!;
    final load = prescriptionLoad(p);
    final notes = p.notes?.trim();
    final label = isTemplate ? 'Sugerido' : 'Prescrito';
    final title = exercise.prescriptionMatchesExercise
        ? label
        : '$label para ${p.exerciseName}';
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Container(
      key: const ValueKey('prescription-block'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(prescriptionSetsReps(p, unilateral: isUnilateral)),
          if (load != null) Text(load),
          Row(
            children: [
              Expanded(child: Text(prescriptionRest(p))),
              TextButton.icon(
                onPressed: () =>
                    showRestTimerSheet(context, initialSeconds: p.restSeconds),
                icon: const Icon(Icons.timer_outlined, size: 18),
                label: const Text('Descansar'),
              ),
            ],
          ),
          if (notes != null && notes.isNotEmpty)
            Text(
              notes,
              style: TextStyle(fontStyle: FontStyle.italic, color: muted),
            ),
        ],
      ),
    );
  }
}

/// Comemora um recorde: banner "Novo recorde!" no topo por alguns segundos
/// e uma vibração leve.
@visibleForTesting
void showRecordBanner(
  BuildContext context,
  WorkoutSet set,
  List<PersonalRecordKind> kinds,
) {
  HapticFeedback.lightImpact();
  final messenger = ScaffoldMessenger.of(context);
  final e1rm = epley1rm(set.weightKg, set.reps);
  final parts = [
    if (kinds.contains(PersonalRecordKind.load))
      'maior carga: ${formatKg(set.weightKg)}',
    if (kinds.contains(PersonalRecordKind.duration))
      'maior tempo: ${formatSeconds(set.seconds)}',
    if (kinds.contains(PersonalRecordKind.e1rm) && e1rm != null)
      '1RM estimado: ${formatKg(roundKg(e1rm))}',
  ];
  messenger
    ..hideCurrentMaterialBanner()
    ..showMaterialBanner(
      MaterialBanner(
        key: const ValueKey('record-banner'),
        leading: const Icon(Icons.emoji_events_outlined),
        content: Text('Novo recorde! ${parts.join(' · ')}'),
        actions: [
          TextButton(
            onPressed: messenger.hideCurrentMaterialBanner,
            child: const Text('OK'),
          ),
        ],
      ),
    );
  // Só esconde se nenhum recorde mais novo tomou o lugar deste banner.
  final shown = ++_recordBannerSeq;
  Timer(const Duration(seconds: 4), () {
    if (shown != _recordBannerSeq) return;
    try {
      messenger.hideCurrentMaterialBanner();
    } catch (_) {}
  });
}

int _recordBannerSeq = 0;

/// Largura do botão da calculadora de anilhas na linha da série.
const double _plateButtonWidth = 40;

class _SetRow extends StatelessWidget {
  final int exerciseIndex;
  final int setIndex;
  final int setNumber;
  final bool isBarbell;
  final bool isTimed;

  /// Meta de reps do plano (ex.: "10-12"), mostrada no campo vazio. A pessoa
  /// digita quantas fez.
  final String repsHint;

  const _SetRow({
    required this.exerciseIndex,
    required this.setIndex,
    required this.setNumber,
    this.isBarbell = false,
    this.isTimed = false,
    this.repsHint = '',
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<WorkoutProvider>();
    final set = context
        .watch<WorkoutProvider>()
        .activeWorkout!
        .exercises[exerciseIndex]
        .sets[setIndex];

    // Barra: se o peso digitado não fecha com as anilhas da academia, só
    // avisa o mais perto (o peso não muda sozinho).
    PlateLoad? plates;
    if (isBarbell && set.weightKg > 0) {
      final setup =
          context.watch<AuthProvider>().profile?.plateSetup ??
          const PlateSetup();
      final load = loadPlates(set.weightKg, setup);
      if (!load.exact && !load.belowBar) plates = load;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 32,
                child: PopupMenuButton<SetType>(
                  key: ValueKey('set-type-$exerciseIndex-$setIndex'),
                  tooltip: 'Tipo da série',
                  initialValue: set.type,
                  padding: EdgeInsets.zero,
                  onSelected: (t) =>
                      provider.setSetType(exerciseIndex, setIndex, t),
                  itemBuilder: (_) => [
                    for (final t in SetType.values)
                      PopupMenuItem(value: t, child: Text(t.label)),
                  ],
                  child: Text(
                    set.type == SetType.normal
                        ? '$setNumber'
                        : set.isWarmup
                        ? 'A'
                        : '$setNumber${set.type.letter}',
                    style: TextStyle(
                      fontWeight: set.type == SetType.normal
                          ? null
                          : FontWeight.w700,
                      color: set.isWarmup
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : set.type == SetType.normal
                          ? null
                          : Theme.of(context).colorScheme.tertiary,
                      decoration: TextDecoration.underline,
                      decorationStyle: TextDecorationStyle.dotted,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _NumberField(
                  suggested: set.suggested,
                  decimal: true,
                  initialValue: set.weightKg == 0
                      ? ''
                      : set.weightKg
                            .toString()
                            .replaceFirst(RegExp(r'\.0$'), '')
                            .replaceAll('.', ','),
                  onChanged: (v) => provider.updateSet(
                    exerciseIndex,
                    setIndex,
                    // aceita vírgula (teclado pt-BR): "22,5" → 22.5
                    weightKg:
                        double.tryParse(v.trim().replaceAll(',', '.')) ?? 0,
                  ),
                ),
              ),
              // Calculadora de anilhas: botão próprio, fora do campo, para o
              // toque não ir para o texto. Só lê o peso; ele só muda se o aluno
              // tocar em "Usar X kg" na folha.
              if (isBarbell)
                SizedBox(
                  width: _plateButtonWidth,
                  child: IconButton(
                    key: ValueKey('plates-$exerciseIndex-$setIndex'),
                    tooltip: 'Anilhas de cada lado',
                    icon: const Icon(Icons.calculate_outlined, size: 20),
                    onPressed: set.weightKg > 0
                        ? () {
                            FocusScope.of(context).unfocus();
                            showPlateCalculator(
                              context,
                              weightKg: set.weightKg,
                              onUse: (kg) => provider.updateSet(
                                exerciseIndex,
                                setIndex,
                                weightKg: kg,
                              ),
                            );
                          }
                        : null,
                  ),
                ),
              const SizedBox(width: 8),
              Expanded(
                // Exercício por tempo: o número é a duração em segundos.
                child: isTimed
                    ? _NumberField(
                        initialValue: set.seconds == 0 ? '' : '${set.seconds}',
                        onChanged: (v) => provider.updateSet(
                          exerciseIndex,
                          setIndex,
                          seconds: int.tryParse(v.trim()) ?? 0,
                        ),
                      )
                    : _NumberField(
                        suggested: set.suggested,
                        hint: set.isWarmup ? '' : repsHint,
                        initialValue: set.reps == 0 ? '' : set.reps.toString(),
                        onChanged: (v) => provider.updateSet(
                          exerciseIndex,
                          setIndex,
                          reps: int.tryParse(v.trim()) ?? 0,
                        ),
                      ),
              ),
              SizedBox(
                width: 40,
                child: Checkbox(
                  value: set.completed,
                  onChanged: (v) {
                    if (v == true && !WorkoutProvider.canComplete(set)) {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            duration: const Duration(seconds: 2),
                            content: Text(
                              isTimed
                                  ? 'Preencha os segundos antes de marcar.'
                                  : 'Preencha as repetições antes de marcar.',
                            ),
                          ),
                        );
                      return;
                    }
                    final records = provider.updateSet(
                      exerciseIndex,
                      setIndex,
                      completed: v ?? false,
                    );
                    if (records.isNotEmpty) {
                      showRecordBanner(context, set, records);
                    }
                  },
                ),
              ),
            ],
          ),
          if (plates != null)
            Padding(
              key: ValueKey('plates-hint-$exerciseIndex-$setIndex'),
              padding: const EdgeInsets.only(left: 32, top: 2),
              child: Text(
                'Não fecha com suas anilhas. O mais perto é '
                '${formatKg(plates.achievedKg)} (toque na calculadora para '
                'usar).',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Campo numérico de uma série. Acompanha o valor do modelo quando ele muda
/// por fora (ex.: a sugestão de carga chega depois de a tela abrir), sem
/// atrapalhar quem está digitando ("22," continua "22,").
class _NumberField extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onChanged;

  /// Valor ainda é só a sugestão: aparece mais apagado.
  final bool suggested;

  /// Aceita casas decimais (peso). Reps e segundos são inteiros.
  final bool decimal;

  /// Texto apagado no campo vazio (ex.: meta "10-12").
  final String hint;

  const _NumberField({
    required this.initialValue,
    required this.onChanged,
    this.suggested = false,
    this.decimal = false,
    this.hint = '',
  });

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final _controller = TextEditingController(text: widget.initialValue);

  static double? _parse(String v) =>
      double.tryParse(v.trim().replaceAll(',', '.'));

  @override
  void didUpdateWidget(covariant _NumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = widget.initialValue;
    // Vazio e 0 são o mesmo valor no modelo: sem isso, digitar "0,5"
    // apagaria o "0" no meio.
    if ((_parse(_controller.text) ?? 0) != (_parse(incoming) ?? 0)) {
      _controller.text = incoming;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      keyboardType: TextInputType.numberWithOptions(decimal: widget.decimal),
      textAlign: TextAlign.center,
      style: widget.suggested
          ? TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)
          : null,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        hintText: widget.hint.isEmpty ? null : widget.hint,
      ),
      onChanged: widget.onChanged,
    );
  }
}

/// Finaliza o treino em andamento: valida, salva (com o fim real do treino),
/// envia ao Health Connect/Apple Saúde, avisa conquistas e mostra o resumo.
/// Usado pelo botão "Finalizar treino" e pelo aviso de treino esquecido.
Future<void> finishActiveWorkout(BuildContext context) async {
  final provider = context.read<WorkoutProvider>();
  final messenger = ScaffoldMessenger.of(context);
  final exercises = provider.activeWorkout!.exercises;
  if (exercises.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Adicione ao menos um exercício antes de finalizar.'),
      ),
    );
    return;
  }

  // Sem séries o treino não é salvo: avisa antes de ele sumir.
  if (!WorkoutProvider.hasRealizedSets(exercises)) {
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nenhuma série preenchida'),
        content: const Text(
          'Para salvar, preencha o peso ou as repetições, ou marque a '
          'série como feita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sair sem salvar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continuar treino'),
          ),
        ],
      ),
    );
    if (discard != true) return;
    await provider.finishWorkout();
    return;
  }

  // Biblioteca (com arquivados) para gravar o retrato dos músculos. Se não
  // carregar a tempo, o treino é salvo sem retrato (o mapa usa a
  // biblioteca, como nos treinos antigos).
  Exercise? Function(String)? lookup;
  try {
    lookup = await loadExerciseLookup(context)
        .timeout(const Duration(seconds: 5));
  } catch (_) {}
  if (!context.mounted) return;
  final result = await provider.finishWorkout(lookup: lookup);
  if (!context.mounted) return;
  if (result == WorkoutFinishResult.saved) {
    final saved = provider.lastSaved!;
    final records = provider.lastSavedRecords;
    // Health Connect / Apple Saúde (se ligado): cópia, não bloqueia.
    unawaited(healthSyncOrNull?.onWorkoutFinished(saved));
    // Conquistas novas: grava no perfil e avisa antes do resumo.
    final earned = await syncAchievementsAfterWorkout(context, saved);
    if (!context.mounted) return;
    if (earned.isNotEmpty) await showAchievementsEarned(context, earned);
    if (!context.mounted) return;
    _showSavedSummary(context, saved, records);
  } else if (result == WorkoutFinishResult.failed) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Não foi possível salvar o treino. Verifique a conexão e tente '
          'de novo. Nada foi perdido.',
        ),
      ),
    );
  }
}

void _showSavedSummary(
  BuildContext context,
  Workout saved,
  List<PersonalRecord> records,
) {
  final volume = saved.totalVolume;
  // Exercícios sem série realizada continuam no treino, mas não contam.
  final done = saved.exercises.where((e) => e.sets.isNotEmpty).length;
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.check_circle_outline, size: 40),
      title: const Text('Treino salvo!'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$done exercício(s) · ${saved.totalSets} '
              'série(s)${volume > 0 ? ' · ${formatKg(volume)}' : ''}',
            ),
            if (records.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                records.length == 1
                    ? 'Recorde de hoje'
                    : 'Recordes de hoje (${records.length})',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              for (final r in records)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.emoji_events_outlined, size: 18),
                      const SizedBox(width: 6),
                      Expanded(child: Text(r.label)),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 12),
            const Text('Ele fica guardado no seu histórico, em Progresso.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Fechar'),
        ),
        TextButton.icon(
          onPressed: () {
            Navigator.pop(ctx);
            openWorkoutShare(context, saved, records);
          },
          icon: const Icon(Icons.share, size: 18),
          label: const Text('Compartilhar'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(ctx);
            context.go(AppRoutes.progress);
          },
          child: const Text('Ver no histórico'),
        ),
      ],
    ),
  );
}
