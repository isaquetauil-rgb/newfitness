import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/features/body_map/logic/missing_muscle_groups.dart';
import 'package:newfitness/features/body_map/presentation/complete_muscle_groups_screen.dart';
import 'package:newfitness/features/exercises/logic/exercise_pool.dart';
import 'package:newfitness/features/exercises/logic/exercise_similarity.dart';
import 'package:newfitness/app/routes/app_routes.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/instructor/logic/custom_exercise_provider.dart';
import 'package:newfitness/shared/models/exercise.dart';

/// Biblioteca privada de exercícios do instrutor logado — paralela à
/// biblioteca global do admin ([AdminExercisesScreen]), mas só ele enxerga e
/// usa ao montar planos (ver `ExercisePickerScreen`).
class CustomExercisesScreen extends StatelessWidget {
  const CustomExercisesScreen({super.key});

  Future<void> _confirmDelete(
    BuildContext context,
    String instructorUid,
    Exercise exercise,
  ) async {
    final provider = context.read<CustomExerciseProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover exercício?'),
        content: Text(
          '"${exercise.name}" sai da sua biblioteca e não aparece mais para '
          'escolher. Os treinos que já usaram o exercício continuam com ele '
          'no histórico e no mapa muscular.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await provider.deleteExercise(instructorUid, exercise.id);
    }
  }

  Future<void> _completeMissing(
    BuildContext context,
    String instructorUid,
    List<Exercise> missing,
  ) async {
    final provider = context.read<CustomExerciseProvider>();
    final navigator = Navigator.of(context);
    final pool = await loadExercisePool(context);
    final byId = {for (final e in missing) e.id: e};
    await navigator.push<bool>(
      MaterialPageRoute(
        builder: (_) => CompleteMuscleGroupsScreen(
          items: [
            for (final e in missing)
              MissingGroupItem(
                id: e.id,
                name: e.name,
                subtitle: e.equipment.isEmpty ? null : e.equipment,
                suggestion: suggestMuscleGroup(e.name, pool),
              ),
          ],
          onSave: (id, group) => provider.saveExercise(
            instructorUid,
            withExerciseGroup(byId[id]!, group),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final instructorUid = context.watch<AuthProvider>().user?.uid;
    final provider = context.watch<CustomExerciseProvider>();

    if (instructorUid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Meus exercícios')),
      body: StreamBuilder<List<Exercise>>(
        stream: provider.watchExercises(instructorUid),
        builder: (context, snapshot) {
          final exercises = snapshot.data ?? [];
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (exercises.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Nenhum exercício próprio ainda.\nCrie um com um link do '
                  'YouTube ou um vídeo gravado por você.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            );
          }
          final missing = customWithoutGroup(exercises);
          final offset = missing.isEmpty ? 0 : 1;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: exercises.length + offset,
            itemBuilder: (context, index) {
              if (index < offset) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: MissingGroupsBanner(
                    count: missing.length,
                    onComplete: () =>
                        _completeMissing(context, instructorUid, missing),
                  ),
                );
              }
              final exercise = exercises[index - offset];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(exercise.name),
                  subtitle: Text(
                    '${exercise.muscleGroup} · ${exercise.equipment}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () => context.push(
                          AppRoutes.instructorExerciseForm,
                          extra: exercise,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () =>
                            _confirmDelete(context, instructorUid, exercise),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.instructorExerciseForm),
        icon: const Icon(Icons.add),
        label: const Text('Novo exercício'),
      ),
    );
  }
}
