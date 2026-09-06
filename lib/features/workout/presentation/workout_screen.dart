import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/app/routes/app_routes.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/workout/logic/workout_provider.dart';
import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/models/logged_exercise.dart';

import 'rest_timer_sheet.dart';

class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final workout = context.watch<WorkoutProvider>();

    return Scaffold(
      appBar: AppBar(
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
                      final ok = await context
                          .read<WorkoutProvider>()
                          .finishWorkout();
                      if (context.mounted && ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Treino salvo! 💪')),
                        );
                      }
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fitness_center, size: 72, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Nenhum treino em andamento',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Inicie um treino para começar a registrar suas séries.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () =>
                  context.read<WorkoutProvider>().startWorkout(uid),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Iniciar treino'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveWorkoutBody extends StatelessWidget {
  const _ActiveWorkoutBody();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final exercises = provider.activeWorkout!.exercises;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        for (int i = 0; i < exercises.length; i++)
          _ExerciseCard(exerciseIndex: i, exercise: exercises[i]),
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

  const _ExerciseCard({required this.exerciseIndex, required this.exercise});

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
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => provider.removeExercise(exerciseIndex),
                ),
              ],
            ),
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

class _SetRow extends StatelessWidget {
  final int exerciseIndex;
  final int setIndex;
  final int setNumber;

  const _SetRow({
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
              initialValue: set.weightKg == 0 ? '' : set.weightKg.toString(),
              onChanged: (v) => provider.updateSet(
                exerciseIndex,
                setIndex,
                weightKg: double.tryParse(v) ?? 0,
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
                reps: int.tryParse(v) ?? 0,
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
