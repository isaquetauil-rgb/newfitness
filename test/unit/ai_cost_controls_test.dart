import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

import 'package:newfitness/core/error/app_exception.dart';
import 'package:newfitness/features/ai/logic/chat_provider.dart';
import 'package:newfitness/features/ai/logic/meal_photo_provider.dart';
import 'package:newfitness/features/instructor/logic/instructor_ai_provider.dart';
import 'package:newfitness/features/nutrition/logic/nutrition_chat_provider.dart';
import 'package:newfitness/shared/models/chat_message.dart';
import 'package:newfitness/shared/models/meal_photo.dart';
import 'package:newfitness/shared/models/nutrition_message.dart';
import 'package:newfitness/shared/models/subscription.dart';

import '../helpers/mocks.dart';

/// Rodada 4 — controle de custo da IA no app: a análise da refeição e as
/// respostas do chat são gravadas pelo servidor, o app não manda histórico,
/// e a mensagem real do servidor (ex: cota esgotada) chega ao usuário.
void main() {
  const quotaMessage =
      'Você atingiu o limite de 5 mensagens no chat com IA de hoje do plano '
      'Básico. O limite renova à meia-noite.';

  late MockFirestoreService firestoreService;
  late MockStorageService storageService;
  late MockAiService aiService;

  setUpAll(() {
    registerTestFallbackValues();
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(
      MealPhoto(
        id: '',
        userId: '',
        date: DateTime(2024),
        mealType: MealType.lunch,
        imageUrl: '',
      ),
    );
    registerFallbackValue(
      ChatMessage(
        id: '',
        role: ChatRole.user,
        content: '',
        createdAt: DateTime(2024),
      ),
    );
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
    firestoreService = MockFirestoreService();
    storageService = MockStorageService();
    aiService = MockAiService();
  });

  group('Foto de refeição: análise pelo servidor', () {
    MealPhotoProvider buildProvider() => MealPhotoProvider(
      firestoreService: firestoreService,
      storageService: storageService,
      aiService: aiService,
    );

    setUp(() {
      when(() => storageService.uploadMealPhoto('u1', any()))
          .thenAnswer((_) async => 'https://x/meal.jpg');
      when(() => firestoreService.addMealPhoto(any()))
          .thenAnswer((_) async => 'm1');
    });

    test('salva a foto sem análise e pede a análise pelo id; o app não grava '
        'o resultado', () async {
      when(() => aiService.analyzeMealPhoto(photoId: any(named: 'photoId')))
          .thenAnswer((_) async => 'Prato equilibrado.');

      final result = await buildProvider().addPhoto(
        'u1',
        XFile.fromData(Uint8List.fromList([1, 2, 3])),
        MealType.lunch,
      );

      expect(result, isNull);
      final saved =
          verify(() => firestoreService.addMealPhoto(captureAny()))
                  .captured
                  .single
              as MealPhoto;
      expect(saved.aiAnalysis, isNull);
      expect(saved.aiAnalysisError, isNull);
      verify(() => aiService.analyzeMealPhoto(photoId: 'm1')).called(1);
      // nada além de criar a foto: a análise é gravada pela Function
      verifyNoMoreInteractions(firestoreService);
    });

    test('analisar de novo devolve a mensagem real do servidor', () async {
      when(() => aiService.analyzeMealPhoto(photoId: any(named: 'photoId')))
          .thenThrow(const ValidationException('Atualize o app para ver.'));
      expect(await buildProvider().analyze('m1'), 'Atualize o app para ver.');

      when(() => aiService.analyzeMealPhoto(photoId: any(named: 'photoId')))
          .thenThrow(Exception('boom'));
      expect(
        await buildProvider().analyze('m1'),
        'Não foi possível analisar esta foto agora.',
      );
    });
  });

  group('Chats: mensagem real da cota e sem histórico do cliente', () {
    test('chat geral: grava só a pergunta, chama a IA só com a mensagem e '
        'mostra a mensagem da cota', () async {
      when(() => firestoreService.addChatMessage(any(), any()))
          .thenAnswer((_) async {});
      when(() => aiService.chat(message: any(named: 'message')))
          .thenThrow(const ValidationException(quotaMessage));
      final provider = ChatProvider(
        firestoreService: firestoreService,
        aiService: aiService,
      );

      await provider.sendMessage('u1', '  Oi  ');

      final saved =
          verify(() => firestoreService.addChatMessage('u1', captureAny()))
                  .captured
                  .single
              as ChatMessage;
      expect(saved.role, ChatRole.user);
      expect(saved.content, 'Oi');
      verify(() => aiService.chat(message: 'Oi')).called(1);
      expect(provider.error, quotaMessage);
      expect(provider.isSending, isFalse);
    });

    test(
      'chat geral: pergunta com mais de 2000 caracteres nem é enviada',
      () async {
        final provider = ChatProvider(
          firestoreService: firestoreService,
          aiService: aiService,
        );

        await provider.sendMessage('u1', 'x' * 2001);

        expect(provider.error, contains('2000'));
        verifyNever(() => firestoreService.addChatMessage(any(), any()));
        verifyNever(() => aiService.chat(message: any(named: 'message')));
      },
    );

    test('nutrição: mostra a mensagem da cota do servidor', () async {
      const message =
          'Você atingiu o limite de 10 perguntas ao assistente de nutrição '
          'deste mês do plano Básico. O limite renova no dia 1º.';
      when(() => firestoreService.addNutritionMessage('u1', any()))
          .thenAnswer((_) async {});
      when(() => aiService.askNutrition(message: any(named: 'message')))
          .thenThrow(const ValidationException(message));
      final provider = NutritionChatProvider(
        firestoreService: firestoreService,
        aiService: aiService,
      );

      await provider.ask('u1', 'Posso comer ovo?');

      expect(provider.error, message);
      verify(() => aiService.askNutrition(message: 'Posso comer ovo?'))
          .called(1);
    });

    test('sugestão de treino: mostra a mensagem do servidor', () async {
      when(
        () => aiService.suggestTrainingPlan(
          prompt: any(named: 'prompt'),
          studentUid: any(named: 'studentUid'),
        ),
      ).thenThrow(const AuthException('Esse aluno não está vinculado a você.'));
      final provider = InstructorAiProvider(aiService: aiService);

      await provider.ask(prompt: 'dor lombar', studentUid: 'a1');

      expect(provider.error, 'Esse aluno não está vinculado a você.');
    });
  });

  group('Cotas no app ("X de Y")', () {
    test('limites por plano iguais aos do servidor', () {
      expect(AiUsageLimits.forTier(PlanTier.basic).chatPerDay, 5);
      expect(AiUsageLimits.forTier(PlanTier.basic).nutritionPerMonth, 10);
      expect(AiUsageLimits.forTier(PlanTier.basic).mealPhotosPerMonth, 3);
      expect(AiUsageLimits.forTier(PlanTier.premium).chatPerDay, 20);
      expect(AiUsageLimits.forTier(PlanTier.premium).nutritionPerMonth, 60);
      expect(AiUsageLimits.forTier(PlanTier.premium).mealPhotosPerMonth, 60);
    });

    test('lê o mês (nutrição, fotos) e o dia (chat)', () {
      final usage = AiUsage.fromDocs(
        month: {'mealPhoto': 2, 'nutrition': 7},
        day: {'chat': 4},
      );
      expect(usage.mealPhotoCount, 2);
      expect(usage.nutritionCount, 7);
      expect(usage.chatTodayCount, 4);
      expect(AiUsage.fromDocs().chatTodayCount, 0);
    });

    test('períodos no fuso de São Paulo (vira à meia-noite de lá)', () {
      // 02:00 UTC de 1º/out = 23:00 de 30/set em São Paulo
      final lateNight = DateTime.utc(2026, 10, 1, 2);
      expect(aiUsageDayKey(lateNight), '2026-09-30');
      expect(aiUsageMonthKey(lateNight), '2026-09');
      final morning = DateTime.utc(2026, 10, 1, 4);
      expect(aiUsageDayKey(morning), '2026-10-01');
      expect(aiUsageMonthKey(morning), '2026-10');
    });
  });
}
