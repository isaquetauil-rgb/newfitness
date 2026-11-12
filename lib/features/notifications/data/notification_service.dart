import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, visibleForTesting;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:newfitness/core/logging/app_logger.dart';
import 'package:newfitness/shared/models/reminder.dart';

final _log = AppLogger.of('NotificationService');

/// Encapsula as notificações locais: lembretes diários (água e suplemento)
/// e avisos pontuais (fim do descanso). Cada [Reminder] vira uma notificação
/// que se repete todo dia no mesmo horário até ser cancelada ou desativada.
///
/// Android: usa alarme exato quando o sistema permite
/// (`SCHEDULE_EXACT_ALARM`, que o usuário pode negar — no Android 14+ vem
/// negada por padrão). Sem a permissão, agenda no modo inexato: a
/// notificação pode atrasar alguns minutos, mas chega e o app não trava.
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

  /// Canais das versões anteriores, apagados no [init]. O Android não deixa
  /// mudar som/vibração de um canal já criado (o de lembretes saiu sem som em
  /// alguns aparelhos), então os canais novos têm IDs novos.
  @visibleForTesting
  static const oldChannelIds = [
    'reminders_channel',
    'rest_timer_sound_vibration',
    'rest_timer_sound',
    'rest_timer_vibration',
    'rest_timer_silent',
  ];

  static const _reminderDescription =
      'Lembretes de água e suplementos do NewFitness';

  /// Vibra três vezes, para ser notado com o celular no bolso.
  static final _vibrationPattern = Int64List.fromList([
    0,
    500,
    300,
    500,
    300,
    500,
  ]);

  /// Som e vibração das notificações (Configurações). Valem para lembretes
  /// e para o fim do descanso; mudar exige reagendar os lembretes.
  bool _sound = true;
  bool _vibration = true;

  void setPreferences({required bool sound, required bool vibration}) {
    _sound = sound;
    _vibration = vibration;
  }

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get _isApple =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

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
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        macOS: iosSettings,
      ),
    );
    if (_isAndroid) {
      for (final id in oldChannelIds) {
        try {
          await _android?.deleteNotificationChannel(id);
        } catch (_) {}
      }
    }

    _initialized = true;
  }

  /// Pede permissão de notificação ao usuário (Android 13+ e iOS). Em
  /// Android mais antigo a permissão já vem concedida. No Web, sempre
  /// `false`. Nunca lança: em erro devolve `false`.
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    try {
      await init();
      if (_isAndroid) {
        return await _android?.requestNotificationsPermission() ?? false;
      }
      if (_isApple) {
        final ios = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        final mac = _plugin
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >();
        return await (ios?.requestPermissions(
                  alert: true,
                  badge: true,
                  sound: true,
                ) ??
                mac?.requestPermissions(
                  alert: true,
                  badge: true,
                  sound: true,
                )) ??
            false;
      }
      return false;
    } catch (e, st) {
      _log.warning('Falha ao pedir permissão de notificação', e, st);
      return false;
    }
  }

  /// O Android deixa agendar no horário exato? `null` fora do Android.
  Future<bool?> _canScheduleExact() async {
    if (!_isAndroid) return null;
    try {
      return await _android?.canScheduleExactNotifications();
    } catch (_) {
      return false;
    }
  }

  /// Agenda pelo modo escolhido e, se o Android recusar o exato (permissão
  /// revogada entre a checagem e o agendamento), tenta de novo no inexato.
  Future<void> _schedule(
    Future<void> Function(AndroidScheduleMode mode) schedule,
  ) async {
    await scheduleWithFallback(schedule, await _canScheduleExact());
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

    await _schedule(
      (mode) => _plugin.zonedSchedule(
        reminder.notificationId,
        title,
        body,
        _nextInstanceOf(reminder.hour, reminder.minute),
        _details(
          NotificationKind.reminder,
          sound: _sound,
          vibration: _vibration,
        ),
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // repete todo dia
      ),
    );
  }

  /// Id fixo da notificação de fim do descanso: só existe uma por vez, e
  /// reagendar com o mesmo id substitui a anterior.
  static const restEndNotificationId = 900001;

  /// Detalhes da notificação no canal certo para o tipo e para o som e a
  /// vibração escolhidos (os canais do Android não mudam depois de criados,
  /// por isso há um para cada combinação).
  NotificationDetails _details(
    NotificationKind kind, {
    required bool sound,
    required bool vibration,
  }) {
    final channel = channelFor(kind, sound: sound, vibration: vibration);
    final rest = kind == NotificationKind.rest;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: rest
            ? 'Aviso de fim do descanso entre séries'
            : _reminderDescription,
        importance: rest ? Importance.max : Importance.high,
        priority: rest ? Priority.max : Priority.high,
        category: rest
            ? AndroidNotificationCategory.alarm
            : AndroidNotificationCategory.reminder,
        playSound: sound,
        enableVibration: vibration,
        vibrationPattern: vibration ? _vibrationPattern : null,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentList: true,
        presentSound: sound,
        interruptionLevel: rest
            ? InterruptionLevel.timeSensitive
            : InterruptionLevel.active,
      ),
    );
  }

  /// Avisa o fim do descanso em [at], mesmo com o app fechado.
  Future<void> scheduleRestEnd(
    DateTime at, {
    required bool sound,
    required bool vibration,
  }) async {
    if (kIsWeb) return;
    await init();
    await _schedule(
      (mode) => _plugin.zonedSchedule(
        restEndNotificationId,
        'Descanso acabou',
        'Hora da próxima série 💪',
        tz.TZDateTime.from(at, tz.UTC),
        _details(NotificationKind.rest, sound: sound, vibration: vibration),
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      ),
    );
  }

  Future<void> cancelRestEnd() async {
    if (kIsWeb) return;
    await _plugin.cancel(restEndNotificationId);
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

enum NotificationKind { reminder, rest }

/// Canal do Android para o tipo de aviso e a combinação de som e vibração:
/// "lembretes" (importância alta) e "descanso" (importância máxima), com
/// som padrão e vibração quando ligados nas configurações.
@visibleForTesting
({String id, String name}) channelFor(
  NotificationKind kind, {
  required bool sound,
  required bool vibration,
}) {
  final (base, label) = switch (kind) {
    NotificationKind.reminder => ('lembretes', 'Lembretes'),
    NotificationKind.rest => ('descanso', 'Fim do descanso'),
  };
  final (suffix, detail) = switch ((sound, vibration)) {
    (true, true) => ('som_vibracao', ''),
    (true, false) => ('som', ' (só som)'),
    (false, true) => ('vibracao', ' (só vibração)'),
    (false, false) => ('silencioso', ' (silencioso)'),
  };
  return (id: '${base}_$suffix', name: '$label$detail');
}

/// Modo de agendamento no Android: exato só quando o sistema permite.
/// `null` (fora do Android ou sem resposta) usa o exato, que no iOS é
/// ignorado.
@visibleForTesting
AndroidScheduleMode scheduleModeFor(bool? canScheduleExact) =>
    canScheduleExact == false
    ? AndroidScheduleMode.inexactAllowWhileIdle
    : AndroidScheduleMode.exactAllowWhileIdle;

/// Agenda no modo de [scheduleModeFor]; se o Android recusar o alarme exato
/// (`exact_alarms_not_permitted` ou `SecurityException`), repete no modo
/// inexato em vez de deixar o erro subir e travar o fluxo.
@visibleForTesting
Future<void> scheduleWithFallback(
  Future<void> Function(AndroidScheduleMode mode) schedule,
  bool? canScheduleExact,
) async {
  final mode = scheduleModeFor(canScheduleExact);
  try {
    await schedule(mode);
  } on PlatformException catch (e) {
    final exactRefused =
        e.code == 'exact_alarms_not_permitted' ||
        '${e.message}'.contains('SCHEDULE_EXACT_ALARM') ||
        '${e.message}'.contains('SecurityException');
    if (mode == AndroidScheduleMode.inexactAllowWhileIdle || !exactRefused) {
      rethrow;
    }
    _log.info('Alarme exato negado; agendando no modo inexato');
    await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
  }
}
