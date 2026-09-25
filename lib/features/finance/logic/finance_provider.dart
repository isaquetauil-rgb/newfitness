import 'package:flutter/foundation.dart';

import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/core/network/functions_client.dart';
import 'package:newfitness/shared/models/subscription.dart';
import 'package:newfitness/shared/services/firestore_service.dart';

/// Mensalidade do aluno via assinatura recorrente no Mercado Pago. A escrita
/// de status/pagamentos é feita só pela Cloud Function
/// (`functions/src/mercadopago.ts`) — este provider só lê e dispara a
/// criação do checkout.
class FinanceProvider extends ChangeNotifier {
  FinanceProvider({FirestoreService? firestoreService, FunctionsClient? client})
    : _firestoreService = firestoreService ?? getIt<FirestoreService>(),
      _client = client ?? FunctionsClient();

  final FirestoreService _firestoreService;
  final FunctionsClient _client;

  bool _creatingCheckout = false;
  bool get isCreatingCheckout => _creatingCheckout;

  Stream<Subscription> watchSubscription(String uid) {
    return _firestoreService.watchSubscription(uid);
  }

  Stream<List<SubscriptionPayment>> watchPayments(String uid) {
    return _firestoreService.watchPayments(uid);
  }

  Future<void> updateStudentFee(
    String instructorId,
    String studentUid,
    int feeCents,
  ) {
    return _firestoreService.updateStudentFee(
      instructorId,
      studentUid,
      feeCents,
    );
  }

  Stream<AiUsage> watchAiUsage(String uid) {
    return _firestoreService.watchAiUsage(uid);
  }

  /// Define o plano (Básico/Premium) de uso de IA de um aluno — só o
  /// instrutor vinculado pode chamar (validado na própria Cloud Function).
  /// Ao contrário de `updateStudentFee` (grava direto no Firestore), aqui
  /// passa por uma function porque o mesmo valor precisa ser espelhado em
  /// dois lugares (`students/{uid}` do instrutor e `finance/subscription`
  /// do aluno) de forma atômica.
  Future<void> setStudentPlanTier(String studentUid, PlanTier tier) {
    return _client.call('setStudentPlanTier', {
      'studentUid': studentUid,
      'planTier': planTierToString(tier),
    });
  }

  /// Cria a assinatura no Mercado Pago para o aluno logado e devolve o
  /// `initPoint` (URL de checkout) pra tela abrir com `url_launcher`.
  Future<String> createCheckout() async {
    _creatingCheckout = true;
    notifyListeners();
    try {
      final data = await _client.call('createSubscriptionCheckout', {});
      return data['initPoint'] as String? ?? '';
    } finally {
      _creatingCheckout = false;
      notifyListeners();
    }
  }
}
