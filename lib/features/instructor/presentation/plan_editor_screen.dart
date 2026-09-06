import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/app/routes/app_routes.dart';
import 'package:newfitness/features/workout/logic/training_plan_provider.dart';
import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/models/training_plan.dart';

/// Argumentos para `/instructor/student/plan`.
class PlanEditorArgs {
  const PlanEditorArgs({
    required this.studentUid,
    required this.studentName,
    required this.instructorUid,
    this.prefillInstructions,
  });

  final String studentUid;
  final String studentName;
  final String instructorUid;
  final String? prefillInstructions;
}

/// Tela onde o instrutor monta um [TrainingPlan] para um aluno: título,
/// instruções livres (pode vir pré-preenchido de uma sugestão de IA) e uma
/// lista de exercícios com séries/reps-alvo, escolhidos na biblioteca via
/// o [ExercisePickerScreen] já existente (reaproveitado por rota).
class PlanEditorScreen extends StatefulWidget {
  const PlanEditorScreen({super.key, required this.args});

  final PlanEditorArgs args;

  @override
  State<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends State<PlanEditorScreen> {
  late final _titleCtrl = TextEditingController(
    text: 'Treino para ${widget.args.studentName}',
  );
  late final _instructionsCtrl = TextEditingController(
    text: widget.args.prefillInstructions ?? '',
  );
  final List<PlanExercise> _exercises = [];
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _addExercise() async {
    final exercise = await context.push<Exercise>(
      AppRoutes.workoutExercisePicker,
    );
    if (exercise == null || !mounted) return;

    final planExercise = await showModalBottomSheet<PlanExercise>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PlanExerciseFormSheet(exercise: exercise),
    );
    if (planExercise != null && mounted) {
      setState(() => _exercises.add(planExercise));
    }
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty || _exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dê um título e adicione ao menos um exercício.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final plan = TrainingPlan(
      id: '',
      studentUid: widget.args.studentUid,
      instructorUid: widget.args.instructorUid,
      title: _titleCtrl.text.trim(),
      instructions: _instructionsCtrl.text.trim().isEmpty
          ? null
          : _instructionsCtrl.text.trim(),
      exercises: _exercises,
      createdAt: DateTime.now(),
    );
    await context.read<TrainingPlanProvider>().savePlan(plan);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo plano de treino')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Título do plano'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _instructionsCtrl,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Instruções (opcional)',
              hintText: 'Orientações gerais para o aluno seguir o plano...',
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Text(
                'Exercícios',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _addExercise,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Adicionar'),
              ),
            ],
          ),
          if (_exercises.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Nenhum exercício adicionado ainda.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            )
          else
            for (int i = 0; i < _exercises.length; i++)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(_exercises[i].exerciseName),
                  subtitle: Text(
                    '${_exercises[i].targetSets}x${_exercises[i].targetReps}'
                    '${_exercises[i].notes != null ? ' · ${_exercises[i].notes}' : ''}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => setState(() => _exercises.removeAt(i)),
                  ),
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
                : const Text('Salvar plano'),
          ),
        ],
      ),
    );
  }
}

class _PlanExerciseFormSheet extends StatefulWidget {
  const _PlanExerciseFormSheet({required this.exercise});

  final Exercise exercise;

  @override
  State<_PlanExerciseFormSheet> createState() => _PlanExerciseFormSheetState();
}

class _PlanExerciseFormSheetState extends State<_PlanExerciseFormSheet> {
  final _setsCtrl = TextEditingController(text: '3');
  final _repsCtrl = TextEditingController(text: '10-12');
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _setsCtrl.dispose();
    _repsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final sets = int.tryParse(_setsCtrl.text) ?? 3;
    Navigator.pop(
      context,
      PlanExercise(
        exerciseId: widget.exercise.id,
        exerciseName: widget.exercise.name,
        targetSets: sets,
        targetReps: _repsCtrl.text.trim().isEmpty
            ? '10'
            : _repsCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.exercise.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _setsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Séries'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _repsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Reps (ex: 10-12)',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            decoration: const InputDecoration(
              labelText: 'Observação (opcional)',
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _confirm,
            child: const Text('Adicionar ao plano'),
          ),
        ],
      ),
    );
  }
}
