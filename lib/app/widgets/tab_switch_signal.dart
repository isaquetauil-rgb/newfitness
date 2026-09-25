import 'package:flutter/foundation.dart';

/// Sinal para pedir a uma tela com abas (ex.: IA, Progresso) que mude para
/// uma aba específica ao ser aberta pelo menu lateral.
///
/// Necessário porque o `StatefulShellRoute` mantém cada aba viva num
/// `IndexedStack` — navegar de novo pra uma aba já visitada não reconstrói
/// a tela, então um `initialIndex` sozinho não bastaria para forçar a troca.
class TabSwitchSignal {
  TabSwitchSignal._();

  static final ValueNotifier<int?> ai = ValueNotifier<int?>(null);
  static final ValueNotifier<int?> progress = ValueNotifier<int?>(null);
}
