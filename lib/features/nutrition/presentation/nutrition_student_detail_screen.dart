import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/app/routes/app_routes.dart';
import 'package:newfitness/features/ai/logic/meal_photo_provider.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/nutrition/logic/nutrition_plan_provider.dart';
import 'package:newfitness/features/nutrition/presentation/nutrition_chat_view.dart';
import 'package:newfitness/features/nutrition/presentation/nutrition_plan_editor_screen.dart';
import 'package:newfitness/shared/models/meal_photo.dart';
import 'package:newfitness/shared/models/nutrition_plan.dart';

class NutritionStudentDetailArgs {
  const NutritionStudentDetailArgs({required this.uid, required this.name});

  final String uid;
  final String name;
}

/// Visão da nutricionista sobre um aluno específico: fotos de refeição
/// (isoladas do instrutor), a conversa de nutrição (onde ela pode corrigir a
/// IA) e o plano alimentar atual, com atalho pra editar.
class NutritionStudentDetailScreen extends StatefulWidget {
  const NutritionStudentDetailScreen({super.key, required this.args});

  final NutritionStudentDetailArgs args;

  @override
  State<NutritionStudentDetailScreen> createState() =>
      _NutritionStudentDetailScreenState();
}

class _NutritionStudentDetailScreenState
    extends State<NutritionStudentDetailScreen>
    with SingleTickerProviderStateMixin {
  late final _tabController = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nutritionistUid = context.watch<AuthProvider>().user?.uid;
    if (nutritionistUid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.args.name),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Refeições'),
            Tab(text: 'Perguntas'),
            Tab(text: 'Plano'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MealHistoryTab(studentUid: widget.args.uid),
          NutritionChatView(
            studentUid: widget.args.uid,
            isNutritionistView: true,
          ),
          _PlanTab(
            studentUid: widget.args.uid,
            studentName: widget.args.name,
            nutritionistUid: nutritionistUid,
          ),
        ],
      ),
    );
  }
}

class _MealHistoryTab extends StatelessWidget {
  const _MealHistoryTab({required this.studentUid});

  final String studentUid;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MealPhotoProvider>();

    return StreamBuilder<List<MealPhoto>>(
      stream: provider.watchPhotos(studentUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final meals = snapshot.data ?? [];
        if (meals.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Nenhuma refeição registrada ainda.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: meals.length,
          itemBuilder: (context, i) {
            final meal = meals[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        meal.imageUrl,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                meal.mealType.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                DateFormat('dd/MM HH:mm').format(meal.date),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          if (meal.aiAnalysis != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              meal.aiAnalysis!,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _PlanTab extends StatelessWidget {
  const _PlanTab({
    required this.studentUid,
    required this.studentName,
    required this.nutritionistUid,
  });

  final String studentUid;
  final String studentName;
  final String nutritionistUid;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NutritionPlanProvider>();

    return StreamBuilder<List<NutritionPlan>>(
      stream: provider.watchPlans(studentUid),
      builder: (context, snapshot) {
        final plans = snapshot.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final plan in plans)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(plan.title),
                  subtitle: Text('${plan.meals.length} refeição(ões)'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => context.push(
                      AppRoutes.nutritionistPlanEditor,
                      extra: NutritionPlanEditorArgs(
                        studentUid: studentUid,
                        studentName: studentName,
                        nutritionistUid: nutritionistUid,
                        existing: plan,
                      ),
                    ),
                  ),
                ),
              ),
            if (plans.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Nenhum plano alimentar criado ainda.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => context.push(
                AppRoutes.nutritionistPlanEditor,
                extra: NutritionPlanEditorArgs(
                  studentUid: studentUid,
                  studentName: studentName,
                  nutritionistUid: nutritionistUid,
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Novo plano alimentar'),
            ),
          ],
        );
      },
    );
  }
}
