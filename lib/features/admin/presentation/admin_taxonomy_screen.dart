import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:newfitness/features/exercises/logic/exercise_taxonomy_provider.dart';
import 'package:newfitness/shared/models/equipment_item.dart';
import 'package:newfitness/shared/models/muscle_group.dart';

const _uuid = Uuid();

/// CRUD da taxonomia de referência (`muscle_groups`/`equipment`) — o que
/// permite adicionar um grupo muscular ou equipamento novo sem alterar o
/// código: assim que salvo aqui, aparece imediatamente nos formulários de
/// exercício (autocomplete) e nos filtros da biblioteca.
class AdminTaxonomyScreen extends StatefulWidget {
  const AdminTaxonomyScreen({super.key});

  @override
  State<AdminTaxonomyScreen> createState() => _AdminTaxonomyScreenState();
}

class _AdminTaxonomyScreenState extends State<AdminTaxonomyScreen>
    with SingleTickerProviderStateMixin {
  late final _controller = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _editMuscleGroup(MuscleGroup? existing) async {
    final result = await _showNameDialog(
      title: existing == null ? 'Novo grupo muscular' : 'Editar grupo muscular',
      initialName: existing?.name ?? '',
    );
    if (result == null || !mounted) return;
    await _guard(
      () => context.read<ExerciseTaxonomyProvider>().saveMuscleGroup(
        MuscleGroup(id: existing?.id ?? _uuid.v4(), name: result),
      ),
    );
  }

  /// Mostra um aviso se a gravação falhar (antes o erro era engolido e a
  /// lista simplesmente não mudava).
  Future<void> _guard(Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Não foi possível salvar a alteração.')),
      );
    }
  }

  Future<void> _editEquipment(EquipmentItem? existing) async {
    final result = await _showNameDialog(
      title: existing == null ? 'Novo equipamento' : 'Editar equipamento',
      initialName: existing?.name ?? '',
    );
    if (result == null || !mounted) return;
    await _guard(
      () => context.read<ExerciseTaxonomyProvider>().saveEquipment(
        EquipmentItem(id: existing?.id ?? _uuid.v4(), name: result),
      ),
    );
  }

  Future<String?> _showNameDialog({
    required String title,
    required String initialName,
  }) async {
    final ctrl = TextEditingController(text: initialName);
    try {
      return await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nome'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                final name = ctrl.text.trim();
                if (name.isNotEmpty) Navigator.pop(ctx, name);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      );
    } finally {
      ctrl.dispose();
    }
  }

  Future<void> _confirmDelete(String label, VoidCallback onConfirmed) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover?'),
        content: Text(
          '"$label" será removido da taxonomia. Exercícios que já usam esse '
          'valor continuam funcionando (o texto fica gravado neles), só '
          'deixa de aparecer como sugestão.',
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
    if (confirmed == true) onConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    final taxonomy = context.watch<ExerciseTaxonomyProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Taxonomia de exercícios'),
        bottom: TabBar(
          controller: _controller,
          tabs: const [
            Tab(text: 'Grupos musculares'),
            Tab(text: 'Equipamentos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _controller,
        children: [
          _TaxonomyList(
            items: [for (final g in taxonomy.muscleGroups) g.name],
            onAdd: () => _editMuscleGroup(null),
            onEdit: (i) => _editMuscleGroup(taxonomy.muscleGroups[i]),
            onDelete: (i) => _confirmDelete(
              taxonomy.muscleGroups[i].name,
              () => _guard(
                () => taxonomy.deleteMuscleGroup(taxonomy.muscleGroups[i].id),
              ),
            ),
          ),
          _TaxonomyList(
            items: [for (final e in taxonomy.equipment) e.name],
            onAdd: () => _editEquipment(null),
            onEdit: (i) => _editEquipment(taxonomy.equipment[i]),
            onDelete: (i) => _confirmDelete(
              taxonomy.equipment[i].name,
              () => _guard(
                () => taxonomy.deleteEquipment(taxonomy.equipment[i].id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaxonomyList extends StatelessWidget {
  const _TaxonomyList({
    required this.items,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final List<String> items;
  final VoidCallback onAdd;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: items.isEmpty
          ? const Center(child: Text('Nenhum item cadastrado ainda.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, i) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(items[i]),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => onEdit(i),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => onDelete(i),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: onAdd,
        child: const Icon(Icons.add),
      ),
    );
  }
}
