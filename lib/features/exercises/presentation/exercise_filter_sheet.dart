import 'package:flutter/material.dart';

import 'package:newfitness/features/exercises/logic/exercise_filter.dart';
import 'package:newfitness/shared/models/exercise.dart';

/// Abre a folha de filtros avançados (equipamento, dificuldade, objetivo,
/// categoria) usada tanto na biblioteca de exercícios quanto no seletor de
/// exercício ao montar um treino/ficha. Filtro por grupo muscular fica fora
/// daqui de propósito — já existe como chips de acesso rápido na tela
/// (`ExerciseLibraryScreen`).
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
                  muscleGroups: widget.initial.muscleGroups,
                  equipment: _equipment,
                  difficultyLevels: _difficulty,
                  objectives: _objectives,
                  categories: _categories,
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
