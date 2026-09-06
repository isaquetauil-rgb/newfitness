import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/widgets/error_view.dart';
import '../logging/app_logger.dart';

final _log = AppLogger.of('ErrorHandler');

/// Captura global de erros não tratados. Chame [ErrorHandler.init] uma vez,
/// antes de `runApp`, dentro do `runZonedGuarded` que envolve `main()`
/// (o `runZonedGuarded` cobre erros assíncronos fora do ciclo de build do
/// Flutter; o que está aqui cobre o resto: build/layout/paint e a engine).
class ErrorHandler {
  ErrorHandler._();

  static void init() {
    FlutterError.onError = (details) {
      _log.severe(
        details.exceptionAsString(),
        details.exception,
        details.stack,
      );
      FlutterError.presentError(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      _log.severe('Erro não tratado na plataforma', error, stack);
      return true;
    };

    ErrorWidget.builder = (details) => const ErrorView();
  }
}
