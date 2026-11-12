import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Esconde a barra de navegação do Android (os botões "|||  ○  <") enquanto
/// o app está aberto, mantendo a barra de status (hora e bateria) visível.
///
/// Se o aluno puxar a barra (gesto na borda de baixo), ela aparece e some
/// sozinha de novo depois de alguns segundos. A barra do teclado não é
/// controlada pelo app.
class SystemBars {
  SystemBars._();

  static const _hideAgainAfter = Duration(seconds: 3);
  static Timer? _timer;

  static Future<void> hideNavigationBar() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await _apply();
    await SystemChrome.setSystemUIChangeCallback((barsVisible) async {
      if (!barsVisible) return;
      _timer?.cancel();
      _timer = Timer(_hideAgainAfter, _apply);
    });
  }

  static Future<void> _apply() => SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: const [SystemUiOverlay.top],
  );
}
