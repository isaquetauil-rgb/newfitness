import 'package:flutter/material.dart';

import 'package:newfitness/features/exercises/logic/exercise_filter.dart';
import 'package:newfitness/shared/models/exercise.dart';

/// Abre a folha de filtros (grupo, músculo, equipamento, dificuldade,
/// categoria, unilateral e objetivo) usada tanto na biblioteca de exercícios
/// quanto no seletor de exercício ao montar um treino/ficha. A busca por nome
/// fica no campo da própria tela e é mantida ao aplicar os filtros.
Future<ExerciseFilter?> showExerciseFilterSheet(
  BuildContext context, {
  required ExerciseFilter current,
  required List<String> equipmentOptions,
}) {
  return showModalBottomSheet<ExerciseFilter>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ExerciseFilterSheet(
      initial: current,
      equipmentOptions: equipmentOptions,
    ),
  );
}

class _ExerciseFilterSheet extends StatefulWidget {
  const _ExerciseFilterSheet({
    required this.initial,
    required this.equipmentOptions,
  });

  final ExerciseFilter initial;
  final List<String> equipmentOptions;

  @override
  State<_ExerciseFilterSheet> createState() => _ExerciseFilterSheetState();
}

class _ExerciseFilterSheetState extends State<_ExerciseFilterSheet> {
  late Set<String> _groups = {...widget.initial.muscleGroups};
  late Set<String> _muscles = {...widget.initial.muscles};
  late bool? _unilateral = widget.initial.unilateral;
  late Set<String> _equipment = {...widget.initial.equipment};
  late Set<String> _difficulty = {...widget.initial.difficultyLevels};
  late Set<String> _objectives = {...widget.initial.objectives};
  late Set<String> _categories = {...widget.initial.categories};

  void _toggle(Set<String> set, String value) {
    setState(() {
      if (!set.add(value)) set.remove(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Filtros',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _groups = {};
                    _muscles = {};
                    _unilateral = null;
                    _equipment = {};
                    _difficulty = {};
                    _objectives = {};
                    _categories = {};
                  }),
                  child: const Text('Limpar'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FilterSection(
                      label: 'Grupo muscular',
                      options: canonicalMuscleGroups,
                      selected: _groups,
                      onToggle: (v) => _toggle(_groups, v),
                    ),
                    _FilterSection(
                      label: 'Músculo (principal ou secundário)',
                      options: canonicalMuscles,
                      selected: _muscles,
                      onToggle: (v) => _toggle(_muscles, v),
                    ),
                    _FilterSection(
                      label: 'Categoria',
                      options: exerciseCategories,
                      optionLabel: exerciseCategoryLabel,
                      selected: _categories,
                      onToggle: (v) => _toggle(_categories, v),
                    ),
                    _FilterSection(
                      label: 'Equipamento',
                      options: widget.equipmentOptions,
                      selected: _equipment,
                      onToggle: (v) => _toggle(_equipment, v),
                    ),
                    _FilterSection(
                      label: 'Nível de dificuldade',
                      options: exerciseDifficultyLevels,
                      optionLabel: exerciseDifficultyLabel,
                      selected: _difficulty,
                      onToggle: (v) => _toggle(_difficulty, v),
                    ),
                    _FilterSection(
                      label: 'Lado',
                      options: const ['sim', 'nao'],
                      optionLabel: (v) =>
                          v == 'sim' ? 'Só unilaterais' : 'Só bilaterais',
                      selected: {
                        if (_unilateral == true) 'sim',
                        if (_unilateral == false) 'nao',
                      },
                      onToggle: (v) => setState(() {
                        final value = v == 'sim';
                        _unilateral = _unilateral == value ? null : value;
                      }),
                    ),
                    _FilterSection(
                      label: 'Objetivo',
                      options: exerciseObjectiveSuggestions,
                      selected: _objectives,
                      onToggle: (v) => _toggle(_objectives, v),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.pop(
                context,
                ExerciseFilter(
                  muscleGroups: _groups,
                  muscles: _muscles,
                  equipment: _equipment,
                  difficultyLevels: _difficulty,
                  objectives: _objectives,
                  categories: _categories,
                  unilateral: _unilateral,
                  query: widget.initial.query,
                ),
              ),
              child: const Text('Aplicar filtros'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.label,
    required this.options,
    required this.selected,
    required this.onToggle,
    this.optionLabel,
  });

  final String label;
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final String Function(String)? optionLabel;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                FilterChip(
                  label: Text(optionLabel?.call(option) ?? option),
                  selected: selected.contains(option),
                  onSelected: (_) => onToggle(option),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Linha com o número de resultados e o botão "Limpar tudo" (busca e
/// filtros), usada na biblioteca e no seletor de exercícios.
class ExerciseResultsBar extends StatelessWidget {
  const ExerciseResultsBar({
    super.key,
    required this.count,
    required this.canClear,
    required this.onClear,
  });

  final int count;
  final bool canClear;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              count == 1 ? '1 exercício' : '$count exercícios',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          if (canClear)
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.clear_all, size: 18),
              label: const Text('Limpar tudo'),
            ),
        ],
      ),
    );
  }
}
