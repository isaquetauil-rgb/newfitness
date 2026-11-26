import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/app/routes/app_routes.dart';
import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/features/account/presentation/account_widgets.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/finance/logic/subscription_labels.dart';
import 'package:newfitness/shared/models/nutrition_plan.dart';
import 'package:newfitness/shared/models/subscription.dart';
import 'package:newfitness/shared/models/training_plan.dart';
import 'package:newfitness/shared/models/user_profile.dart';
import 'package:newfitness/shared/services/firestore_service.dart';

/// Contratos ativos: com quem a pessoa tem vínculo hoje e o que está valendo.
/// Aluno: personal (plano de treino), nutricionista (plano alimentar) e a
/// mensalidade. Profissional: quantos alunos estão vinculados.
class ActiveContractsScreen extends StatelessWidget {
  const ActiveContractsScreen({super.key, this.firestoreService});

  /// Para testes; no app vem do injetor.
  final FirestoreService? firestoreService;

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    final db = firestoreService ?? getIt<FirestoreService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Contratos ativos')),
      body: profile == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: profile.role == UserRole.student
                  ? _student(context, db, profile)
                  : _professional(context, db, profile),
            ),
    );
  }

  List<Widget> _student(
    BuildContext context,
    FirestoreService db,
    UserProfile profile,
  ) {
    final hasInstructor = (profile.instructorId ?? '').isNotEmpty;
    final hasNutritionist = (profile.nutritionistId ?? '').isNotEmpty;
    return [
      AccountSection(
        title: 'Personal',
        children: [
          if (!hasInstructor)
            AccountTile(
              key: const ValueKey('no-instructor'),
              icon: Icons.person_search_outlined,
              iconColor: Colors.grey,
              title: 'Sem personal vinculado',
              subtitle: 'Peça o código de convite ao seu personal e digite no Perfil.',
              onTap: () => context.go(AppRoutes.profile),
            )
          else
            StreamBuilder<List<TrainingPlan>>(
              stream: db.watchTrainingPlans(profile.uid),
              builder: (context, snap) {
                final plans = [...?snap.data]
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AccountTile(
                      key: ValueKey('instructor-linked'),
                      icon: Icons.verified_user_outlined,
                      iconColor: Colors.green,
                      title: 'Personal vinculado',
                      subtitle: 'Ele vê seus treinos e monta seu plano.',
                    ),
                    if (snap.hasData && plans.isEmpty)
                      const AccountNotice(
                        text:
                            'Seu personal ainda não montou um plano para você.',
                      ),
                    for (final p in plans)
                      AccountTile(
                        icon: Icons.fitness_center,
                        title: p.title,
                        subtitle:
                            '${p.workouts.length} treino(s) · desde '
                            '${formatDate(p.createdAt)}',
                        onTap: () => context.go(AppRoutes.workout),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
      AccountSection(
        title: 'Nutricionista',
        children: [
          if (!hasNutritionist)
            AccountTile(
              key: const ValueKey('no-nutritionist'),
              icon: Icons.person_search_outlined,
              iconColor: Colors.grey,
              title: 'Sem nutricionista vinculada',
              subtitle:
                  'Peça o código de convite à sua nutricionista e digite no '
                  'Perfil.',
              onTap: () => context.go(AppRoutes.profile),
            )
          else
            StreamBuilder<List<NutritionPlan>>(
              stream: db.watchNutritionPlans(profile.uid),
              builder: (context, snap) {
                final plans = [...?snap.data]
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AccountTile(
                      key: ValueKey('nutritionist-linked'),
                      icon: Icons.verified_user_outlined,
                      iconColor: Colors.green,
                      title: 'Nutricionista vinculada',
                      subtitle: 'Ela vê suas refeições e monta seu plano.',
                    ),
                    if (snap.hasData && plans.isEmpty)
                      const AccountNotice(
                        text:
                            'Sua nutricionista ainda não montou um plano '
                            'alimentar para você.',
                      ),
                    for (final p in plans)
                      AccountTile(
                        icon: Icons.restaurant_menu,
                        title: p.title,
                        subtitle:
                            '${p.meals.length} refeição(ões) · desde '
                            '${formatDate(p.createdAt)}',
                        onTap: () => context.push(AppRoutes.nutrition),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
      StreamBuilder<Subscription>(
        stream: db.watchSubscription(profile.uid),
        builder: (context, snap) {
          final sub = snap.data ?? const Subscription();
          return AccountSection(
            title: 'Mensalidade',
            children: [
              AccountTile(
                key: const ValueKey('contract-subscription'),
                icon: Icons.receipt_long_outlined,
                iconColor: subscriptionStatusColor(sub.status),
                title: subscriptionStatusLabel(sub.status),
                subtitle: sub.status == SubscriptionStatus.none
                    ? 'Nenhuma mensalidade ativa.'
                    : [
                        formatCents(sub.amountCents),
                        if (sub.nextPaymentDate != null)
                          'próxima cobrança em '
                              '${formatDate(sub.nextPaymentDate!)}',
                      ].join(' · '),
                onTap: () => context.push(AppRoutes.finance),
              ),
            ],
          );
        },
      ),
    ];
  }

  List<Widget> _professional(
    BuildContext context,
    FirestoreService db,
    UserProfile profile,
  ) {
    final isInstructor = profile.role == UserRole.instructor;
    final stream = isInstructor
        ? db.watchStudents(profile.uid)
        : db.watchNutritionStudents(profile.uid);
    return [
      StreamBuilder<List<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          final n = snap.data?.length;
          return AccountSection(
            title: 'Alunos',
            children: [
              AccountTile(
                key: const ValueKey('linked-students'),
                icon: Icons.groups_outlined,
                title: n == null
                    ? 'Carregando...'
                    : n == 1
                    ? '1 aluno vinculado'
                    : '$n alunos vinculados',
                subtitle: 'Veja a situação de cada um no painel.',
                onTap: () => context.go(
                  isInstructor ? AppRoutes.instructor : AppRoutes.nutritionist,
                ),
              ),
            ],
          );
        },
      ),
      if (isInstructor)
        AccountSection(
          title: 'Mensalidades',
          children: [
            AccountTile(
              icon: Icons.payments_outlined,
              title: 'Valores e pagamentos dos alunos',
              subtitle: 'No Financeiro.',
              onTap: () => context.push(AppRoutes.finance),
            ),
          ],
        ),
    ];
  }
}
