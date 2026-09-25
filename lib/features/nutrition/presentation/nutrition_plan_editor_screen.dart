import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:newfitness/features/nutrition/logic/nutrition_plan_provider.dart';
import 'package:newfitness/shared/models/nutrition_plan.dart';

const _uuid = Uuid();

class NutritionPlanEditorArgs {
  const NutritionPlanEditorArgs({
    required this.studentUid,
    required this.studentName,
    required this.nutritionistUid,
    this.existing,
  });

  final String studentUid;
  final String studentName;
  final String nutritionistUid;
  final NutritionPlan? existing;
}

/// Formulário da nutricionista pra montar/editar o plano alimentar de um
/// aluno — mais simples que `PlanEditorScreen` (refeições não têm
/// séries/reps, só uma descrição livre).
class NutritionPlanEditorScreen extends StatefulWidget {
  const NutritionPlanEditorScreen({super.key, required this.args});

  final NutritionPlanEditorArgs args;

  @override
  State<NutritionPlanEditorScreen> createState() =>
      _NutritionPlanEditorScreenState();
}

class _MealDraft {
  _MealDraft({String? label, String? description, String? suggestedTime})
    : labelCtrl = TextEditingController(text: label ?? ''),
      descriptionCtrl = TextEditingController(text: description ?? ''),
      timeCtrl = TextEditingController(text: suggestedTime ?? '');

  final TextEditingController labelCtrl;
  final TextEditingController descriptionCtrl;
  final TextEditingController timeCtrl;

  void dispose() {
    labelCtrl.dispose();
    descriptionCtrl.dispose();
    timeCtrl.dispose();
  }
}

class _NutritionPlanEditorScreenState extends State<NutritionPlanEditorScreen> {
  late final _titleCtrl = TextEditingController(
    text: widget.args.existing?.title ?? '',
  );
  late final _instructionsCtrl = TextEditingController(
    text: widget.args.existing?.instructions ?? '',
  );
  late final List<_MealDraft> _meals =
      widget.args.existing?.meals.isNotEmpty == true
      ? widget.args.existing!.meals
            .map(
              (m) => _MealDraft(
                label: m.label,
                description: m.description,
                suggestedTime: m.suggestedTime,
              ),
            )
            .toList()
      : [_MealDraft()];
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _instructionsCtrl.dispose();
    for (final meal in _meals) {
      meal.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Dê um título ao plano.')));
      return;
    }
    setState(() => _saving = true);
    final plan = NutritionPlan(
      id: widget.args.existing?.id ?? _uuid.v4(),
      studentUid: widget.args.studentUid,
      nutritionistUid: widget.args.nutritionistUid,
      title: _titleCtrl.text.trim(),
      instructions: _instructionsCtrl.text.trim().isEmpty
          ? null
          : _instructionsCtrl.text.trim(),
      meals: _meals
          .where((m) => m.labelCtrl.text.trim().isNotEmpty)
          .map(
            (m) => NutritionMeal(
              label: m.labelCtrl.text.trim(),
              description: m.descriptionCtrl.text.trim(),
              suggestedTime: m.timeCtrl.text.trim().isEmpty
                  ? null
                  : m.timeCtrl.text.trim(),
            ),
          )
          .toList(),
      createdAt: widget.args.existing?.createdAt ?? DateTime.now(),
    );
    await context.read<NutritionPlanProvider>().savePlan(plan);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Plano de ${widget.args.studentName}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Título do plano'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _instructionsCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Orientações gerais (opcional)',
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Refeições',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (int i = 0; i < _meals.length; i++)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _meals[i].labelCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Ex: Café da manhã',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 90,
                          child: TextField(
                            controller: _meals[i].timeCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Horário',
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: _meals.length == 1
                              ? null
                              : () => setState(() {
                                  _meals.removeAt(i).dispose();
                                }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _meals[i].descriptionCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'O que comer',
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: () => setState(() => _meals.add(_MealDraft())),
            icon: const Icon(Icons.add),
            label: const Text('Adicionar refeição'),
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
