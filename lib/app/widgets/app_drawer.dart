import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/app/routes/app_routes.dart';
import 'package:newfitness/app/theme/app_theme.dart';
import 'package:newfitness/app/widgets/tab_switch_signal.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/shared/models/user_profile.dart';

/// Menu lateral do app — substitui a antiga barra de navegação inferior.
/// Os itens que já são abas do [StatefulShellRoute] navegam via
/// `navigationShell.goBranch`; os demais (Timeline, Avaliação física,
/// Financeiro, Agenda) são telas cheias fora do shell, abertas via
/// `context.push`.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _goBranch(BuildContext context, int index) {
    Navigator.pop(context);
    navigationShell.goBranch(index);
  }

  void _goBranchTab(
    BuildContext context,
    int index,
    ValueNotifier<int?> tabSignal,
    int tabIndex,
  ) {
    tabSignal.value = tabIndex;
    _goBranch(context, index);
  }

  void _pushRoute(BuildContext context, String route) {
    Navigator.pop(context);
    context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;
    final isInstructor = profile?.role == UserRole.instructor;
    final isNutritionist = profile?.role == UserRole.nutritionist;
    final isAdmin = auth.isAdmin;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            _DrawerHeader(profile: profile),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _DrawerTile(
                    icon: Icons.home_outlined,
                    label: 'Início',
                    onTap: () => _goBranch(context, 0),
                  ),
                  _DrawerTile(
                    icon: Icons.fitness_center,
                    label: 'Treino',
                    color: AppTheme.trainingAccent,
                    onTap: () => _goBranch(context, 1),
                  ),
                  _DrawerTile(
                    icon: Icons.list_alt,
                    label: 'Exercícios',
                    onTap: () => _goBranch(context, 2),
                  ),
                  _DrawerTile(
                    icon: Icons.show_chart,
                    label: 'Progresso',
                    color: AppTheme.progressAccent,
                    onTap: () => _goBranch(context, 3),
                  ),
                  _DrawerTile(
                    icon: Icons.photo_camera_outlined,
                    label: 'Evoluções',
                    color: AppTheme.progressAccent,
                    onTap: () =>
                        _goBranchTab(context, 3, TabSwitchSignal.progress, 1),
                  ),
                  _DrawerTile(
                    icon: Icons.notifications_outlined,
                    label: 'Lembretes',
                    onTap: () => _goBranch(context, 4),
                  ),
                  _DrawerTile(
                    icon: Icons.smart_toy_outlined,
                    label: 'IA',
                    onTap: () => _goBranch(context, 5),
                  ),
                  _DrawerTile(
                    icon: Icons.restaurant_outlined,
                    label: 'Refeições',
                    color: AppTheme.progressAccent,
                    onTap: () =>
                        _goBranchTab(context, 5, TabSwitchSignal.ai, 1),
                  ),
                  if (isInstructor)
                    _DrawerTile(
                      icon: Icons.groups_outlined,
                      label: 'Alunos',
                      color: AppTheme.trainingAccent,
                      onTap: () => _goBranch(context, 6),
                    ),
                  if (isNutritionist)
                    _DrawerTile(
                      icon: Icons.groups_outlined,
                      label: 'Meus alunos (nutrição)',
                      color: AppTheme.progressAccent,
                      onTap: () => _goBranch(context, 9),
                    ),
                  if (isAdmin)
                    _DrawerTile(
                      icon: Icons.admin_panel_settings_outlined,
                      label: 'Admin',
                      onTap: () => _goBranch(context, 7),
                    ),
                  const Divider(),
                  _DrawerTile(
                    icon: Icons.forum_outlined,
                    label: 'Timeline',
                    onTap: () => _pushRoute(context, AppRoutes.timeline),
                  ),
                  _DrawerTile(
                    icon: Icons.event_outlined,
                    label: 'Agenda',
                    onTap: () => _pushRoute(context, AppRoutes.agenda),
                  ),
                  _DrawerTile(
                    icon: Icons.monitor_weight_outlined,
                    label: 'Evolução física',
                    color: AppTheme.progressAccent,
                    onTap: () =>
                        _pushRoute(context, AppRoutes.physicalAssessment),
                  ),
                  _DrawerTile(
                    icon: Icons.payments_outlined,
                    label: 'Financeiro',
                    onTap: () => _pushRoute(context, AppRoutes.finance),
                  ),
                  _DrawerTile(
                    icon: Icons.restaurant_menu_outlined,
                    label: 'Nutrição',
                    color: AppTheme.progressAccent,
                    onTap: () => _pushRoute(context, AppRoutes.nutrition),
                  ),
                  const Divider(),
                  _DrawerTile(
                    icon: Icons.person_outline,
                    label: 'Perfil',
                    onTap: () => _goBranch(context, 8),
                  ),
                  _DrawerTile(
                    icon: Icons.logout,
                    label: 'Sair',
                    onTap: () {
                      Navigator.pop(context);
                      context.read<AuthProvider>().signOut();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final name = profile?.name ?? '';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Text(
              initials,
              style: const TextStyle(fontSize: 22, color: Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            name.isEmpty ? 'Usuário' : name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
          if (profile?.email != null)
            Text(
              profile!.email,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Acento de módulo (ver [AppTheme.trainingAccent]/[AppTheme.progressAccent])
  /// — quando nulo, usa a cor padrão do tema (itens sem módulo próprio).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label),
      onTap: onTap,
    );
  }
}
