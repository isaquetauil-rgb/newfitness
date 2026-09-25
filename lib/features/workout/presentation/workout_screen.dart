import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/app/routes/app_routes.dart';
import 'package:newfitness/app/widgets/drawer_menu_button.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/exercises/logic/exercise_pool.dart';
import 'package:newfitness/features/exercises/logic/exercise_provider.dart';
import 'package:newfitness/features/exercises/presentation/exercise_alternatives_sheet.dart';
import 'package:newfitness/features/instructor/logic/custom_exercise_provider.dart';
import 'package:newfitness/features/workout/logic/prescription_format.dart';
import 'package:newfitness/features/workout/logic/training_plan_provider.dart';
import 'package:newfitness/features/workout/logic/workout_provider.dart';
import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/models/logged_exercise.dart';
import 'package:newfitness/shared/models/sample_exercises.dart';
import 'package:newfitness/shared/models/training_plan.dart';
import 'package:newfitness/shared/models/user_profile.dart';

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
          ? const _ActiveWorkoutBody()
          : const _StartWorkoutBody(),
      floatingActionButton: workout.hasActiveWorkout
          ? FloatingActionButton.extended(
              onPressed: workout.isSaving
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      if (workout.activeWorkout!.exercises.isEmpty) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Adicione ao menos um exercício antes de '
                              'finalizar.',
                            ),
                          ),
                        );
                        return;
                      }
                      final result = await context
                          .read<WorkoutProvider>()
                          .finishWorkout();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(switch (result) {
                            WorkoutFinishResult.saved => 'Treino salvo! 💪',
                            WorkoutFinishResult.endedWithoutSets =>
                              'Nenhuma série registrada — o treino foi '
                                  'encerrado sem entrar no histórico.',
                            WorkoutFinishResult.failed =>
                              'Não foi possível salvar o treino. '
                                  'Verifique a conexão e tente de novo — '
                                  'nada foi perdido.',
                          }),
                        ),
                      );
                    },
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
          'Inicie um treino livre ou siga um plano do seu instrutor.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        Center(
          child: ElevatedButton.icon(
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

  Widget _buildList(BuildContext context, List<Exercise> custom) {
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
        for (int i = 0; i < exercises.length; i++)
          // A chave amarra cada card (e os campos de texto dentro dele) ao
          // exercício, não à posição — sem ela, remover um exercício fazia
          // os cards seguintes exibirem os valores digitados no anterior.
          _ExerciseCard(
            key: ObjectKey(exercises[i]),
            exerciseIndex: i,
            exercise: exercises[i],
            isUnilateral: unilateralIds.contains(exercises[i].exerciseId),
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

  const _ExerciseCard({
    super.key,
    required this.exerciseIndex,
    required this.exercise,
    this.isUnilateral = false,
  });

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
            if (exercise.prescription != null) ...[
              const SizedBox(height: 8),
              _PrescriptionBlock(
                exercise: exercise,
                isUnilateral: isUnilateral,
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
                  child: Text('Série', style: TextStyle(color: Colors.grey)),
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
  });

  final LoggedExercise exercise;
  final bool isUnilateral;

  @override
  Widget build(BuildContext context) {
    final p = exercise.prescription!;
    final load = prescriptionLoad(p);
    final notes = p.notes?.trim();
    final title = exercise.prescriptionMatchesExercise
        ? 'Prescrito'
        : 'Prescrito para ${p.exerciseName}';
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
