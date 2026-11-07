import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/app/routes/app_routes.dart';
import 'package:newfitness/app/widgets/drawer_menu_button.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/exercises/logic/exercise_pool.dart';
import 'package:newfitness/features/exercises/logic/exercise_provider.dart';
import 'package:newfitness/features/exercises/presentation/exercise_alternatives_sheet.dart';
import 'package:newfitness/features/instructor/logic/custom_exercise_provider.dart';
import 'package:newfitness/features/progress/logic/progress_record_provider.dart';
import 'package:newfitness/features/workout/logic/prescription_format.dart';
import 'package:newfitness/features/workout/logic/training_plan_provider.dart';
import 'package:newfitness/features/workout/logic/workout_provider.dart';
import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/models/exercise_progress_record.dart';
import 'package:newfitness/shared/models/logged_exercise.dart';
import 'package:newfitness/shared/models/sample_exercises.dart';
import 'package:newfitness/shared/models/training_plan.dart';
import 'package:newfitness/shared/models/user_profile.dart';
import 'package:newfitness/shared/models/workout.dart';
import 'package:newfitness/shared/models/workout_templates.dart';

import 'rest_timer_sheet.dart';

class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final workout = context.watch<WorkoutProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: Text(
          workout.hasActiveWorkout ? workout.activeWorkout!.name : 'Treino',
        ),
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
                if (workout.restEndsAt != null)
                  _RestBar(
                    key: ValueKey(workout.restEndsAt),
                    endsAt: workout.restEndsAt!,
                    totalSeconds: workout.restTotalSeconds,
                  ),
                const Expanded(child: _ActiveWorkoutBody()),
              ],
            )
          : const _StartWorkoutBody(),
      floatingActionButton: workout.hasActiveWorkout
          ? FloatingActionButton.extended(
              onPressed: workout.isSaving ? null : () => _finish(context),
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

  Future<void> _finish(BuildContext context) async {
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

    final result = await provider.finishWorkout();
    if (!context.mounted) return;
    if (result == WorkoutFinishResult.saved) {
      _showSavedSummary(context, provider.lastSaved!);
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

  void _showSavedSummary(BuildContext context, Workout saved) {
    final volume = saved.totalVolume;
    // Exercícios sem série realizada continuam no treino, mas não contam.
    final done = saved.exercises.where((e) => e.sets.isNotEmpty).length;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle_outline, size: 40),
        title: const Text('Treino salvo!'),
        content: Text(
          '$done exercício(s) · ${saved.totalSets} '
          'série(s)${volume > 0 ? ' · ${volume.toStringAsFixed(0)} kg' : ''}'
          '\n\nEle fica guardado no seu histórico, em Progresso.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
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

/// Contagem do descanso entre séries, iniciada ao marcar uma série.
class _RestBar extends StatefulWidget {
  const _RestBar({super.key, required this.endsAt, required this.totalSeconds});

  final DateTime endsAt;
  final int totalSeconds;

  @override
  State<_RestBar> createState() => _RestBarState();
}

class _RestBarState extends State<_RestBar> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    if (!DateTime.now().isBefore(widget.endsAt)) {
      _timer?.cancel();
      HapticFeedback.heavyImpact();
      context.read<WorkoutProvider>().skipRest();
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<WorkoutProvider>();
    final left = widget.endsAt
        .difference(DateTime.now())
        .inSeconds
        .clamp(0, widget.totalSeconds);
    final label = '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}';
    const ink = Color(0xFF14171A);

    return Material(
      color: Theme.of(context).colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            const Icon(Icons.timer_outlined, color: ink),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Descanso $label',
                    style: const TextStyle(
                      color: ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: widget.totalSeconds == 0
                        ? 0
                        : left / widget.totalSeconds,
                    color: ink,
                    backgroundColor: Colors.white54,
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => provider.addRest(15),
              style: TextButton.styleFrom(foregroundColor: ink),
              child: const Text('+15 s'),
            ),
            TextButton(
              onPressed: provider.skipRest,
              style: TextButton.styleFrom(foregroundColor: ink),
              child: const Text('Pular'),
            ),
          ],
        ),
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
            onPressed: () => context.read<WorkoutProvider>().startWorkout(uid),
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
                                      '${e.exerciseName} — ${e.targetSets}x'
                                      '${e.targetReps}'
                                      '${e.targetWeightsKg.isNotEmpty ? ' · ${e.targetWeightsKg} kg' : ''}'
                                      ' · ${e.restSeconds}s descanso',
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

  Widget _buildList(BuildContext context, List<Exercise> custom) {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) return _buildExercises(context, custom, const {});
    return StreamBuilder<List<ExerciseProgressRecord>>(
      stream: _recordsFor(uid),
      builder: (context, snapshot) => _buildExercises(context, custom, {
        for (final record in snapshot.data ?? const <ExerciseProgressRecord>[])
          record.exerciseId: record,
      }),
    );
  }

  Widget _buildExercises(
    BuildContext context,
    List<Exercise> custom,
    Map<String, ExerciseProgressRecord> records,
  ) {
    final provider = context.watch<WorkoutProvider>();
    final exercises = provider.activeWorkout!.exercises;
    final global = context.watch<ExerciseProvider>().exercises;
    final unilateralIds = {
      for (final e in [
        ...custom,
        ...(global.isNotEmpty ? global : sampleExercises),
      ])
        if (e.isUnilateral) e.id,
    };

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
            isUnilateral: unilateralIds.contains(exercises[i].exerciseId),
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

  const _ExerciseCard({
    super.key,
    required this.exerciseIndex,
    required this.exercise,
    this.isUnilateral = false,
    this.isTemplate = false,
    this.record,
  });

  static String _kg(double value) => value
      .toStringAsFixed(1)
      .replaceFirst(RegExp(r'\.0$'), '')
      .replaceAll('.', ',');

  Future<void> _swapExercise(BuildContext context) async {
    final provider = context.read<WorkoutProvider>();
    final pool = await loadExercisePool(context);
    if (!context.mounted) return;
    final current = pool.firstWhere(
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
            if (exercise.replacedExerciseName != null)
              Text(
                'No lugar de ${exercise.replacedExerciseName}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            if (record != null && record!.lastLoadKg > 0)
              Text(
                'Última vez: ${_kg(record!.lastLoadKg)} kg · '
                'recorde: ${_kg(record!.bestLoadKg)} kg',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
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
              children: const [
                SizedBox(
                  width: 32,
                  child: Text('Nº', style: TextStyle(color: Colors.grey)),
                ),
                Expanded(
                  child: Center(
                    child: Text('Kg', style: TextStyle(color: Colors.grey)),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text('Reps', style: TextStyle(color: Colors.grey)),
                  ),
                ),
                SizedBox(width: 40),
              ],
            ),
            for (int s = 0; s < exercise.sets.length; s++)
              _SetRow(
                key: ObjectKey(exercise.sets[s]),
                exerciseIndex: exerciseIndex,
                setIndex: s,
                setNumber: s + 1,
              ),
            TextButton.icon(
              onPressed: () => provider.addSet(exerciseIndex),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Adicionar série'),
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

class _SetRow extends StatelessWidget {
  final int exerciseIndex;
  final int setIndex;
  final int setNumber;

  const _SetRow({
    super.key,
    required this.exerciseIndex,
    required this.setIndex,
    required this.setNumber,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<WorkoutProvider>();
    final set = context
        .watch<WorkoutProvider>()
        .activeWorkout!
        .exercises[exerciseIndex]
        .sets[setIndex];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 32, child: Text('$setNumber')),
          Expanded(
            child: _NumberField(
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
                weightKg: double.tryParse(v.trim().replaceAll(',', '.')) ?? 0,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _NumberField(
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
              onChanged: (v) => provider.updateSet(
                exerciseIndex,
                setIndex,
                completed: v ?? false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final String initialValue;
  final ValueChanged<String> onChanged;

  const _NumberField({required this.initialValue, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(vertical: 8),
      ),
      onChanged: onChanged,
    );
  }
}
