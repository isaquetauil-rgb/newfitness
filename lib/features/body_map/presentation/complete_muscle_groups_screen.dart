import 'package:flutter/material.dart';

import 'package:newfitness/features/import/logic/workout_import.dart'
    show ownExerciseMuscleGroups;

/// Um exercício sem grupo muscular, com o grupo sugerido pelo nome.
class MissingGroupItem {
  const MissingGroupItem({
    required this.id,
    required this.name,
    this.subtitle,
    this.suggestion,
  });

  final String id;
  final String name;
  final String? subtitle;

  /// Grupo sugerido pelo nome (exercise_similarity), ou `null`.
  final String? suggestion;
}

/// Aviso "X exercícios sem grupo muscular" com botão para completar.
class MissingGroupsBanner extends StatelessWidget {
  const MissingGroupsBanner({
    super.key,
    required this.count,
    required this.onComplete,
  });

  final int count;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.amber.withValues(alpha: 0.15),
      child: ListTile(
        leading: Icon(
          Icons.warning_amber_rounded,
          color: Colors.amber.shade800,
        ),
        title: Text(
          count == 1
              ? '1 exercício sem grupo muscular'
              : '$count exercícios sem grupo muscular',
        ),
        subtitle: const Text('Eles ficam fora do mapa muscular.'),
        trailing: TextButton(
          onPressed: onComplete,
          child: const Text('Completar'),
        ),
      ),
    );
  }
}

/// Completar o grupo muscular de vários exercícios de uma vez, já com o
/// grupo sugerido pelo nome. [onSave] grava um exercício.
class CompleteMuscleGroupsScreen extends StatefulWidget {
  const CompleteMuscleGroupsScreen({
    super.key,
    required this.items,
    required this.onSave,
    this.extraOptions = const [],
  });

  final List<MissingGroupItem> items;
  final Future<void> Function(String id, String muscleGroup) onSave;

  /// Grupos além dos padrões (ex.: os da taxonomia do admin).
  final List<String> extraOptions;

  @override
  State<CompleteMuscleGroupsScreen> createState() =>
      _CompleteMuscleGroupsScreenState();
}

class _CompleteMuscleGroupsScreenState
    extends State<CompleteMuscleGroupsScreen> {
  late final Map<String, String?> _chosen = {
    for (final i in widget.items) i.id: i.suggestion,
  };
  bool _saving = false;

  List<String> get _options {
    final seen = <String>{};
    return [
      for (final g in [
        ...ownExerciseMuscleGroups,
        ...widget.extraOptions,
        for (final i in widget.items) ?i.suggestion,
      ])
        if (g.trim().isNotEmpty && seen.add(g.trim().toLowerCase())) g,
    ];
  }

  Future<void> _save() async {
    final ready = {
      for (final e in _chosen.entries)
        if (e.value != null) e.key: e.value!,
    };
    if (ready.isEmpty) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      for (final e in ready.entries) {
        await widget.onSave(e.key, e.value);
      }
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ready.length == 1
                ? '1 exercício completado. Ele já aparece no mapa.'
                : '${ready.length} exercícios completados. Eles já aparecem '
                      'no mapa.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Não foi possível salvar. Tente de novo.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _options;
    final ready = _chosen.values.where((v) => v != null).length;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Completar grupo muscular')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Escolha o grupo de cada exercício. Já deixamos sugerido o grupo '
            'do exercício mais parecido da biblioteca; confira antes de salvar.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          for (final item in widget.items)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (item.subtitle != null)
                      Text(
                        item.subtitle!,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: ValueKey('grupo-${item.id}'),
                      initialValue: _chosen[item.id],
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Grupo muscular',
                        helperText:
                            item.suggestion != null &&
                                _chosen[item.id] == item.suggestion
                            ? 'Sugerido pelo nome'
                            : null,
                      ),
                      items: [
                        for (final g in options)
                          DropdownMenuItem(value: g, child: Text(g)),
                      ],
                      onChanged: (g) => setState(() => _chosen[item.id] = g),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: ready == 0 || _saving ? null : _save,
            child: Text(
              _saving
                  ? 'Salvando...'
                  : ready == 1
                  ? 'Salvar 1 exercício'
                  : 'Salvar $ready exercícios',
            ),
          ),
        ),
      ),
    );
  }
}
