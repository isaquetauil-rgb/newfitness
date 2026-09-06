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

/// Rascunho de um sub-treino nomeado (ex: "Treino A") em edição na tela.
class _SubWorkoutDraft {
  _SubWorkoutDraft(String label)
    : labelCtrl = TextEditingController(text: label);

  final TextEditingController labelCtrl;
  final List<PlanExercise> exercises = [];

  void dispose() => labelCtrl.dispose();
}

String _nextSubWorkoutLabel(int index) {
  // A, B, C... depois AA, AB... (suficiente pra qualquer plano razoável)
  final letter = String.fromCharCode('A'.codeUnitAt(0) + (index % 26));
  final prefix = index >= 26 ? '${index ~/ 26}' : '';
  return 'Treino $prefix$letter';
}

/// Tela onde o instrutor monta um [TrainingPlan] para um aluno: título,
/// instruções livres (pode vir pré-preenchido de uma sugestão de IA) e um ou
/// mais sub-treinos nomeados (Treino A/B/C...), cada um com sua lista de
/// exercícios (escolhidos na biblioteca via o [ExercisePickerScreen] já
/// existente, reaproveitado por rota) com séries/reps/peso/descanso-alvo.
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
  final List<_SubWorkoutDraft> _subWorkouts = [
    _SubWorkoutDraft(_nextSubWorkoutLabel(0)),
  ];
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _instructionsCtrl.dispose();
    for (final d in _subWorkouts) {
      d.dispose();
    }
    super.dispose();
  }

  void _addSubWorkout() {
    setState(
      () => _subWorkouts.add(
        _SubWorkoutDraft(_nextSubWorkoutLabel(_subWorkouts.length)),
      ),
    );
  }

  void _removeSubWorkout(int index) {
    setState(() => _subWorkouts.removeAt(index).dispose());
  }

  Future<void> _addExercise(int subWorkoutIndex) async {
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
      setState(() => _subWorkouts[subWorkoutIndex].exercises.add(planExercise));
    }
  }

  Future<void> _save() async {
    final hasAnyExercise = _subWorkouts.any((d) => d.exercises.isNotEmpty);
    if (_titleCtrl.text.trim().isEmpty || !hasAnyExercise) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Dê um título e adicione ao menos um exercício em algum treino.',
          ),
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
      workouts: [
        for (final d in _subWorkouts)
          if (d.exercises.isNotEmpty)
            TrainingSubWorkout(
              label: d.labelCtrl.text.trim().isEmpty
                  ? 'Treino'
                  : d.labelCtrl.text.trim(),
              exercises: d.exercises,
            ),
      ],
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
          for (int i = 0; i < _subWorkouts.length; i++)
            _SubWorkoutEditor(
              draft: _subWorkouts[i],
              canRemove: _subWorkouts.length > 1,
              onAddExercise: () => _addExercise(i),
              onRemoveExercise: (j) =>
                  setState(() => _subWorkouts[i].exercises.removeAt(j)),
              onRemove: () => _removeSubWorkout(i),
            ),
          OutlinedButton.icon(
            onPressed: _addSubWorkout,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Adicionar outro treino (B, C...)'),
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

class _SubWorkoutEditor extends StatelessWidget {
  const _SubWorkoutEditor({
    required this.draft,
    required this.canRemove,
    required this.onAddExercise,
    required this.onRemoveExercise,
    required this.onRemove,
  });

  final _SubWorkoutDraft draft;
  final bool canRemove;
  final VoidCallback onAddExercise;
  final ValueChanged<int> onRemoveExercise;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: draft.labelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nome do treino',
                      isDense: true,
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (canRemove)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: onRemove,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (draft.exercises.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Nenhum exercício adicionado ainda.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              )
            else
              for (int i = 0; i < draft.exercises.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(draft.exercises[i].exerciseName),
                  subtitle: Text(_exerciseSummary(draft.exercises[i])),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => onRemoveExercise(i),
                  ),
                ),
            TextButton.icon(
              onPressed: onAddExercise,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Adicionar exercício'),
            ),
          ],
        ),
      ),
    );
  }

  String _exerciseSummary(PlanExercise e) {
    final parts = <String>['${e.targetSets}x${e.targetReps}'];
    if (e.targetWeightsKg.isNotEmpty) parts.add('${e.targetWeightsKg} kg');
    parts.add('${e.restSeconds}s descanso');
    if (e.notes != null) parts.add(e.notes!);
    return parts.join(' · ');
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
  final _weightsCtrl = TextEditingController();
  final _restCtrl = TextEditingController(text: '60');
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _setsCtrl.dispose();
    _repsCtrl.dispose();
    _weightsCtrl.dispose();
    _restCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final sets = int.tryParse(_setsCtrl.text) ?? 3;
    final rest = int.tryParse(_restCtrl.text) ?? 60;
    Navigator.pop(
      context,
      PlanExercise(
        exerciseId: widget.exercise.id,
        exerciseName: widget.exercise.name,
        targetSets: sets,
        targetReps: _repsCtrl.text.trim().isEmpty
            ? '10'
            : _repsCtrl.text.trim(),
        targetWeightsKg: _weightsCtrl.text.trim(),
        restSeconds: rest,
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
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _weightsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Peso por série (ex: 40/50/60)',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _restCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Descanso (s)'),
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
