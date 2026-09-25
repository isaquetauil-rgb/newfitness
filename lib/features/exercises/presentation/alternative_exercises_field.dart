import 'package:flutter/material.dart';

import 'package:newfitness/shared/models/exercise.dart';

/// Campo de formulário para curar manualmente `Exercise.alternativeExerciseIds`
/// — usado tanto no cadastro do admin (biblioteca global) quanto no do
/// instrutor (biblioteca privada). Mostra os vinculados como chips e abre
/// uma busca para adicionar mais.
class AlternativeExercisesField extends StatelessWidget {
  const AlternativeExercisesField({
    super.key,
    required this.allExercises,
    required this.excludeId,
    required this.selectedIds,
    required this.onChanged,
    this.title = 'Exercícios alternativos',
    this.helperText = 'Usados como sugestão prioritária em "Trocar exercício".',
    this.emptyText =
        'Nenhum vínculo ainda — o sistema ainda assim sugere alternativas '
        'automaticamente por grupo muscular, padrão de movimento e '
        'equipamento.',
  });

  /// Todos os exercícios disponíveis para vincular (o exercício em edição,
  /// se já tiver id, é removido da lista via [excludeId]).
  final List<Exercise> allExercises;
  final String? excludeId;
  final List<String> selectedIds;
  final ValueChanged<List<String>> onChanged;

  /// Permite reaproveitar este campo tanto para "variações" quanto para
  /// "substitutos" (ver `Exercise.variationExerciseIds` vs
  /// `Exercise.alternativeExerciseIds`), só trocando os textos.
  final String title;
  final String helperText;
  final String emptyText;

  Future<void> _openPicker(BuildContext context) async {
    final candidates = allExercises.where((e) => e.id != excludeId).toList();
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AlternativePickerSheet(
        candidates: candidates,
        initiallySelected: selectedIds,
      ),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final selectedExercises = allExercises
        .where((e) => selectedIds.contains(e.id))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton.icon(
              onPressed: () => _openPicker(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Vincular'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          helperText,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        if (selectedExercises.isEmpty)
          Text(
            emptyText,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final e in selectedExercises)
                Chip(
                  label: Text(e.name),
                  onDeleted: () =>
                      onChanged(selectedIds.where((id) => id != e.id).toList()),
                ),
            ],
          ),
      ],
    );
  }
}

class _AlternativePickerSheet extends StatefulWidget {
  const _AlternativePickerSheet({
    required this.candidates,
    required this.initiallySelected,
  });

  final List<Exercise> candidates;
  final List<String> initiallySelected;

  @override
  State<_AlternativePickerSheet> createState() =>
      _AlternativePickerSheetState();
}

class _AlternativePickerSheetState extends State<_AlternativePickerSheet> {
  late final Set<String> _selected = {...widget.initiallySelected};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.candidates
        .where((e) => e.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Vincular alternativas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, _selected.toList()),
                    child: const Text('Confirmar'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Buscar exercício...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('Nenhum exercício encontrado'))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final e = filtered[i];
                        final checked = _selected.contains(e.id);
                        return CheckboxListTile(
                          value: checked,
                          title: Text(e.name),
                          subtitle: Text(
                            [
                              e.muscleGroup,
                              e.equipment,
                            ].where((s) => s.isNotEmpty).join(' · '),
                          ),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _selected.add(e.id);
                            } else {
                              _selected.remove(e.id);
                            }
                          }),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
