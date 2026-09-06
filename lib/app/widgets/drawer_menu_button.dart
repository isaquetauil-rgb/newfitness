import 'package:flutter/material.dart';

import 'app_shell.dart';

/// Botão de hambúrguer que abre o [Drawer] do [AppShell] a partir de
/// qualquer tela de aba — cada aba tem seu próprio `Scaffold`/`AppBar`
/// (não um só compartilhado), então `Scaffold.of(context)` dentro dela
/// encontraria o `Scaffold` da própria aba, não o do shell. Por isso usa a
/// `GlobalKey` exposta por `app_shell.dart` diretamente.
///
/// Uso: `AppBar(leading: const DrawerMenuButton(), ...)`.
class DrawerMenuButton extends StatelessWidget {
  const DrawerMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.menu),
      tooltip: 'Menu',
      onPressed: () => appShellScaffoldKey.currentState?.openDrawer(),
    );
  }
}
