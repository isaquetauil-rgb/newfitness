import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/features/exercises/logic/exercise_provider.dart';
import 'package:newfitness/features/instructor/logic/instructor_ai_provider.dart';
import 'package:newfitness/features/workout/logic/training_plan_provider.dart';
import 'package:newfitness/shared/models/exercise_suggestion.dart';
import 'package:newfitness/shared/models/training_plan.dart';

/// Bottom sheet do assistente de IA para instrutores — reutilizado em dois
/// contextos:
///  - Geral (a partir do dashboard): [studentName]/[studentUid] são null,
///    cobre pedidos tipo "me dê mais ideias de treino de braço"; as
///    sugestões só podem virar um plano novo (via [onCreatePlan]).
///  - Por aluno (a partir do detalhe do aluno): [studentName], [studentUid]
///    e [instructorUid] vêm preenchidos, cobrindo o caso "Dona Maria está
///    com dor nas costas" — cada sugestão ganha um botão "Usar no plano"
///    que adiciona (ou substitui) o exercício direto num sub-treino já
///    existente daquela aluna, além da opção de criar um plano novo.
Future<void> showAiSuggestionSheet(
  BuildContext context, {
  String? studentName,
  String? studentUid,
  String? instructorUid,
  String? initialContext,
  void Function(String suggestion)? onCreatePlan,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => AiSuggestionSheet(
      studentName: studentName,
      studentUid: studentUid,
      instructorUid: instructorUid,
      initialContext: initialContext,
      onCreatePlan: onCreatePlan,
    ),
  );
}

class AiSuggestionSheet extends StatefulWidget {
  const AiSuggestionSheet({
    super.key,
    this.studentName,
    this.studentUid,
    this.instructorUid,
    this.initialContext,
    this.onCreatePlan,
  });

  final String? studentName;
  final String? studentUid;
  final String? instructorUid;
  final String? initialContext;
  final void Function(String suggestion)? onCreatePlan;

  @override
  State<AiSuggestionSheet> createState() => _AiSuggestionSheetState();
}

class _AiSuggestionSheetState extends State<AiSuggestionSheet> {
  late final _controller = TextEditingController(
    text: widget.initialContext ?? '',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InstructorAiProvider>().reset();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    await context.read<InstructorAiProvider>().ask(
      prompt: _controller.text,
      studentUid: widget.studentUid,
    );
  }

  String _composeInstructions(List<ExerciseSuggestion> suggestions) {
    return suggestions
        .map(
          (s) =>
              '- ${s.exerciseName}: ${s.sets}x${s.reps}, '
              '${s.restSeconds}s descanso'
              '${s.reason.isNotEmpty ? ' — ${s.reason}' : ''}',
        )
        .join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<InstructorAiProvider>();
    final isForStudent = widget.studentName != null;
    final canEditPlan =
        widget.studentUid != null && widget.instructorUid != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.smart_toy_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isForStudent
                        ? 'Sugestão de IA para ${widget.studentName}'
                        : 'Assistente de IA',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: isForStudent
                    ? 'Ex: dor nas costas, quer focar em pernas, iniciante...'
                    : 'Ex: me dê mais ideias de treino de braço',
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: ai.isLoading ? null : _ask,
              icon: ai.isLoading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send),
              label: const Text('Perguntar à IA'),
            ),
            if (ai.error != null) ...[
              const SizedBox(height: 12),
              Text(ai.error!, style: const TextStyle(color: Colors.red)),
            ],
            if (ai.suggestions.isNotEmpty) ...[
              const SizedBox(height: 16),
              for (final suggestion in ai.suggestions)
                _SuggestionCard(
                  suggestion: suggestion,
                  onUseInPlan: canEditPlan
                      ? () => _openUseInPlanSheet(context, suggestion)
                      : null,
                ),
              if (widget.onCreatePlan != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    final instructions = _composeInstructions(ai.suggestions);
                    Navigator.pop(context);
                    widget.onCreatePlan!(instructions);
                  },
                  icon: const Icon(Icons.assignment_add),
                  label: const Text('Criar plano novo com estas sugestões'),
                ),
              ],
            ] else if (ai.rawText != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(ai.rawText!),
              ),
              if (widget.onCreatePlan != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onCreatePlan!(ai.rawText!);
                  },
                  icon: const Icon(Icons.assignment_add),
                  label: const Text('Criar plano com esta sugestão'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _openUseInPlanSheet(
    BuildContext context,
    ExerciseSuggestion suggestion,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _UseInPlanSheet(
        suggestion: suggestion,
        studentUid: widget.studentUid!,
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.suggestion, this.onUseInPlan});

  final ExerciseSuggestion suggestion;
  final VoidCallback? onUseInPlan;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              suggestion.exerciseName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${suggestion.sets}x${suggestion.reps} · '
              '${suggestion.restSeconds}s descanso',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            if (suggestion.reason.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(suggestion.reason, style: const TextStyle(fontSize: 13)),
            ],
            if (onUseInPlan != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onUseInPlan,
                  icon: const Icon(Icons.playlist_add, size: 18),
                  label: const Text('Usar no plano'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Escolhe em qual plano/sub-treino do aluno a sugestão entra — adicionada
/// como exercício novo, ou substituindo um já existente.
class _UseInPlanSheet extends StatefulWidget {
  const _UseInPlanSheet({required this.suggestion, required this.studentUid});

  final ExerciseSuggestion suggestion;
  final String studentUid;

  @override
  State<_UseInPlanSheet> createState() => _UseInPlanSheetState();
}

class _UseInPlanSheetState extends State<_UseInPlanSheet> {
  // Guarda só o ID: cada snapshot do Firestore traz objetos
  // [TrainingPlan] novos, e comparar por instância quebrava o dropdown
  // ("There should be exactly one item with value") a cada atualização.
  String? _selectedPlanId;
  TrainingPlan? _selectedPlan;
  int? _subWorkoutIndex;
  int? _replaceExerciseIndex; // null = adicionar como novo
  bool _saving = false;

  // Criado uma vez: recriar a cada setState (escolher plano/sub-treino,
  // salvar) reabria a consulta e trocava o formulário pelo spinner.
  late final Stream<List<TrainingPlan>> _plansStream = context
      .read<TrainingPlanProvider>()
      .watchPlans(widget.studentUid);

  PlanExercise _buildPlanExercise(BuildContext context) {
    final s = widget.suggestion;
    final library = context.read<ExerciseProvider>().exercises;
    final normalized = s.exerciseName.trim().toLowerCase();
    final match = library.where(
      (e) => e.name.trim().toLowerCase() == normalized,
    );
    final matchedId = match.isNotEmpty ? match.first.id : '';

    return PlanExercise(
      exerciseId: matchedId,
      exerciseName: s.exerciseName,
      targetSets: s.sets,
      targetReps: s.reps,
      restSeconds: s.restSeconds,
      notes: s.reason.isEmpty ? null : s.reason,
    );
  }

  Future<void> _confirm() async {
    final plan = _selectedPlan;
    final subIndex = _subWorkoutIndex;
    if (plan == null || subIndex == null) return;

    setState(() => _saving = true);
    final newExercise = _buildPlanExercise(context);
    final updatedWorkouts = [
      for (int i = 0; i < plan.workouts.length; i++)
        if (i != subIndex)
          plan.workouts[i]
        else
          TrainingSubWorkout(
            label: plan.workouts[i].label,
            exercises: [
              for (int j = 0; j < plan.workouts[i].exercises.length; j++)
                if (j == _replaceExerciseIndex)
                  newExercise
                else
                  plan.workouts[i].exercises[j],
              if (_replaceExerciseIndex == null) newExercise,
            ],
          ),
    ];

    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<TrainingPlanProvider>().savePlan(
        TrainingPlan(
          id: plan.id,
          studentUid: plan.studentUid,
          instructorUid: plan.instructorUid,
          title: plan.title,
          instructions: plan.instructions,
          workouts: updatedWorkouts,
          createdAt: plan.createdAt,
        ),
      );
      if (mounted) Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text('${newExercise.exerciseName} adicionado ao plano'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Não foi possível atualizar o plano.')),
      );
    }
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
      child: StreamBuilder<List<TrainingPlan>>(
        stream: _plansStream,
        builder: (context, snapshot) {
          final plans = snapshot.data ?? [];
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Não foi possível carregar os planos deste aluno.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (plans.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Este aluno ainda não tem nenhum plano. Crie um plano '
                'primeiro para poder adicionar exercícios sugeridos a ele.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            );
          }

          // Sempre a instância do snapshot ATUAL (o dropdown compara por
          // identidade); se o plano escolhido sumiu, volta para o primeiro.
          _selectedPlan = plans.firstWhere(
            (p) => p.id == _selectedPlanId,
            orElse: () => plans.first,
          );
          _selectedPlanId = _selectedPlan!.id;
          final subWorkouts = _selectedPlan!.workouts;

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Adicionar "${widget.suggestion.exerciseName}"',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<TrainingPlan>(
                  initialValue: _selectedPlan,
                  decoration: const InputDecoration(labelText: 'Plano'),
                  items: [
                    for (final plan in plans)
                      DropdownMenuItem(value: plan, child: Text(plan.title)),
                  ],
                  onChanged: (value) => setState(() {
                    _selectedPlanId = value?.id;
                    _selectedPlan = value;
                    _subWorkoutIndex = null;
                    _replaceExerciseIndex = null;
                  }),
                ),
                const SizedBox(height: 12),
                if (subWorkouts.isEmpty)
                  Text(
                    'Este plano ainda não tem sub-treinos.',
                    style: TextStyle(color: Colors.grey.shade600),
                  )
                else ...[
                  DropdownButtonFormField<int>(
                    initialValue: _subWorkoutIndex,
                    decoration: const InputDecoration(labelText: 'Sub-treino'),
                    items: [
                      for (int i = 0; i < subWorkouts.length; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(subWorkouts[i].label),
                        ),
                    ],
                    onChanged: (value) => setState(() {
                      _subWorkoutIndex = value;
                      _replaceExerciseIndex = null;
                    }),
                  ),
                  if (_subWorkoutIndex != null &&
                      subWorkouts[_subWorkoutIndex!].exercises.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int?>(
                      initialValue: _replaceExerciseIndex,
                      decoration: const InputDecoration(
                        labelText: 'Adicionar como novo ou substituir',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Adicionar como novo exercício'),
                        ),
                        for (
                          int j = 0;
                          j < subWorkouts[_subWorkoutIndex!].exercises.length;
                          j++
                        )
                          DropdownMenuItem(
                            value: j,
                            child: Text(
                              'Substituir: '
                              '${subWorkouts[_subWorkoutIndex!].exercises[j].exerciseName}',
                            ),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _replaceExerciseIndex = value),
                    ),
                  ],
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: (_subWorkoutIndex == null || _saving)
                      ? null
                      : _confirm,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Confirmar'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
