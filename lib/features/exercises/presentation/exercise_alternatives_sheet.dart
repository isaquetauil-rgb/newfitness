import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:newfitness/app/routes/app_routes.dart';
import 'package:newfitness/features/exercises/logic/exercise_similarity.dart';
import 'package:newfitness/shared/models/exercise.dart';

/// Abre a folha "Trocar exercício": lista exercícios equivalentes a
/// [current] (mesmo grupo muscular/padrão de movimento/objetivo — ver
/// `findExerciseAlternatives`) dentro de [pool], e devolve o escolhido via
/// `Navigator.pop` (ou `null` se o usuário cancelar).
///
/// Usada tanto pelo aluno, ao trocar um exercício do treino em andamento
/// (`WorkoutScreen`), quanto pelo instrutor, ao trocar um exercício
/// prescrito num plano (`PlanEditorScreen`) — o chamador decide o que fazer
/// com o exercício devolvido (preservando séries/reps/descanso/observações).
Future<Exercise?> showExerciseAlternativesSheet(
  BuildContext context, {
  required Exercise current,
  required List<Exercise> pool,
}) {
  return showModalBottomSheet<Exercise>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => ExerciseAlternativesSheet(current: current, pool: pool),
  );
}

class ExerciseAlternativesSheet extends StatelessWidget {
  const ExerciseAlternativesSheet({
    super.key,
    required this.current,
    required this.pool,
  });

  final Exercise current;
  final List<Exercise> pool;

  Future<void> _confirmAndPop(BuildContext context, Exercise chosen) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Trocar exercício?'),
        content: Text(
          '"${current.name}" será substituído por "${chosen.name}". '
          'Séries, repetições, descanso e observações já preenchidos são '
          'mantidos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Trocar'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      Navigator.of(context).pop<Exercise>(chosen);
    }
  }

  Future<void> _openFullLibrary(BuildContext context) async {
    final chosen = await context.push<Exercise>(
      AppRoutes.workoutExercisePicker,
    );
    if (chosen != null && context.mounted) {
      Navigator.of(context).pop<Exercise>(chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final variations = findExerciseVariations(current, pool);
    final substitutes = findExerciseAlternatives(
      current,
      pool,
      excludeIds: variations.map((e) => e.id).toSet(),
    );
    final isEmpty = variations.isEmpty && substitutes.isEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Trocar exercício',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Alternativas compatíveis com "${current.name}"',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: isEmpty
                    ? _EmptyState(
                        onOpenLibrary: () => _openFullLibrary(context),
                      )
                    : ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: [
                          if (variations.isNotEmpty) ...[
                            const _SectionHeader('Variações deste exercício'),
                            for (final v in variations)
                              _AlternativeTile(
                                alternative: ExerciseAlternative(
                                  exercise: v,
                                  score: 1,
                                  reason: 'Variação cadastrada',
                                  curated: true,
                                ),
                                onTap: () => _confirmAndPop(context, v),
                              ),
                          ],
                          if (substitutes.isNotEmpty) ...[
                            const _SectionHeader('Substitutos equivalentes'),
                            for (final alt in substitutes)
                              _AlternativeTile(
                                alternative: alt,
                                onTap: () =>
                                    _confirmAndPop(context, alt.exercise),
                              ),
                          ],
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: OutlinedButton.icon(
                              onPressed: () => _openFullLibrary(context),
                              icon: const Icon(Icons.search),
                              label: const Text('Ver toda a biblioteca'),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onOpenLibrary});

  final VoidCallback onOpenLibrary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Nenhuma alternativa semelhante encontrada ainda.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onOpenLibrary,
              icon: const Icon(Icons.search),
              label: const Text('Ver toda a biblioteca'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlternativeTile extends StatelessWidget {
  const _AlternativeTile({required this.alternative, required this.onTap});

  final ExerciseAlternative alternative;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final exercise = alternative.exercise;
    final thumbnail = exercise.thumbnailUrl;

    final details = <String>[
      if (exercise.muscleGroup.isNotEmpty) exercise.muscleGroup,
      if (exercise.equipment.isNotEmpty) exercise.equipment,
      if (exercise.difficultyLevel.isNotEmpty)
        exerciseDifficultyLabel(exercise.difficultyLevel),
    ];

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.grey.shade100,
        backgroundImage: thumbnail != null && thumbnail.isNotEmpty
            ? NetworkImage(thumbnail)
            : null,
        child: thumbnail == null || thumbnail.isEmpty
            ? const Icon(Icons.fitness_center, color: Colors.black54)
            : null,
      ),
      title: Text(
        exercise.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(details.join(' · ')),
          Text(
            alternative.reason,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
