import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/app/routes/app_routes.dart';
import 'package:newfitness/features/exercises/logic/exercise_pool.dart';
import 'package:newfitness/features/exercises/presentation/exercise_alternatives_sheet.dart';
import 'package:newfitness/features/instructor/logic/plan_template_provider.dart';
import 'package:newfitness/features/workout/logic/progression/progression_rule.dart';
import 'package:newfitness/features/workout/logic/training_plan_provider.dart';
import 'package:newfitness/features/workout/presentation/workout_templates_screen.dart';
import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/models/plan_template.dart';
import 'package:newfitness/shared/models/training_plan.dart';
import 'package:newfitness/shared/models/workout_templates.dart';

/// Argumentos para `/instructor/student/plan`.
class PlanEditorArgs {
  const PlanEditorArgs({
    required this.studentUid,
    required this.studentName,
    required this.instructorUid,
    this.prefillInstructions,
    this.existingPlan,
  });

  final String studentUid;
  final String studentName;
  final String instructorUid;
  final String? prefillInstructions;

  /// Plano já salvo a editar — sem ele, a tela cria um plano novo.
  final TrainingPlan? existingPlan;
}

/// Rascunho de um sub-treino nomeado (ex: "Treino A") em edição na tela.
class _SubWorkoutDraft {
  _SubWorkoutDraft(String label)
    : labelCtrl = TextEditingController(text: label);

  final TextEditingController labelCtrl;
  final List<PlanExercise> exercises = [];

  /// Clona um sub-treino já salvo (de um modelo ou plano existente) — as
  /// listas de exercícios são copiadas, não compartilhadas, pra editar o
  /// rascunho não alterar o modelo original.
  factory _SubWorkoutDraft.from(TrainingSubWorkout source) {
    final draft = _SubWorkoutDraft(source.label);
    draft.exercises.addAll(source.exercises);
    return draft;
  }

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
  late final _existing = widget.args.existingPlan;
  late final _titleCtrl = TextEditingController(
    text: _existing?.title ?? 'Treino para ${widget.args.studentName}',
  );
  late final _instructionsCtrl = TextEditingController(
    text: _existing?.instructions ?? widget.args.prefillInstructions ?? '',
  );
  late final List<_SubWorkoutDraft> _subWorkouts =
      (_existing?.workouts.isNotEmpty ?? false)
      ? _existing!.workouts.map(_SubWorkoutDraft.from).toList()
      : [_SubWorkoutDraft(_nextSubWorkoutLabel(0))];
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

  /// Ajusta séries/reps/carga/descanso/observações de um exercício que já
  /// está no plano (antes só dava para trocar ou remover e adicionar de
  /// novo).
  Future<void> _editExercise(int subWorkoutIndex, int exerciseIndex) async {
    final current = _subWorkouts[subWorkoutIndex].exercises[exerciseIndex];
    final edited = await showModalBottomSheet<PlanExercise>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PlanExerciseFormSheet(
        exercise: Exercise(
          id: current.exerciseId,
          name: current.exerciseName,
          muscleGroup: '',
          equipment: '',
          description: '',
          videoUrl: '',
        ),
        initial: current,
      ),
    );
    if (edited != null && mounted) {
      setState(
        () => _subWorkouts[subWorkoutIndex].exercises[exerciseIndex] = edited,
      );
    }
  }

  Future<void> _swapExercise(int subWorkoutIndex, int exerciseIndex) async {
    final planExercise = _subWorkouts[subWorkoutIndex].exercises[exerciseIndex];
    final pool = await loadExercisePool(context);
    if (!mounted) return;
    final current = pool.firstWhere(
      (e) => e.id == planExercise.exerciseId,
      orElse: () => Exercise(
        id: planExercise.exerciseId,
        name: planExercise.exerciseName,
        muscleGroup: '',
        equipment: '',
        description: '',
        videoUrl: '',
      ),
    );
    final chosen = await showExerciseAlternativesSheet(
      context,
      current: current,
      pool: pool,
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _subWorkouts[subWorkoutIndex].exercises[exerciseIndex] = planExercise
          .copyWith(
            exerciseId: chosen.id,
            exerciseName: chosen.name,
            replacedExerciseId:
                planExercise.replacedExerciseId ?? planExercise.exerciseId,
            replacedExerciseName:
                planExercise.replacedExerciseName ?? planExercise.exerciseName,
          );
    });
  }

  Future<void> _useTemplate() async {
    final template = await showModalBottomSheet<PlanTemplate>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _TemplatePickerSheet(instructorUid: widget.args.instructorUid),
    );
    if (template == null || !mounted) return;

    if (_subWorkouts.any((d) => d.exercises.isNotEmpty)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Substituir treinos atuais?'),
          content: const Text(
            'O modelo escolhido vai substituir os treinos já montados '
            'nesta tela.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Substituir'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() {
      for (final d in _subWorkouts) {
        d.dispose();
      }
      _subWorkouts
        ..clear()
        ..addAll(template.workouts.map(_SubWorkoutDraft.from));
      if (_subWorkouts.isEmpty) {
        _subWorkouts.add(_SubWorkoutDraft(_nextSubWorkoutLabel(0)));
      }
      if (template.instructions != null && template.instructions!.isNotEmpty) {
        _instructionsCtrl.text = template.instructions!;
      }
    });
  }

  Future<void> _saveAsTemplate() async {
    final hasAnyExercise = _subWorkouts.any((d) => d.exercises.isNotEmpty);
    if (!hasAnyExercise) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adicione ao menos um exercício antes de salvar.'),
        ),
      );
      return;
    }

    final titleCtrl = TextEditingController(
      text: _titleCtrl.text.trim().isEmpty
          ? 'Modelo de treino'
          : _titleCtrl.text.trim(),
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Salvar como modelo'),
        content: TextField(
          controller: titleCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome do modelo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final template = PlanTemplate(
      id: '',
      instructorUid: widget.args.instructorUid,
      title: titleCtrl.text.trim().isEmpty
          ? 'Modelo de treino'
          : titleCtrl.text.trim(),
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
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<PlanTemplateProvider>().saveTemplate(template);
      messenger.showSnackBar(const SnackBar(content: Text('Modelo salvo')));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Não foi possível salvar o modelo.')),
      );
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
      id: _existing?.id ?? '',
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
      createdAt: _existing?.createdAt ?? DateTime.now(),
    );
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<TrainingPlanProvider>().savePlan(plan);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _existing == null ? 'Plano criado' : 'Plano atualizado',
          ),
        ),
      );
      if (mounted) context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível salvar o plano. Verifique a conexão e se o '
            'aluno ainda está vinculado a você.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _existing == null ? 'Novo plano de treino' : 'Editar plano de treino',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_outlined),
            tooltip: 'Usar modelo',
            onPressed: _useTemplate,
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_add_outlined),
            tooltip: 'Salvar como modelo',
            onPressed: _saveAsTemplate,
          ),
        ],
      ),
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
              onSwapExercise: (j) => _swapExercise(i, j),
              onEditExercise: (j) => _editExercise(i, j),
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
    required this.onSwapExercise,
    required this.onEditExercise,
    required this.onRemove,
  });

  final _SubWorkoutDraft draft;
  final bool canRemove;
  final VoidCallback onAddExercise;
  final ValueChanged<int> onRemoveExercise;
  final ValueChanged<int> onSwapExercise;
  final ValueChanged<int> onEditExercise;
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
                  onTap: () => onEditExercise(i),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.swap_horiz, size: 20),
                        tooltip: 'Trocar exercício',
                        onPressed: () => onSwapExercise(i),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => onRemoveExercise(i),
                      ),
                    ],
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
    final type = progressionTypeFromString(e.progressionType);
    if (type != null) {
      parts.add(
        type == ProgressionType.linear ? 'prog. linear' : 'prog. dupla',
      );
    }
    if (e.progressionIncrementKg != null) {
      final kg = e.progressionIncrementKg!;
      parts.add(
        '+${(kg % 1 == 0 ? kg.toStringAsFixed(0) : '$kg').replaceAll('.', ',')} kg',
      );
    }
    if (e.notes != null) parts.add(e.notes!);
    return parts.join(' · ');
  }
}

class _PlanExerciseFormSheet extends StatefulWidget {
  const _PlanExerciseFormSheet({required this.exercise, this.initial});

  final Exercise exercise;

  /// Prescrição atual, quando o instrutor está editando um exercício que
  /// já está no plano.
  final PlanExercise? initial;

  @override
  State<_PlanExerciseFormSheet> createState() => _PlanExerciseFormSheetState();
}

class _PlanExerciseFormSheetState extends State<_PlanExerciseFormSheet> {
  // Pré-preenchido com a prescrição padrão do exercício (ver
  // `Exercise.defaultSets` etc.), quando cadastrada — o instrutor ainda
  // pode ajustar livremente antes de confirmar.
  late final _setsCtrl = TextEditingController(
    text: '${widget.initial?.targetSets ?? widget.exercise.defaultSets ?? 3}',
  );
  late final _repsCtrl = TextEditingController(
    text:
        widget.initial?.targetReps ??
        (widget.exercise.defaultReps.isNotEmpty
            ? widget.exercise.defaultReps
            : '10-12'),
  );
  late final _weightsCtrl = TextEditingController(
    text:
        widget.initial?.targetWeightsKg ??
        (widget.exercise.defaultLoad != null
            ? _formatLoad(widget.exercise.defaultLoad!)
            : ''),
  );
  late final _restCtrl = TextEditingController(
    text:
        '${widget.initial?.restSeconds ?? widget.exercise.defaultRestSeconds ?? 60}',
  );
  late final _notesCtrl = TextEditingController(
    text: widget.initial?.notes ?? '',
  );

  // Regra de progressão: `null` = automática (pela faixa de reps).
  late ProgressionType? _progression = progressionTypeFromString(
    widget.initial?.progressionType,
  );
  late final _incrementCtrl = TextEditingController(
    text: _formatLoad(
      widget.initial?.progressionIncrementKg ??
          ProgressionRule.defaultIncrementKg,
    ).replaceAll('.', ','),
  );
  String? _incrementError;

  String _formatLoad(double load) =>
      load % 1 == 0 ? load.toStringAsFixed(0) : load.toString();

  @override
  void dispose() {
    _setsCtrl.dispose();
    _repsCtrl.dispose();
    _weightsCtrl.dispose();
    _restCtrl.dispose();
    _notesCtrl.dispose();
    _incrementCtrl.dispose();
    super.dispose();
  }

  String? _setsError;
  String? _restError;

  void _confirm() {
    // Valores inválidos NÃO são corrigidos automaticamente — o formulário
    // fica aberto mostrando o erro (antes "0", "-1", "25" ou vazio viravam
    // prescrição incoerente com as séries criadas no treino).
    final sets = int.tryParse(_setsCtrl.text.trim());
    final rest = int.tryParse(_restCtrl.text.trim());
    final increment = double.tryParse(
      _incrementCtrl.text.trim().replaceAll(',', '.'),
    );
    final setsError = validatePlanSets(sets);
    final restError = validatePlanRest(rest);
    final incrementError = validatePlanIncrement(increment);
    if (setsError != null || restError != null || incrementError != null) {
      setState(() {
        _setsError = setsError;
        _restError = restError;
        _incrementError = incrementError;
      });
      return;
    }
    Navigator.pop(
      context,
      PlanExercise(
        exerciseId: widget.exercise.id,
        exerciseName: widget.exercise.name,
        targetSets: sets!,
        targetReps: _repsCtrl.text.trim().isEmpty
            ? '10'
            : _repsCtrl.text.trim(),
        targetWeightsKg: _weightsCtrl.text.trim(),
        restSeconds: rest!,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        replacedExerciseId: widget.initial?.replacedExerciseId,
        replacedExerciseName: widget.initial?.replacedExerciseName,
        // Só grava o que o personal mudou: o resto segue o padrão.
        progressionType: _progression == null
            ? null
            : progressionTypeToString(_progression!),
        progressionIncrementKg: increment == ProgressionRule.defaultIncrementKg
            ? null
            : increment,
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
      child: SingleChildScrollView(child: _form(context)),
    );
  }

  Widget _form(BuildContext context) {
    return Column(
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
                decoration: InputDecoration(
                  labelText: 'Séries',
                  errorText: _setsError,
                  errorMaxLines: 2,
                ),
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
                decoration: InputDecoration(
                  labelText: 'Descanso (s)',
                  errorText: _restError,
                  errorMaxLines: 2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesCtrl,
          decoration: const InputDecoration(labelText: 'Observação (opcional)'),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<ProgressionType?>(
                key: const ValueKey('progression-type'),
                initialValue: _progression,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Progressão de carga',
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Automática (pelas reps)'),
                  ),
                  for (final type in ProgressionType.values)
                    DropdownMenuItem(
                      value: type,
                      child: Text(progressionTypeLabel(type)),
                    ),
                ],
                onChanged: (v) => setState(() => _progression = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextField(
                key: const ValueKey('progression-increment'),
                controller: _incrementCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Sobe (kg)',
                  errorText: _incrementError,
                  errorMaxLines: 2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'O app sugere a carga do aluno a cada treino com base nisso.',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _confirm,
          child: const Text('Adicionar ao plano'),
        ),
      ],
    );
  }
}

/// Incremento de carga da progressão: de 0,5 a 50 kg.
@visibleForTesting
String? validatePlanIncrement(double? kg) {
  if (kg == null) return 'Informe um número.';
  if (kg < 0.5 || kg > 50) return 'Entre 0,5 e 50 kg.';
  return null;
}

/// Séries prescritas: inteiro de 1 a 20 (o treino cria no máximo 20
/// linhas). Devolve a mensagem de erro, ou `null` se válido.
@visibleForTesting
String? validatePlanSets(int? sets) {
  if (sets == null) return 'Informe um número inteiro.';
  if (sets < 1 || sets > 20) return 'Entre 1 e 20 séries.';
  return null;
}

/// Descanso em segundos: inteiro ≥ 0.
@visibleForTesting
String? validatePlanRest(int? restSeconds) {
  if (restSeconds == null) return 'Informe um número inteiro.';
  if (restSeconds < 0) return 'Não pode ser negativo.';
  return null;
}

/// Bottom sheet com a lista de modelos salvos pelo instrutor — usado por
/// [PlanEditorScreen._useTemplate] pra escolher um pra clonar no plano atual.
/// Converte um treino pronto do app num modelo do personal, levando o
/// aquecimento e a progressão para as instruções do plano.
@visibleForTesting
PlanTemplate planTemplateFromReady(
  WorkoutTemplate ready,
  String instructorUid,
) => PlanTemplate(
  id: '$templatePlanPrefix${ready.id}',
  instructorUid: instructorUid,
  title: ready.title,
  instructions: [
    'Aquecimento: ${ready.warmUp.join(' ')}',
    'Como progredir: ${ready.progression}',
    if (ready.safetyNote != null) 'Atenção: ${ready.safetyNote}',
  ].join('\n\n'),
  workouts: ready.workouts,
  createdAt: DateTime.now(),
);

class _PickerHeader extends StatelessWidget {
  const _PickerHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 8),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
  );
}

class _TemplatePickerSheet extends StatelessWidget {
  const _TemplatePickerSheet({required this.instructorUid});

  final String instructorUid;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlanTemplateProvider>();

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Escolha um modelo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<PlanTemplate>>(
                stream: provider.watchTemplates(instructorUid),
                builder: (context, snapshot) {
                  final templates = snapshot.data ?? [];
                  final waiting =
                      snapshot.connectionState == ConnectionState.waiting;
                  final muted = TextStyle(color: Colors.grey.shade600);

                  Widget tile(PlanTemplate template, {String? subtitle}) {
                    final exerciseCount = template.workouts.fold<int>(
                      0,
                      (sum, w) => sum + w.exercises.length,
                    );
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.fitness_center),
                        title: Text(template.title),
                        subtitle: Text(
                          subtitle ??
                              '${template.workouts.length} treino(s) · '
                                  '$exerciseCount exercício(s)',
                        ),
                        onTap: () => Navigator.pop(context, template),
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      const _PickerHeader('Seus modelos'),
                      if (waiting)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (templates.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Nenhum modelo salvo ainda.',
                            style: muted,
                          ),
                        )
                      else
                        for (final template in templates) tile(template),
                      const _PickerHeader('Treinos prontos do NewFitness'),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Ponto de partida: ajuste séries, cargas e '
                          'exercícios ao aluno antes de salvar.',
                          style: muted,
                        ),
                      ),
                      for (final ready in workoutTemplates)
                        tile(
                          planTemplateFromReady(ready, instructorUid),
                          subtitle: templateFacts(ready),
                        ),
                    ],
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
