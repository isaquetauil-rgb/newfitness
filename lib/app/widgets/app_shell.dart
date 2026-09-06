import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/shared/models/user_profile.dart';

/// Índices fixos dos branches condicionais dentro do [StatefulShellRoute]
/// — só aparecem na barra inferior conforme o papel/permissão do usuário
/// logado (instrutor / dono do app).
const _instructorBranchIndex = 6;
const _adminBranchIndex = 7;
const _profileBranchIndex = 8;

/// Casca de navegação por abas (bottom nav) montada sobre o
/// [StatefulShellRoute] do go_router — cada aba mantém sua própria pilha de
/// navegação. Substitui o antigo `home_screen.dart`, que fazia isso na mão
/// com um `IndexedStack` e uma lista de telas que precisava ficar
/// manualmente sincronizada com a lista de itens da barra.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isInstructor = auth.profile?.role == UserRole.instructor;
    final isAdmin = auth.isAdmin;

    final visibleBranches = [
      0,
      1,
      2,
      3,
      4,
      5,
      if (isInstructor) _instructorBranchIndex,
      if (isAdmin) _adminBranchIndex,
      _profileBranchIndex,
    ];

    final items = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined),
        label: 'Início',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.fitness_center),
        label: 'Treino',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.list_alt),
        label: 'Exercícios',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.show_chart),
        label: 'Progresso',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.notifications_outlined),
        label: 'Lembretes',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.smart_toy_outlined),
        label: 'IA',
      ),
      if (isInstructor)
        const BottomNavigationBarItem(
          icon: Icon(Icons.groups_outlined),
          label: 'Alunos',
        ),
      if (isAdmin)
        const BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings_outlined),
          label: 'Admin',
        ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person_outline),
        label: 'Perfil',
      ),
    ];

    final currentVisibleIndex = visibleBranches.indexOf(
      navigationShell.currentIndex,
    );
    final safeIndex = currentVisibleIndex == -1 ? 0 : currentVisibleIndex;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: safeIndex,
        onTap: (tappedIndex) => navigationShell.goBranch(
          visibleBranches[tappedIndex],
          initialLocation:
              visibleBranches[tappedIndex] == navigationShell.currentIndex,
        ),
        items: items,
      ),
    );
  }
}
