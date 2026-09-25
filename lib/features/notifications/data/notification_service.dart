import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:newfitness/shared/models/reminder.dart';

/// Encapsula o agendamento de notificações locais diárias (lembretes de
/// água e suplemento). Cada [Reminder] vira uma notificação que se repete
/// todo dia no mesmo horário até ser cancelada ou desativada.
///
/// `flutter_local_notifications` não tem implementação para Web — todos os
/// métodos viram no-op nessa plataforma (a lista de lembretes continua
/// funcionando normalmente via Firestore, só o alarme do sistema
/// operacional não dispara no navegador).
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const _channelId = 'reminders_channel';
  static const _channelName = 'Lembretes';
  static const _channelDescription =
      'Lembretes de água e suplementos do NewFitness';

  Future<void> init() async {
    if (kIsWeb || _initialized) return;

    tz_data.initializeTimeZones();
    // Usa o fuso horário local do dispositivo. Se sua base de usuários for
    // majoritariamente de uma região, você pode fixar com
    // tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
    tz.setLocalLocation(tz.local);

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    _initialized = true;
  }

  /// Pede permissão de notificação ao usuário (obrigatório no Android 13+ e no iOS).
  /// No Web, sempre retorna false — não há como agendar notificações locais lá.
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  Future<void> scheduleReminder(Reminder reminder) async {
    if (kIsWeb) return;
    await init();
    if (!reminder.enabled) {
      await cancelReminder(reminder);
      return;
    }

    final title = reminder.type == ReminderType.water
        ? '💧 Hora de beber água'
        : '💊 Hora do suplemento';
    final body = reminder.type == ReminderType.water
        ? reminder.label
        : '${reminder.label}${reminder.dosage != null ? ' · ${reminder.dosage}' : ''}';

    await _plugin.zonedSchedule(
      reminder.notificationId,
      title,
      body,
      _nextInstanceOf(reminder.hour, reminder.minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // repete todo dia
    );
  }

  Future<void> cancelReminder(Reminder reminder) async {
    if (kIsWeb) return;
    await _plugin.cancel(reminder.notificationId);
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await _plugin.cancelAll();
  }

  /// Próximo horário [hour]:[minute] no RELÓGIO DO APARELHO.
  ///
  /// `tz.local` do pacote `timezone` é UTC por padrão (o app não usa um
  /// plugin para descobrir o fuso do aparelho), então montar o horário
  /// direto em `tz.local` agendava "08:00" para 08:00 UTC — 05:00 no
  /// horário de Brasília. Aqui o horário é montado com o `DateTime` local
  /// e convertido para o mesmo instante; a repetição diária
  /// (`DateTimeComponents.time`) mantém esse horário todo dia. Limitação:
  /// em regiões com horário de verão o alarme desloca 1h após a troca até
  /// o próximo reagendamento (o app reagenda ao abrir).
  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    return nextLocalOccurrence(hour, minute, DateTime.now());
  }

  @visibleForTesting
  static tz.TZDateTime nextLocalOccurrence(int hour, int minute, DateTime now) {
    var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = DateTime(now.year, now.month, now.day + 1, hour, minute);
    }
    return tz.TZDateTime.from(scheduled, tz.UTC);
  }
}
