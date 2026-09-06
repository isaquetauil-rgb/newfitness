import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:newfitness/features/notifications/logic/reminder_provider.dart';
import 'package:newfitness/shared/models/reminder.dart';

import '../helpers/mocks.dart';

void main() {
  late MockFirestoreService firestoreService;
  late MockNotificationService notificationService;
  late StreamController<List<Reminder>> remindersController;
  late ReminderProvider provider;

  setUpAll(registerTestFallbackValues);

  setUp(() {
    firestoreService = MockFirestoreService();
    notificationService = MockNotificationService();
    remindersController = StreamController<List<Reminder>>.broadcast();
    when(() => firestoreService.watchReminders(any()))
        .thenAnswer((_) => remindersController.stream);
    when(() => notificationService.scheduleReminder(any()))
        .thenAnswer((_) async {});
    when(() => notificationService.cancelReminder(any()))
        .thenAnswer((_) async {});
    provider = ReminderProvider(
      firestoreService: firestoreService,
      notificationService: notificationService,
    );
  });

  tearDown(() => remindersController.close());

  const reminder = Reminder(
    id: 'r1',
    type: ReminderType.water,
    label: 'Água',
    hour: 8,
    minute: 0,
  );

  test('listenTo agenda notificações para os lembretes recebidos', () async {
    provider.listenTo('u1');
    remindersController.add([reminder]);
    await Future<void>.delayed(Duration.zero);

    expect(provider.reminders, [reminder]);
    verify(() => notificationService.scheduleReminder(reminder)).called(1);
  });

  test('toggleReminder desativado salva e cancela a notificação', () async {
    when(() => firestoreService.saveReminder(any(), any()))
        .thenAnswer((_) async => 'r1');

    await provider.toggleReminder('u1', reminder);

    final saved =
        verify(() => firestoreService.saveReminder('u1', captureAny()))
                .captured
                .single
            as Reminder;
    expect(saved.enabled, isFalse);
    verify(() => notificationService.cancelReminder(any())).called(1);
  });

  test(
    'deleteReminder cancela a notificação antes de remover do Firestore',
    () async {
      when(() => firestoreService.deleteReminder(any(), any()))
          .thenAnswer((_) async {});

      await provider.deleteReminder('u1', reminder);

      verify(() => notificationService.cancelReminder(reminder)).called(1);
      verify(() => firestoreService.deleteReminder('u1', 'r1')).called(1);
    },
  );
}
