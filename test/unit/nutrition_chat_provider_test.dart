import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:newfitness/features/nutrition/logic/nutrition_chat_provider.dart';
import 'package:newfitness/shared/models/nutrition_message.dart';

import '../helpers/mocks.dart';

void main() {
  late MockAiService aiService;
  late MockFirestoreService firestoreService;
  late NutritionChatProvider provider;

  setUpAll(() {
    registerFallbackValue(
      NutritionMessage(
        id: '',
        role: NutritionRole.user,
        content: '',
        createdAt: DateTime(2024),
      ),
    );
  });

  setUp(() {
    aiService = MockAiService();
    firestoreService = MockFirestoreService();
    provider = NutritionChatProvider(
      aiService: aiService,
      firestoreService: firestoreService,
    );
  });

  test('watchMessages delega ao FirestoreService', () async {
    final controller = StreamController<List<NutritionMessage>>();
    when(() => firestoreService.watchNutritionChat('student1'))
        .thenAnswer((_) => controller.stream);

    final message = NutritionMessage(
      id: 'm1',
      role: NutritionRole.assistant,
      content: 'Olá!',
      createdAt: DateTime(2024, 1, 1),
    );
    final future = provider.watchMessages('student1').first;
    controller.add([message]);
    final result = await future;

    expect(result, [message]);
    await controller.close();
  });

  test('ask grava só a pergunta (role user) e chama a IA — a resposta '
      '(assistant) é gravada pela Cloud Function, nunca pelo app', () async {
    when(() => firestoreService.addNutritionMessage('student1', any()))
        .thenAnswer((_) async {});
    when(
      () => aiService.askNutrition(
        message: any(named: 'message'),
      ),
    ).thenAnswer((_) async => 'Coma mais fibras.');

    await provider.ask('student1', 'O que comer no café?');

    final captured = verify(
      () => firestoreService.addNutritionMessage('student1', captureAny()),
    ).captured;
    expect(captured.length, 1);
    expect((captured.single as NutritionMessage).role, NutritionRole.user);
    verify(
      () => aiService.askNutrition(
        message: 'O que comer no café?',
      ),
    ).called(1);
    expect(provider.isSending, isFalse);
    expect(provider.error, isNull);
  });

  test('ask define uma mensagem de erro amigável quando a IA falha', () async {
    when(() => firestoreService.addNutritionMessage('student1', any()))
        .thenAnswer((_) async {});
    when(
      () => aiService.askNutrition(
        message: any(named: 'message'),
      ),
    ).thenThrow(Exception('falha de rede'));

    await provider.ask('student1', 'O que comer no café?');

    expect(provider.error, isNotNull);
    expect(provider.isSending, isFalse);
  });

  test('addCorrection grava mensagem com papel nutritionist', () async {
    when(() => firestoreService.addNutritionMessage('student1', any()))
        .thenAnswer((_) async {});

    await provider.addCorrection(
      'student1',
      'Cuidado com o açúcar',
      'Dra. Ana',
    );

    final saved =
        verify(
              () => firestoreService.addNutritionMessage(
                'student1',
                captureAny(),
              ),
            ).captured.single
            as NutritionMessage;
    expect(saved.role, NutritionRole.nutritionist);
    expect(saved.authorName, 'Dra. Ana');
    expect(saved.content, 'Cuidado com o açúcar');
  });

  test(
    'ask: se nem a pergunta for salva, mostra erro e libera o botão',
    () async {
      when(() => firestoreService.addNutritionMessage('student1', any()))
          .thenThrow(Exception('permission-denied'));

      await provider.ask('student1', 'Posso comer ovo?');

      expect(provider.isSending, isFalse);
      expect(provider.error, isNotNull);
      verifyNever(
        () => aiService.askNutrition(
          message: any(named: 'message'),
        ),
      );
    },
  );
}
