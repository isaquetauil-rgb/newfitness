/// Status de uma assinatura de mensalidade no Mercado Pago (ver
/// `functions/src/mercadopago.ts`, que é quem realmente escreve esse
/// documento via Admin SDK — o cliente só lê).
enum SubscriptionStatus { none, pending, authorized, paused, cancelled }

SubscriptionStatus subscriptionStatusFromString(String? value) {
  switch (value) {
    case 'pending':
      return SubscriptionStatus.pending;
    case 'authorized':
      return SubscriptionStatus.authorized;
    case 'paused':
      return SubscriptionStatus.paused;
    case 'cancelled':
      return SubscriptionStatus.cancelled;
    default:
      return SubscriptionStatus.none;
  }
}

/// Nível de uso de IA do aluno (fotos de refeição/evolução) — definido pelo
/// instrutor (`FinanceProvider.setStudentPlanTier`, via a Cloud Function
/// `setStudentPlanTier`) e aplicado como trava no backend em
/// `functions/src/index.ts` (`assertAiUsageAllowed`). `basic` é o padrão
/// quando o instrutor ainda não escolheu nada — evita uso ilimitado de IA
/// sem custo antes de qualquer configuração.
enum PlanTier { basic, premium }

PlanTier planTierFromString(String? value) {
  return value == 'premium' ? PlanTier.premium : PlanTier.basic;
}

String planTierToString(PlanTier tier) =>
    tier == PlanTier.premium ? 'premium' : 'basic';

/// `users/{uid}/finance/subscription` — estado atual da mensalidade de um
/// aluno. Só a Cloud Function grava (rules bloqueiam escrita do cliente);
/// o `amountCents` é uma cópia do que estava em `monthlyFeeCents` no
/// momento em que a assinatura foi criada.
class Subscription {
  final SubscriptionStatus status;
  final int? amountCents;
  final DateTime? nextPaymentDate;
  final String? lastPaymentStatus;
  final PlanTier planTier;

  const Subscription({
    this.status = SubscriptionStatus.none,
    this.amountCents,
    this.nextPaymentDate,
    this.lastPaymentStatus,
    this.planTier = PlanTier.basic,
  });

  factory Subscription.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const Subscription();
    return Subscription(
      status: subscriptionStatusFromString(map['status'] as String?),
      amountCents: (map['amountCents'] as num?)?.toInt(),
      nextPaymentDate: map['nextPaymentDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['nextPaymentDate'] as int)
          : null,
      lastPaymentStatus: map['lastPaymentStatus'] as String?,
      planTier: planTierFromString(map['planTier'] as String?),
    );
  }
}

/// Limites mensais de uso de IA do plano Básico (aluno) — o Premium não tem
/// limite. Mesmos números usados no backend (`functions/src/index.ts`);
/// duplicados aqui só para exibir "X de Y usados" na tela sem precisar de
/// mais uma leitura ao servidor.
class AiUsageLimits {
  AiUsageLimits._();

  static const basicMealPhotosPerMonth = 3;
  static const basicBodyPhotosPerMonth = 1;
}

/// Contagem de uso de IA do mês corrente — `users/{uid}/ai_usage/{yyyy-MM}`.
/// Incrementado só pela Cloud Function, depois de cada análise concluída com
/// sucesso (ver `incrementAiUsage` em `functions/src/index.ts`); o cliente só
/// lê, pra mostrar "X de Y usados" antes de tentar uma análise nova.
class AiUsage {
  final int mealPhotoCount;
  final int bodyPhotoCount;

  const AiUsage({this.mealPhotoCount = 0, this.bodyPhotoCount = 0});

  factory AiUsage.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const AiUsage();
    return AiUsage(
      mealPhotoCount: (map['mealPhoto'] as num?)?.toInt() ?? 0,
      bodyPhotoCount: (map['bodyPhoto'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Um pagamento já processado, em `users/{uid}/finance/subscription/payments/{id}`.
class SubscriptionPayment {
  final String id;
  final int amountCents;
  final DateTime date;
  final String status;

  const SubscriptionPayment({
    required this.id,
    required this.amountCents,
    required this.date,
    required this.status,
  });

  factory SubscriptionPayment.fromMap(String id, Map<String, dynamic> map) {
    return SubscriptionPayment(
      id: id,
      amountCents: (map['amountCents'] as num?)?.toInt() ?? 0,
      date: DateTime.fromMillisecondsSinceEpoch(
        map['date'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      status: map['status'] as String? ?? 'pending',
    );
  }
}
