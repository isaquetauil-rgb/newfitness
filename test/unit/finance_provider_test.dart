import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:newfitness/features/finance/logic/finance_provider.dart';
import 'package:newfitness/shared/models/subscription.dart';

import '../helpers/mocks.dart';

void main() {
  late MockFirestoreService firestoreService;
  late MockFunctionsClient functionsClient;
  late FinanceProvider provider;

  setUp(() {
    firestoreService = MockFirestoreService();
    functionsClient = MockFunctionsClient();
    provider = FinanceProvider(
      firestoreService: firestoreService,
      client: functionsClient,
    );
  });

  test('watchSubscription delega ao FirestoreService', () async {
    final controller = StreamController<Subscription>();
    when(() => firestoreService.watchSubscription('student1'))
        .thenAnswer((_) => controller.stream);

    const subscription = Subscription(
      status: SubscriptionStatus.authorized,
      amountCents: 15000,
    );
    final future = provider.watchSubscription('student1').first;
    controller.add(subscription);
    final result = await future;

    expect(result, subscription);
    await controller.close();
  });

  test('watchPayments delega ao FirestoreService', () async {
    final controller = StreamController<List<SubscriptionPayment>>();
    when(() => firestoreService.watchPayments('student1'))
        .thenAnswer((_) => controller.stream);

    final payment = SubscriptionPayment(
      id: 'pay1',
      amountCents: 15000,
      date: DateTime(2024, 1, 1),
      status: 'approved',
    );
    final future = provider.watchPayments('student1').first;
    controller.add([payment]);
    final result = await future;

    expect(result, [payment]);
    await controller.close();
  });

  test('updateStudentFee delega ao FirestoreService', () async {
    when(
      () => firestoreService.updateStudentFee('instructor1', 'student1', 15000),
    ).thenAnswer((_) async {});

    await provider.updateStudentFee('instructor1', 'student1', 15000);

    verify(
      () => firestoreService.updateStudentFee('instructor1', 'student1', 15000),
    ).called(1);
  });

  test('createCheckout chama a Cloud Function e devolve o initPoint', () async {
    when(() => functionsClient.call('createSubscriptionCheckout', {}))
        .thenAnswer(
          (_) async => {'initPoint': 'https://mercadopago.com/checkout/x'},
        );

    final initPoint = await provider.createCheckout();

    expect(initPoint, 'https://mercadopago.com/checkout/x');
    verify(() => functionsClient.call('createSubscriptionCheckout', {}))
        .called(1);
  });

  test(
    'createCheckout liga e desliga isCreatingCheckout durante a chamada',
    () async {
      final completer = Completer<Map<String, dynamic>>();
      when(() => functionsClient.call('createSubscriptionCheckout', {}))
          .thenAnswer((_) => completer.future);

      expect(provider.isCreatingCheckout, isFalse);
      final future = provider.createCheckout();
      expect(provider.isCreatingCheckout, isTrue);

      completer.complete({'initPoint': 'https://mercadopago.com/checkout/x'});
      await future;

      expect(provider.isCreatingCheckout, isFalse);
    },
  );

  test(
    'createCheckout desliga isCreatingCheckout mesmo quando falha',
    () async {
      when(() => functionsClient.call('createSubscriptionCheckout', {}))
          .thenThrow(Exception('falha de rede'));

      await expectLater(provider.createCheckout(), throwsException);

      expect(provider.isCreatingCheckout, isFalse);
    },
  );

  test('watchAiUsage delega ao FirestoreService', () async {
    final controller = StreamController<AiUsage>();
    when(() => firestoreService.watchAiUsage('student1'))
        .thenAnswer((_) => controller.stream);

    const usage = AiUsage(mealPhotoCount: 2, bodyPhotoCount: 1);
    final future = provider.watchAiUsage('student1').first;
    controller.add(usage);
    final result = await future;

    expect(result, usage);
    await controller.close();
  });

  test('setStudentPlanTier chama a Cloud Function com o tier certo', () async {
    when(
      () => functionsClient.call('setStudentPlanTier', {
        'studentUid': 'student1',
        'planTier': 'premium',
      }),
    ).thenAnswer((_) async => {'ok': true});

    await provider.setStudentPlanTier('student1', PlanTier.premium);

    verify(
      () => functionsClient.call('setStudentPlanTier', {
        'studentUid': 'student1',
        'planTier': 'premium',
      }),
    ).called(1);
  });
}
