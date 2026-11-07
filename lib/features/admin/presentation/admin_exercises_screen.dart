import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/app/routes/app_routes.dart';
import 'package:newfitness/features/admin/logic/admin_provider.dart';
import 'package:newfitness/features/exercises/logic/exercise_provider.dart';
import 'package:newfitness/shared/models/exercise.dart';

/// Gerenciamento da biblioteca de exercícios compartilhada — só o admin
/// escreve aqui (ver `firestore.rules`).
class AdminExercisesScreen extends StatelessWidget {
  const AdminExercisesScreen({super.key});

  Future<void> _confirmDelete(BuildContext context, Exercise exercise) async {
    final adminProvider = context.read<AdminProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover exercício?'),
        content: Text('"${exercise.name}" será removido da biblioteca.'),
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
      await adminProvider.deleteExercise(exercise.id);
    }
  }

  Future<void> _addMissing(BuildContext context) async {
    final provider = context.read<ExerciseProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final names = provider.missingDefaults.map((e) => e.name).toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Adicionar ${names.length} exercício(s)?'),
        content: SingleChildScrollView(child: Text(names.join('\n'))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final added = await provider.addMissingDefaults();
      messenger.showSnackBar(
        SnackBar(content: Text('$added exercício(s) adicionado(s).')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Não foi possível adicionar agora.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExerciseProvider>();
    final exercises = provider.exercises;
    final missing = exercises.isEmpty ? 0 : provider.missingDefaults.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca de exercícios'),
        actions: [
          if (missing > 0)
            TextButton.icon(
              onPressed: () => _addMissing(context),
              icon: const Icon(Icons.playlist_add),
              label: Text('$missing novos'),
            ),
        ],
      ),
      body: exercises.isEmpty
          ? const Center(child: Text('Nenhum exercício cadastrado ainda.'))
          : ListView.builder(
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
                            AppRoutes.adminExerciseForm,
                            extra: exercise,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => _confirmDelete(context, exercise),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.adminExerciseForm),
        icon: const Icon(Icons.add),
        label: const Text('Novo exercício'),
      ),
    );
  }
}
