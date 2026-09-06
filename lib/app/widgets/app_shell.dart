import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_drawer.dart';

/// Chave do `Scaffold` que hospeda o [Drawer] do app — usada por
/// [DrawerMenuButton] (em `drawer_menu_button.dart`) pra abrir o menu a
/// partir de qualquer tela de aba, já que cada uma tem seu próprio
/// `Scaffold`/`AppBar` e `Scaffold.of(context)` dentro delas não alcança
/// este aqui.
final appShellScaffoldKey = GlobalKey<ScaffoldState>();

/// Casca de navegação montada sobre o [StatefulShellRoute] do go_router —
/// cada aba mantém sua própria pilha de navegação. A navegação em si é
/// feita pelo [AppDrawer] (menu lateral); esta tela só hospeda o `body`
/// (a aba atual) e o `drawer`.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: appShellScaffoldKey,
      drawer: AppDrawer(navigationShell: navigationShell),
      body: navigationShell,
    );
  }
}
