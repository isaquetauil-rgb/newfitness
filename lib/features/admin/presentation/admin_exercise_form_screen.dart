import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:newfitness/features/admin/logic/admin_provider.dart';
import 'package:newfitness/features/exercises/logic/exercise_provider.dart';
import 'package:newfitness/features/exercises/logic/exercise_taxonomy_provider.dart';
import 'package:newfitness/features/exercises/presentation/exercise_form_controller.dart';
import 'package:newfitness/features/exercises/presentation/exercise_form_fields.dart';
import 'package:newfitness/shared/models/exercise.dart';

const _uuid = Uuid();

/// Formulário de criar/editar um exercício da biblioteca global. Passe um
/// [existing] (via `extra` na rota) para editar; deixe null para criar um
/// novo. Os campos compartilhados com o formulário do instrutor
/// (`CustomExerciseFormScreen`) vivem em `ExerciseFormFields` — aqui só o
/// vídeo (link do YouTube, sem upload próprio) e o destino do salvamento
/// (`AdminProvider`, biblioteca global) são específicos.
class AdminExerciseFormScreen extends StatefulWidget {
  const AdminExerciseFormScreen({super.key, this.existing});

  final Exercise? existing;

  @override
  State<AdminExerciseFormScreen> createState() =>
      _AdminExerciseFormScreenState();
}

class _AdminExerciseFormScreenState extends State<AdminExerciseFormScreen> {
  late final _form = ExerciseFormController(widget.existing);
  late final _videoUrlCtrl = TextEditingController(
    text: widget.existing?.videoUrl ?? '',
  );
  bool _saving = false;

  @override
  void dispose() {
    _form.dispose();
    _videoUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.isValid) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Dê um nome ao exercício.')));
      return;
    }
    setState(() => _saving = true);
    final exercise = _form.buildExercise(
      id: widget.existing?.id ?? _uuid.v4(),
      videoUrl: _videoUrlCtrl.text.trim(),
    );
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AdminProvider>().saveExercise(exercise);
      messenger.showSnackBar(const SnackBar(content: Text('Exercício salvo')));
      if (mounted) context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Não foi possível salvar o exercício.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final allExercises = context.watch<ExerciseProvider>().exercises;
    final taxonomy = context.watch<ExerciseTaxonomyProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? 'Novo exercício' : 'Editar exercício',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ExerciseFormFields(
            controller: _form,
            allExercises: allExercises,
            muscleGroupOptions: [for (final g in taxonomy.muscleGroups) g.name],
            equipmentOptions: [for (final e in taxonomy.equipment) e.name],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _videoUrlCtrl,
            decoration: const InputDecoration(
              labelText: 'URL do vídeo (YouTube)',
              hintText: 'https://www.youtube.com/watch?v=...',
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
