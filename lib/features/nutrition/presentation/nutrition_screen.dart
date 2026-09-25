import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/app/widgets/drawer_menu_button.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/profile/presentation/manage_link_sheet.dart';
import 'package:newfitness/features/nutrition/logic/nutrition_plan_provider.dart';
import 'package:newfitness/features/nutrition/presentation/nutrition_chat_view.dart';
import 'package:newfitness/shared/models/nutrition_plan.dart';

/// Tela do aluno: se ainda não tem nutricionista vinculada, mostra o cartão
/// pra vincular por código (mesmo padrão de `_LinkInstructorCard` no
/// Perfil); depois disso, mostra o plano alimentar atual e a conversa de
/// nutrição (perguntas à IA + correções da nutricionista).
class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen>
    with SingleTickerProviderStateMixin {
  late final _tabController = TabController(length: 2, vsync: this);
  final _codeCtrl = TextEditingController();
  bool _linking = false;

  @override
  void dispose() {
    _tabController.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _link() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;
    final authProvider = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _linking = true);
    // Valida e grava o vínculo no servidor (Cloud Function) — o app nunca
    // escreve `nutritionistId` diretamente, ver `firestore.rules`.
    final nutritionistName = await authProvider.linkToNutritionist(code);
    if (!mounted) return;
    setState(() => _linking = false);
    if (nutritionistName == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            authProvider.errorMessage ?? 'Código de nutricionista inválido',
          ),
        ),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(content: Text('Vinculado a $nutritionistName!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (profile.nutritionistId == null) {
      return Scaffold(
        appBar: AppBar(
          leading: const DrawerMenuButton(),
          title: const Text('Nutrição'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Vincular a uma nutricionista',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Peça o código de convite à sua nutricionista pra '
                    'liberar plano alimentar e perguntas com correção dela.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _codeCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            hintText: 'Código da nutricionista',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _linking ? null : _link,
                        child: _linking
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Vincular'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Nutrição'),
        actions: [
          IconButton(
            icon: const Icon(Icons.manage_accounts_outlined),
            tooltip: 'Trocar ou desvincular nutricionista',
            onPressed: () =>
                showManageLinkSheet(context, LinkedProfessional.nutritionist),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Perguntas'),
            Tab(text: 'Meu plano'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          NutritionChatView(studentUid: profile.uid, isNutritionistView: false),
          _MyPlanTab(studentUid: profile.uid),
        ],
      ),
    );
  }
}

class _MyPlanTab extends StatelessWidget {
  const _MyPlanTab({required this.studentUid});

  final String studentUid;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NutritionPlanProvider>();

    return StreamBuilder<List<NutritionPlan>>(
      stream: provider.watchPlans(studentUid),
      builder: (context, snapshot) {
        final plans = snapshot.data ?? [];
        if (plans.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Sua nutricionista ainda não enviou um plano alimentar.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          );
        }
        final plan = plans.first;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              plan.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            if (plan.instructions != null) ...[
              const SizedBox(height: 8),
              Text(plan.instructions!),
            ],
            const SizedBox(height: 16),
            for (final meal in plan.meals)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(meal.label),
                  subtitle: Text(meal.description),
                  trailing: meal.suggestedTime != null
                      ? Text(meal.suggestedTime!)
                      : null,
                ),
              ),
          ],
        );
      },
    );
  }
}
