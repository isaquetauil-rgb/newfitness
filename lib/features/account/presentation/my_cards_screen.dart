import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/app/routes/app_routes.dart';
import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/features/account/presentation/account_widgets.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/finance/logic/subscription_labels.dart';
import 'package:newfitness/shared/models/subscription.dart';
import 'package:newfitness/shared/models/user_profile.dart';
import 'package:newfitness/shared/services/firestore_service.dart';

/// Meus cartões: o app NÃO guarda cartão. O pagamento da mensalidade é feito
/// no Mercado Pago, que guarda o cartão; aqui a pessoa vê a mensalidade, os
/// últimos pagamentos e vai para o Financeiro para pagar ou trocar o cartão.
class MyCardsScreen extends StatelessWidget {
  const MyCardsScreen({super.key, this.firestoreService});

  /// Para testes; no app vem do injetor.
  final FirestoreService? firestoreService;

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    final db = firestoreService ?? getIt<FirestoreService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Meus cartões')),
      body: profile == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                const AccountNotice(
                  icon: Icons.lock_outline,
                  text:
                      'Seu cartão fica guardado com segurança no Mercado Pago. '
                      'O NewFitness não vê nem salva o número do cartão.',
                ),
                if (profile.role != UserRole.student)
                  AccountSection(
                    title: 'Recebimentos',
                    children: [
                      AccountTile(
                        icon: Icons.payments_outlined,
                        title: 'Mensalidades dos alunos',
                        subtitle:
                            'Defina o valor de cada aluno e acompanhe quem '
                            'está em dia no Financeiro.',
                        onTap: () => context.push(AppRoutes.finance),
                      ),
                    ],
                  )
                else ...[
                  StreamBuilder<Subscription>(
                    stream: db.watchSubscription(profile.uid),
                    builder: (context, snap) {
                      final sub = snap.data ?? const Subscription();
                      final next = sub.nextPaymentDate;
                      return AccountSection(
                        title: 'Mensalidade',
                        children: [
                          AccountTile(
                            key: const ValueKey('subscription-status'),
                            icon: Icons.credit_card,
                            iconColor: subscriptionStatusColor(sub.status),
                            title: subscriptionStatusLabel(sub.status),
                            subtitle: sub.status == SubscriptionStatus.none
                                ? 'Você ainda não tem cartão cadastrado para '
                                      'a mensalidade.'
                                : [
                                    formatCents(sub.amountCents),
                                    if (next != null)
                                      'próxima cobrança em ${formatDate(next)}',
                                  ].join(' · '),
                          ),
                          FilledButton.icon(
                            key: const ValueKey('go-finance'),
                            onPressed: () => context.push(AppRoutes.finance),
                            icon: const Icon(Icons.add_card),
                            label: Text(
                              sub.status == SubscriptionStatus.none
                                  ? 'Cadastrar cartão e assinar'
                                  : 'Pagar ou trocar o cartão',
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  StreamBuilder<List<SubscriptionPayment>>(
                    stream: db.watchPayments(profile.uid),
                    builder: (context, snap) {
                      final payments = [...?snap.data]
                        ..sort((a, b) => b.date.compareTo(a.date));
                      return AccountSection(
                        title: 'Últimos pagamentos',
                        children: [
                          if (payments.isEmpty)
                            const AccountNotice(
                              text: 'Nenhum pagamento registrado ainda.',
                            )
                          else
                            for (final p in payments.take(5))
                              AccountTile(
                                icon: Icons.receipt_long_outlined,
                                title: formatCents(p.amountCents),
                                subtitle:
                                    '${formatDate(p.date)} · ${_paymentStatus(p.status)}',
                              ),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
    );
  }

  static String _paymentStatus(String status) => switch (status) {
    'approved' || 'authorized' || 'processed' => 'aprovado',
    'pending' || 'in_process' => 'em análise',
    'rejected' => 'recusado',
    'refunded' => 'estornado',
    'cancelled' => 'cancelado',
    _ => status,
  };
}
