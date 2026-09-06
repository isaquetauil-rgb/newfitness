import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/app/routes/app_routes.dart';
import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/instructor/presentation/ai_suggestion_sheet.dart';
import 'package:newfitness/features/instructor/presentation/plan_editor_screen.dart';
import 'package:newfitness/features/workout/logic/training_plan_provider.dart';
import 'package:newfitness/shared/models/training_plan.dart';
import 'package:newfitness/shared/models/workout.dart';
import 'package:newfitness/shared/services/firestore_service.dart';

/// Visão do instrutor sobre um aluno: notas, assistente de IA, planos de
/// treino atribuídos e histórico de treinos executados.
///
/// Importante: para isso funcionar, as regras do Firestore precisam
/// permitir que o instrutor leia a subcoleção `workouts` do aluno vinculado
/// (veja README.md, seção de regras de segurança).
class StudentDetailScreen extends StatefulWidget {
  final String studentUid;
  final String studentName;
  final String? initialNotes;

  const StudentDetailScreen({
    super.key,
    required this.studentUid,
    required this.studentName,
    this.initialNotes,
  });

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  final _firestoreService = getIt<FirestoreService>();
  late final _notesCtrl = TextEditingController(
    text: widget.initialNotes ?? '',
  );
  bool _savingNotes = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveNotes(String instructorUid) async {
    setState(() => _savingNotes = true);
    final messenger = ScaffoldMessenger.of(context);
    await _firestoreService.updateStudentNote(
      instructorUid,
      widget.studentUid,
      _notesCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _savingNotes = false);
    messenger.showSnackBar(const SnackBar(content: Text('Nota salva')));
  }

  void _openAiSheet(String instructorUid) {
    showAiSuggestionSheet(
      context,
      studentName: widget.studentName,
      initialContext: _notesCtrl.text,
      onCreatePlan: (suggestion) =>
          _openPlanEditor(instructorUid, prefill: suggestion),
    );
  }

  void _openPlanEditor(String instructorUid, {String? prefill}) {
    context.push(
      AppRoutes.instructorPlanEditor,
      extra: PlanEditorArgs(
        studentUid: widget.studentUid,
        studentName: widget.studentName,
        instructorUid: instructorUid,
        prefillInstructions: prefill,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final instructorUid = context.read<AuthProvider>().user?.uid ?? '';
    final planProvider = context.watch<TrainingPlanProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(widget.studentName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Notas sobre o aluno',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesCtrl,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Ex: dor lombar crônica, quer focar em pernas...',
              suffixIcon: IconButton(
                icon: _savingNotes
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                onPressed: _savingNotes
                    ? null
                    : () => _saveNotes(instructorUid),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _openAiSheet(instructorUid),
            icon: const Icon(Icons.smart_toy_outlined),
            label: const Text('Pedir sugestão de treino com IA'),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              const Text(
                'Planos deste aluno',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _openPlanEditor(instructorUid),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Novo plano'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          StreamBuilder<List<TrainingPlan>>(
            stream: planProvider.watchPlans(widget.studentUid),
            builder: (context, snapshot) {
              final plans = snapshot.data ?? [];
              if (plans.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Nenhum plano criado ainda.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                );
              }
              return Column(
                children: [
                  for (final plan in plans)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(plan.title),
                        subtitle: Text('${plan.exercises.length} exercício(s)'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => planProvider.deletePlan(
                            widget.studentUid,
                            plan.id,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          const Text(
            'Histórico de treinos',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          StreamBuilder<List<Workout>>(
            stream: _firestoreService.watchWorkouts(widget.studentUid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Não foi possível carregar os treinos deste aluno. '
                    'Verifique as regras de segurança do Firestore.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                );
              }

              final workouts = snapshot.data ?? [];
              if (workouts.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Este aluno ainda não registrou treinos.'),
                );
              }

              final totalVolume = workouts.fold<double>(
                0,
                (sum, w) => sum + w.totalVolume,
              );

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Treinos',
                          value: '${workouts.length}',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Volume total',
                          value: '${totalVolume.toStringAsFixed(0)} kg',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final w in workouts)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(w.name),
                        subtitle: Text(
                          '${DateFormat('dd/MM/yyyy').format(w.date)} · ${w.totalSets} séries',
                        ),
                        trailing: Text(
                          '${w.totalVolume.toStringAsFixed(0)} kg',
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
