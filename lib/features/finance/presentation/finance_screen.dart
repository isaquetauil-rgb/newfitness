import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/finance/logic/finance_provider.dart';
import 'package:newfitness/shared/models/subscription.dart';
import 'package:newfitness/shared/models/user_profile.dart';
import 'package:newfitness/shared/services/firestore_service.dart';

String _formatCents(int? cents) {
  if (cents == null) return '—';
  return 'R\$ ${(cents / 100).toStringAsFixed(2).replaceAll('.', ',')}';
}

String _statusLabel(SubscriptionStatus status) {
  switch (status) {
    case SubscriptionStatus.authorized:
      return 'Em dia';
    case SubscriptionStatus.pending:
      return 'Pendente';
    case SubscriptionStatus.paused:
      return 'Pausada';
    case SubscriptionStatus.cancelled:
      return 'Cancelada';
    case SubscriptionStatus.none:
      return 'Sem assinatura';
  }
}

Color _statusColor(SubscriptionStatus status) {
  switch (status) {
    case SubscriptionStatus.authorized:
      return Colors.green;
    case SubscriptionStatus.pending:
      return Colors.orange;
    case SubscriptionStatus.paused:
    case SubscriptionStatus.cancelled:
      return Colors.red;
    case SubscriptionStatus.none:
      return Colors.grey;
  }
}

/// Financeiro: mensalidade recorrente via Mercado Pago (ver
/// `functions/src/mercadopago.ts`). Aluno assina/acompanha o próprio
/// pagamento; instrutor define o valor mensal de cada aluno e acompanha o
/// status de todos.
class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;
    final uid = auth.user?.uid;

    if (uid == null || profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Financeiro')),
      body: profile.role == UserRole.instructor
          ? _InstructorFinanceView(instructorUid: uid)
          : _StudentFinanceView(studentUid: uid),
    );
  }
}

class _StudentFinanceView extends StatelessWidget {
  const _StudentFinanceView({required this.studentUid});

  final String studentUid;

  Future<void> _subscribe(BuildContext context) async {
    final provider = context.read<FinanceProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final initPoint = await provider.createCheckout();
      if (initPoint.isEmpty) return;
      final uri = Uri.parse(initPoint);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Não foi possível iniciar o pagamento: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StreamBuilder<Subscription>(
          stream: provider.watchSubscription(studentUid),
          builder: (context, snapshot) {
            final subscription = snapshot.data ?? const Subscription();
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _statusColor(subscription.status),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _statusLabel(subscription.status),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Mensalidade: ${_formatCents(subscription.amountCents)}',
                    ),
                    if (subscription.nextPaymentDate != null)
                      Text(
                        'Próxima cobrança: '
                        '${DateFormat('dd/MM/yyyy').format(subscription.nextPaymentDate!)}',
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: provider.isCreatingCheckout
                          ? null
                          : () => _subscribe(context),
                      child: provider.isCreatingCheckout
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              subscription.status ==
                                      SubscriptionStatus.authorized
                                  ? 'Atualizar forma de pagamento'
                                  : 'Assinar',
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        StreamBuilder<Subscription>(
          stream: provider.watchSubscription(studentUid),
          builder: (context, subscriptionSnapshot) {
            final subscription =
                subscriptionSnapshot.data ?? const Subscription();
            return StreamBuilder<AiUsage>(
              stream: provider.watchAiUsage(studentUid),
              builder: (context, usageSnapshot) {
                final usage = usageSnapshot.data ?? const AiUsage();
                return _AiPlanCard(
                  planTier: subscription.planTier,
                  usage: usage,
                );
              },
            );
          },
        ),
        const SizedBox(height: 24),
        const Text(
          'Histórico de pagamentos',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<SubscriptionPayment>>(
          stream: provider.watchPayments(studentUid),
          builder: (context, snapshot) {
            final payments = snapshot.data ?? [];
            if (payments.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Nenhum pagamento registrado ainda.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              );
            }
            return Column(
              children: [
                for (final payment in payments)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(_formatCents(payment.amountCents)),
                      subtitle: Text(
                        DateFormat('dd/MM/yyyy').format(payment.date),
                      ),
                      trailing: Text(payment.status),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Mostra o plano de IA do aluno (definido pelo instrutor em
/// `_StudentFinanceTile`) e quanto já foi usado este mês — pra não deixar o
/// limite ser uma surpresa quando a análise for recusada.
class _AiPlanCard extends StatelessWidget {
  const _AiPlanCard({required this.planTier, required this.usage});

  final PlanTier planTier;
  final AiUsage usage;

  @override
  Widget build(BuildContext context) {
    final isPremium = planTier == PlanTier.premium;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isPremium ? Icons.star : Icons.star_border,
                  color: isPremium ? Colors.amber : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Plano de IA: ${isPremium ? 'Premium' : 'Básico'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (isPremium)
              Text(
                'Fotos de refeição e de evolução com IA ilimitadas.',
                style: TextStyle(color: Colors.grey.shade600),
              )
            else ...[
              Text(
                'Fotos de refeição com IA este mês: '
                '${usage.mealPhotoCount}/${AiUsageLimits.basicMealPhotosPerMonth}',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              Text(
                'Fotos de evolução com IA este mês: '
                '${usage.bodyPhotoCount}/${AiUsageLimits.basicBodyPhotosPerMonth}',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InstructorFinanceView extends StatelessWidget {
  const _InstructorFinanceView({required this.instructorUid});

  final String instructorUid;

  @override
  Widget build(BuildContext context) {
    final firestoreService = getIt<FirestoreService>();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: firestoreService.watchStudents(instructorUid),
      builder: (context, snapshot) {
        final students = snapshot.data ?? [];
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (students.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Nenhum aluno vinculado ainda.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: students.length,
          itemBuilder: (context, i) {
            final student = students[i];
            return _StudentFinanceTile(
              instructorUid: instructorUid,
              studentUid: student['uid'] as String,
              studentName: student['name'] as String? ?? '',
              monthlyFeeCents: (student['monthlyFeeCents'] as num?)?.toInt(),
              planTier: planTierFromString(student['planTier'] as String?),
            );
          },
        );
      },
    );
  }
}

class _StudentFinanceTile extends StatefulWidget {
  const _StudentFinanceTile({
    required this.instructorUid,
    required this.studentUid,
    required this.studentName,
    required this.monthlyFeeCents,
    required this.planTier,
  });

  final String instructorUid;
  final String studentUid;
  final String studentName;
  final int? monthlyFeeCents;
  final PlanTier planTier;

  @override
  State<_StudentFinanceTile> createState() => _StudentFinanceTileState();
}

class _StudentFinanceTileState extends State<_StudentFinanceTile> {
  late final _feeCtrl = TextEditingController(
    text: widget.monthlyFeeCents != null
        ? (widget.monthlyFeeCents! / 100).toStringAsFixed(2)
        : '',
  );

  @override
  void dispose() {
    _feeCtrl.dispose();
    super.dispose();
  }

  void _saveFee() {
    final value = double.tryParse(_feeCtrl.text.replaceAll(',', '.'));
    if (value == null) return;
    context.read<FinanceProvider>().updateStudentFee(
      widget.instructorUid,
      widget.studentUid,
      (value * 100).round(),
    );
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Valor atualizado')));
  }

  Future<void> _changeTier(PlanTier tier) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<FinanceProvider>().setStudentPlanTier(
        widget.studentUid,
        tier,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Não foi possível mudar o plano: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.studentName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                StreamBuilder<Subscription>(
                  stream: provider.watchSubscription(widget.studentUid),
                  builder: (context, snapshot) {
                    final subscription = snapshot.data ?? const Subscription();
                    return Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _statusColor(subscription.status),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(_statusLabel(subscription.status)),
                      ],
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _feeCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Mensalidade (R\$)',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(onPressed: _saveFee, child: const Text('Salvar')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Plano de IA:',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(width: 8),
                SegmentedButton<PlanTier>(
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: const [
                    ButtonSegment(value: PlanTier.basic, label: Text('Básico')),
                    ButtonSegment(
                      value: PlanTier.premium,
                      label: Text('Premium'),
                    ),
                  ],
                  selected: {widget.planTier},
                  onSelectionChanged: (s) => _changeTier(s.first),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
