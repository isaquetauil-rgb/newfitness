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

/// Plano de IA do aluno — definido SÓ pelo administrador (Cloud Function
/// `setStudentPlanTier`) em `users/{uid}/finance/subscription.planTier`, a
/// mesma fonte que a cota lê no backend (`reserveAiQuota` em
/// `functions/src/ai_guard.ts`). Sem plano gravado = `basic`.
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

/// Cotas de IA do ALUNO por plano — os mesmos números do backend
/// (`QUOTAS` em `functions/src/ai_guard.ts`), repetidos aqui só para
/// mostrar "X de Y" na tela; a trava de verdade é sempre no servidor.
class AiUsageLimits {
  const AiUsageLimits._({
    required this.chatPerDay,
    required this.nutritionPerMonth,
    required this.mealPhotosPerMonth,
  });

  final int chatPerDay;
  final int nutritionPerMonth;
  final int mealPhotosPerMonth;

  static const basic = AiUsageLimits._(
    chatPerDay: 5,
    nutritionPerMonth: 10,
    mealPhotosPerMonth: 3,
  );
  static const premium = AiUsageLimits._(
    chatPerDay: 20,
    nutritionPerMonth: 60,
    mealPhotosPerMonth: 60,
  );

  static AiUsageLimits forTier(PlanTier tier) =>
      tier == PlanTier.premium ? premium : basic;
}

/// Chaves dos contadores de IA no fuso de São Paulo (UTC−3, sem horário de
/// verão) — as mesmas de `periodKey` no backend: `yyyy-MM` (mês, vira no
/// dia 1º) e `yyyy-MM-dd` (dia, vira à meia-noite).
String aiUsageMonthKey(DateTime now) => _saoPauloDate(now).substring(0, 7);
String aiUsageDayKey(DateTime now) => _saoPauloDate(now);

String _saoPauloDate(DateTime now) {
  final sp = now.toUtc().subtract(const Duration(hours: 3));
  String two(int v) => v.toString().padLeft(2, '0');
  return '${sp.year}-${two(sp.month)}-${two(sp.day)}';
}

/// Uso de IA do aluno: `users/{uid}/ai_usage/{yyyy-MM}` (nutrição e fotos
/// no mês) e `users/{uid}/ai_usage/{yyyy-MM-dd}` (chat no dia). Só a Cloud
/// Function grava; o app só lê, para mostrar "X de Y".
class AiUsage {
  final int mealPhotoCount;
  final int nutritionCount;
  final int chatTodayCount;

  /// Contador legado das fotos de evolução com IA (função removida) — só
  /// lido de documentos antigos, não aparece mais na tela.
  final int bodyPhotoCount;

  const AiUsage({
    this.mealPhotoCount = 0,
    this.nutritionCount = 0,
    this.chatTodayCount = 0,
    this.bodyPhotoCount = 0,
  });

  factory AiUsage.fromDocs({
    Map<String, dynamic>? month,
    Map<String, dynamic>? day,
  }) {
    int count(Map<String, dynamic>? map, String key) =>
        (map?[key] as num?)?.toInt() ?? 0;
    return AiUsage(
      mealPhotoCount: count(month, 'mealPhoto'),
      nutritionCount: count(month, 'nutrition'),
      chatTodayCount: count(day, 'chat'),
      bodyPhotoCount: count(month, 'bodyPhoto'),
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
