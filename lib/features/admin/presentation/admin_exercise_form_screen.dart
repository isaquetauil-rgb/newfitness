import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:newfitness/features/admin/logic/admin_provider.dart';
import 'package:newfitness/shared/models/exercise.dart';

const _uuid = Uuid();

/// Formulário de criar/editar um exercício da biblioteca. Passe um
/// [existing] (via `extra` na rota) para editar; deixe null para criar um
/// novo.
class AdminExerciseFormScreen extends StatefulWidget {
  const AdminExerciseFormScreen({super.key, this.existing});

  final Exercise? existing;

  @override
  State<AdminExerciseFormScreen> createState() =>
      _AdminExerciseFormScreenState();
}

class _AdminExerciseFormScreenState extends State<AdminExerciseFormScreen> {
  late final _nameCtrl = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final _muscleGroupCtrl = TextEditingController(
    text: widget.existing?.muscleGroup ?? '',
  );
  late final _equipmentCtrl = TextEditingController(
    text: widget.existing?.equipment ?? '',
  );
  late final _descriptionCtrl = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late final _videoUrlCtrl = TextEditingController(
    text: widget.existing?.videoUrl ?? '',
  );
  late final _instructionsCtrl = TextEditingController(
    text: widget.existing?.instructions.join('\n') ?? '',
  );
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _muscleGroupCtrl.dispose();
    _equipmentCtrl.dispose();
    _descriptionCtrl.dispose();
    _videoUrlCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Dê um nome ao exercício.')));
      return;
    }
    setState(() => _saving = true);
    final exercise = Exercise(
      id: widget.existing?.id ?? _uuid.v4(),
      name: _nameCtrl.text.trim(),
      muscleGroup: _muscleGroupCtrl.text.trim(),
      equipment: _equipmentCtrl.text.trim(),
      description: _descriptionCtrl.text.trim(),
      videoUrl: _videoUrlCtrl.text.trim(),
      instructions: _instructionsCtrl.text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
    );
    await context.read<AdminProvider>().saveExercise(exercise);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? 'Novo exercício' : 'Editar exercício',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Nome'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _muscleGroupCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Grupo muscular',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _equipmentCtrl,
                  decoration: const InputDecoration(labelText: 'Equipamento'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionCtrl,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Descrição'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _videoUrlCtrl,
            decoration: const InputDecoration(
              labelText: 'URL do vídeo (YouTube)',
              hintText: 'https://www.youtube.com/watch?v=...',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _instructionsCtrl,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Como executar (uma instrução por linha)',
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
