import 'dart:developer' as developer;

import 'package:logging/logging.dart';

/// Ponto único de configuração de logging do app. Em debug, tudo vai para o
/// console via `dart:developer`; é aqui que se plugaria um backend de
/// observabilidade (Crashlytics, Sentry, etc.) no futuro, sem tocar em quem
/// chama [AppLogger.of].
class AppLogger {
  AppLogger._();

  static bool _initialized = false;

  static void init({Level level = Level.INFO}) {
    if (_initialized) return;
    _initialized = true;

    Logger.root.level = level;
    Logger.root.onRecord.listen((record) {
      developer.log(
        record.message,
        time: record.time,
        level: record.level.value,
        name: record.loggerName,
        error: record.error,
        stackTrace: record.stackTrace,
      );
    });
  }

  /// Cria um logger nomeado (normalmente o nome da classe que o usa).
  static Logger of(String name) => Logger(name);
}
