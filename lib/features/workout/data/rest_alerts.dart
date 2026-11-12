import 'package:flutter/services.dart';

import 'package:newfitness/features/notifications/data/notification_service.dart';
import 'package:newfitness/features/workout/logic/rest_timer_controller.dart';

/// Avisos reais do fim do descanso: notificação local agendada (chega com o
/// app fechado) e vibração do aparelho com o app aberto. Pede a permissão
/// de notificação na primeira vez que um descanso começa.
class LocalRestAlerts implements RestAlerts {
  LocalRestAlerts(this._notifications);

  final NotificationService _notifications;
  bool _askedPermission = false;

  @override
  Future<void> scheduleEnd(DateTime at, RestTimerSettings settings) async {
    if (!_askedPermission) {
      _askedPermission = true;
      await _notifications.requestPermission();
    }
    await _notifications.scheduleRestEnd(
      at,
      sound: settings.sound,
      vibration: settings.vibration,
    );
  }

  @override
  Future<void> cancelEnd() => _notifications.cancelRestEnd();

  @override
  void vibrate() {
    HapticFeedback.vibrate();
  }
}
