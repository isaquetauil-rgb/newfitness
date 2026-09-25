import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

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
        content: Text('"${exercise.name}" será removido da sua biblioteca.'),
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
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: exercises.length,
            itemBuilder: (context, i) {
              final exercise = exercises[i];
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
