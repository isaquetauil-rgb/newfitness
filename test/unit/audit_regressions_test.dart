import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

import 'package:newfitness/core/error/app_exception.dart';
import 'package:newfitness/features/ai/logic/chat_provider.dart';
import 'package:newfitness/features/ai/logic/meal_photo_provider.dart';
import 'package:newfitness/features/instructor/presentation/custom_exercise_form_screen.dart';
import 'package:newfitness/features/notifications/data/notification_service.dart';
import 'package:newfitness/features/notifications/logic/reminder_provider.dart';
import 'package:newfitness/shared/models/chat_message.dart';
import 'package:newfitness/shared/models/meal_photo.dart';
import 'package:newfitness/shared/models/reminder.dart';

import '../helpers/mocks.dart';

/// Regressões encontradas na auditoria funcional/E2E — um teste por bug
/// corrigido que dá para exercitar sem aparelho.
void main() {
  setUpAll(() {
    registerTestFallbackValues();
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(
      MealPhoto(
        id: '',
        userId: '',
        date: DateTime(2024),
        mealType: MealType.values.first,
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
  });

  group('Lembretes: horário do aparelho', () {
    test('08:00 local vira o instante de 08:00 local (não 08:00 UTC)', () {
      final now = DateTime(2024, 6, 10, 7, 30);
      final at = NotificationService.nextLocalOccurrence(8, 0, now);
      final local = DateTime.fromMillisecondsSinceEpoch(
        at.millisecondsSinceEpoch,
      );
      expect(local, DateTime(2024, 6, 10, 8, 0));
    });

    test('horário que já passou hoje vai para amanhã', () {
      final now = DateTime(2024, 6, 10, 9, 0);
      final at = NotificationService.nextLocalOccurrence(8, 0, now);
      final local = DateTime.fromMillisecondsSinceEpoch(
        at.millisecondsSinceEpoch,
      );
      expect(local, DateTime(2024, 6, 11, 8, 0));
    });
  });

  group('Lembretes: troca de conta', () {
    late MockFirestoreService firestoreService;
    late MockNotificationService notificationService;
    late ReminderProvider provider;
    late int subscriptions;

    setUp(() {
      firestoreService = MockFirestoreService();
      notificationService = MockNotificationService();
      subscriptions = 0;
      when(() => firestoreService.watchReminders(any())).thenAnswer((_) {
        subscriptions++;
        return const Stream<List<Reminder>>.empty();
      });
      when(() => notificationService.cancelAll()).thenAnswer((_) async {});
      provider = ReminderProvider(
        firestoreService: firestoreService,
        notificationService: notificationService,
      );
    });

    test('clear cancela as notificações deste aparelho', () async {
      provider.listenTo('u1');
      await provider.clear();
      verify(() => notificationService.cancelAll()).called(1);
      expect(provider.reminders, isEmpty);
    });

    test('depois de sair, entrar de novo com a MESMA conta reassina', () async {
      provider.listenTo('u1');
      await provider.clear();
      provider.listenTo('u1');
      expect(subscriptions, 2);
    });
  });

  group('Vídeo de exercício próprio: extensão segura', () {
    test('usa o nome do arquivo, não o path (no Web o path é blob:)', () {
      expect(videoExtensionOf('treino.MP4'), 'mp4');
      expect(videoExtensionOf('IMG_0001.mov'), 'mov');
      expect(videoExtensionOf('video'), 'mp4');
      expect(videoExtensionOf('blob:http://localhost:5000/a1b2'), 'mp4');
      expect(videoExtensionOf('arquivo.x/../y'), 'mp4');
    });
  });

  group('Refeições: falha da análise não fica em "Analisando..."', () {
    test('grava o motivo quando a IA recusa (ex: limite do plano)', () async {
      final firestoreService = MockFirestoreService();
      final storageService = MockStorageService();
      final aiService = MockAiService();
      when(() => storageService.uploadMealPhoto('u1', any()))
          .thenAnswer((_) async => 'https://x/meal.jpg');
      when(() => firestoreService.addMealPhoto(any()))
          .thenAnswer((_) async => 'm1');
      when(
        () => aiService.analyzeMealPhoto(
          imageBytes: any(named: 'imageBytes'),
          mealType: any(named: 'mealType'),
        ),
      ).thenThrow(const ValidationException('Você atingiu o limite.'));
      when(
        () => firestoreService.markMealPhotoAnalysisFailed(any(), any(), any()),
      ).thenAnswer((_) async {});

      final provider = MealPhotoProvider(
        firestoreService: firestoreService,
        storageService: storageService,
        aiService: aiService,
      );
      await provider.addPhoto(
        'u1',
        XFile.fromData(Uint8List.fromList([1, 2, 3])),
        MealType.values.first,
      );

      verify(
        () => firestoreService.markMealPhotoAnalysisFailed(
          'u1',
          'm1',
          'Você atingiu o limite.',
        ),
      ).called(1);
      expect(provider.isUploading, isFalse);
    });

    test('documento antigo sem o campo continua lendo normalmente', () {
      final meal = MealPhoto.fromMap('m', {
        'userId': 'u1',
        'date': 1,
        'mealType': MealType.values.first.name,
        'imageUrl': 'x',
        'aiAnalysis': null,
      });
      expect(meal.aiAnalysisError, isNull);
    });
  });

  group('Chat geral: falha ao salvar a pergunta não trava o botão', () {
    test('sending volta a false e mostra erro', () async {
      final firestoreService = MockFirestoreService();
      final aiService = MockAiService();
      when(() => firestoreService.addChatMessage(any(), any()))
          .thenThrow(Exception('permission-denied'));
      final provider = ChatProvider(
        firestoreService: firestoreService,
        aiService: aiService,
      );

      await provider.sendMessage('u1', 'Oi', const []);

      expect(provider.isSending, isFalse);
      expect(provider.error, isNotNull);
    });
  });
}
