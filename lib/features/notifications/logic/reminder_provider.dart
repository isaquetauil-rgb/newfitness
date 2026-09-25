import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/features/notifications/data/notification_service.dart';
import 'package:newfitness/shared/models/reminder.dart';
import 'package:newfitness/shared/services/firestore_service.dart';

/// Mantém a lista de lembretes do usuário sincronizada entre o Firestore
/// (fonte de verdade / backup) e o agendamento local de notificações
/// (o que efetivamente dispara o alerta no celular).
class ReminderProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;
  final NotificationService _notificationService;
  StreamSubscription<List<Reminder>>? _sub;
  String? _uid;

  ReminderProvider({
    FirestoreService? firestoreService,
    NotificationService? notificationService,
  }) : _firestoreService = firestoreService ?? getIt<FirestoreService>(),
       _notificationService =
           notificationService ?? getIt<NotificationService>();

  List<Reminder> _reminders = [];
  List<Reminder> get reminders => _reminders;

  List<Reminder> get waterReminders =>
      _reminders.where((r) => r.type == ReminderType.water).toList();

  List<Reminder> get supplementReminders =>
      _reminders.where((r) => r.type == ReminderType.supplement).toList();

  /// Deve ser chamado quando o usuário loga (ou troca de conta).
  void listenTo(String uid) {
    if (_uid == uid) return;
    _uid = uid;
    _sub?.cancel();
    _sub = _firestoreService.watchReminders(uid).listen(
      (list) async {
        _reminders = list;
        notifyListeners();
        // Reagenda todas as notificações para refletir o estado atual
        // (cobre alterações feitas em outro dispositivo, por exemplo).
        for (final r in list) {
          await _notificationService.scheduleReminder(r);
        }
      },
      // Ex: permissão negada no logout — sem isso o erro ficava sem dono.
      onError: (Object _) {},
    );
  }

  /// Chamado ao sair da conta (ver `app.dart`): para de ouvir, esquece a
  /// lista e cancela as notificações agendadas neste aparelho. Antes nada
  /// chamava isto: ao entrar de novo com a MESMA conta, [listenTo] via o
  /// mesmo uid e não reassinava (a lista parava de atualizar), e ao entrar
  /// com OUTRA conta os lembretes da anterior continuavam tocando.
  Future<void> clear() async {
    await _sub?.cancel();
    _sub = null;
    _uid = null;
    _reminders = [];
    notifyListeners();
    await _notificationService.cancelAll();
  }

  Future<bool> requestNotificationPermission() {
    return _notificationService.requestPermission();
  }

  Future<void> addOrUpdateReminder(String uid, Reminder reminder) async {
    final id = await _firestoreService.saveReminder(uid, reminder);
    final saved = Reminder(
      id: id,
      type: reminder.type,
      label: reminder.label,
      dosage: reminder.dosage,
      hour: reminder.hour,
      minute: reminder.minute,
      enabled: reminder.enabled,
    );
    await _notificationService.scheduleReminder(saved);
  }

  Future<void> toggleReminder(String uid, Reminder reminder) async {
    final updated = reminder.copyWith(enabled: !reminder.enabled);
    await _firestoreService.saveReminder(uid, updated);
    if (updated.enabled) {
      await _notificationService.scheduleReminder(updated);
    } else {
      await _notificationService.cancelReminder(updated);
    }
  }

  Future<void> deleteReminder(String uid, Reminder reminder) async {
    await _notificationService.cancelReminder(reminder);
    await _firestoreService.deleteReminder(uid, reminder.id);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
