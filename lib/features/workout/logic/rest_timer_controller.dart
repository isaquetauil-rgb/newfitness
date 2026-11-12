// Campos privados recebidos por parâmetros nomeados públicos (`alerts:`,
// `settings:`): o "initializing formal" sugerido não se aplica aqui.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';

/// Preferências do cronômetro de descanso (ver `RestTimerSettings` em
/// `LocalPrefs`).
class RestTimerSettings {
  const RestTimerSettings({
    this.autoStart = true,
    this.sound = true,
    this.vibration = true,
  });

  /// Começar o descanso sozinho ao marcar uma série como feita.
  final bool autoStart;

  /// Som na notificação de fim do descanso.
  final bool sound;

  /// Vibração no fim do descanso (no app e na notificação).
  final bool vibration;

  RestTimerSettings copyWith({bool? autoStart, bool? sound, bool? vibration}) =>
      RestTimerSettings(
        autoStart: autoStart ?? this.autoStart,
        sound: sound ?? this.sound,
        vibration: vibration ?? this.vibration,
      );
}

/// Avisos do fim do descanso fora da lógica: notificação local (que chega
/// com o app fechado) e vibração (com o app aberto).
abstract class RestAlerts {
  Future<void> scheduleEnd(DateTime at, RestTimerSettings settings);
  Future<void> cancelEnd();
  void vibrate();
}

/// Sem avisos (testes e plataformas sem notificação).
class SilentRestAlerts implements RestAlerts {
  const SilentRestAlerts();
  @override
  Future<void> scheduleEnd(DateTime at, RestTimerSettings settings) async {}
  @override
  Future<void> cancelEnd() async {}
  @override
  void vibrate() {}
}

/// Cronômetro de descanso entre séries.
///
/// Guarda o HORÁRIO DE FIM, e não um contador: o tempo restante é sempre
/// `fim - agora`, então continua certo com o app em segundo plano ou a tela
/// bloqueada (quando um `Timer` do Dart para de rodar). No fim, vibra (se o
/// app está aberto) e a notificação agendada avisa com o app fechado.
/// Pular ou ajustar o tempo cancela ou reagenda essa notificação.
class RestTimerController extends ChangeNotifier {
  RestTimerController({
    RestAlerts alerts = const SilentRestAlerts(),
    RestTimerSettings settings = const RestTimerSettings(),
    DateTime Function()? now,
  }) : _alerts = alerts,
       _settings = settings,
       _now = now ?? DateTime.now;

  final RestAlerts _alerts;
  final DateTime Function() _now;
  RestTimerSettings _settings;

  DateTime? _endsAt;
  int _totalSeconds = 0;
  int? _pausedRemaining;
  Timer? _endTimer;

  /// Tolerância para vibrar ao detectar o fim atrasado (app voltou do
  /// segundo plano bem depois do fim: aí a notificação já avisou).
  static const lateAlertWindow = Duration(seconds: 3);

  RestTimerSettings get settings => _settings;
  DateTime? get endsAt => _endsAt;
  int get totalSeconds => _totalSeconds;

  /// Há descanso contando ou pausado?
  bool get isActive => _endsAt != null || _pausedRemaining != null;
  bool get isRunning => _endsAt != null;
  bool get isPaused => _pausedRemaining != null;

  /// Segundos que faltam (arredondado para cima: "0:01" até acabar).
  int get remainingSeconds {
    final paused = _pausedRemaining;
    if (paused != null) return paused;
    final ends = _endsAt;
    if (ends == null) return 0;
    final ms = ends.difference(_now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  /// Fração restante, de 1 (começou) a 0 (acabou).
  double get progress =>
      _totalSeconds <= 0 ? 0 : (remainingSeconds / _totalSeconds).clamp(0, 1);

  void updateSettings(RestTimerSettings settings) {
    _settings = settings;
    notifyListeners();
  }

  /// Série marcada como feita: começa o descanso se o início automático
  /// estiver ligado.
  void onSetCompleted(int restSeconds) {
    if (_settings.autoStart) start(restSeconds);
  }

  /// Começa (ou recomeça) um descanso de [seconds].
  void start(int seconds) {
    if (seconds <= 0) return;
    _pausedRemaining = null;
    _totalSeconds = seconds;
    _setEnd(_now().add(Duration(seconds: seconds)));
    notifyListeners();
  }

  /// Soma (ou tira, se negativo) segundos do descanso em andamento. Se o
  /// tempo acabar com o ajuste, o descanso termina sem alarme.
  void adjust(int deltaSeconds) {
    final paused = _pausedRemaining;
    if (paused != null) {
      final next = paused + deltaSeconds;
      if (next <= 0) return skip();
      _pausedRemaining = next;
      if (next > _totalSeconds) _totalSeconds = next;
      notifyListeners();
      return;
    }
    final ends = _endsAt;
    if (ends == null) return;
    final next = ends.add(Duration(seconds: deltaSeconds));
    if (!next.isAfter(_now())) return skip();
    final remaining = next.difference(_now()).inSeconds;
    if (remaining > _totalSeconds) _totalSeconds = remaining;
    _setEnd(next);
    notifyListeners();
  }

  /// Para o relógio guardando o que falta; a notificação é cancelada.
  void pause() {
    if (_endsAt == null) return;
    _pausedRemaining = remainingSeconds;
    _clearEnd();
    notifyListeners();
  }

  void resume() {
    final paused = _pausedRemaining;
    if (paused == null) return;
    _pausedRemaining = null;
    _setEnd(_now().add(Duration(seconds: paused)));
    notifyListeners();
  }

  /// Encerra sem alarme (Pular, cancelar ou finalizar o treino).
  void skip() {
    if (!isActive) return;
    _pausedRemaining = null;
    _clearEnd();
    notifyListeners();
  }

  /// Confere se o descanso acabou (a tela chama ao redesenhar e ao voltar do
  /// segundo plano). Devolve `true` se acabou agora.
  bool checkFinished() {
    final ends = _endsAt;
    if (ends == null) return false;
    final now = _now();
    if (now.isBefore(ends)) return false;
    _finish(late: now.difference(ends) > lateAlertWindow);
    return true;
  }

  void _finish({bool late = false}) {
    _endTimer?.cancel();
    _endTimer = null;
    _endsAt = null;
    _pausedRemaining = null;
    // A notificação agendada cuida do aviso sonoro; aqui só a vibração do
    // app aberto. Atrasado demais (app estava fechado), não vibra.
    if (_settings.vibration && !late) _alerts.vibrate();
    notifyListeners();
  }

  void _setEnd(DateTime at) {
    _endsAt = at;
    _endTimer?.cancel();
    _endTimer = Timer(at.difference(_now()), checkFinished);
    unawaited(_alerts.scheduleEnd(at, _settings).catchError((Object _) {}));
  }

  void _clearEnd() {
    _endTimer?.cancel();
    _endTimer = null;
    _endsAt = null;
    unawaited(_alerts.cancelEnd().catchError((Object _) {}));
  }

  @override
  void dispose() {
    _endTimer?.cancel();
    super.dispose();
  }
}
