import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/app/routes/app_routes.dart';
import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/instructor/presentation/ai_suggestion_sheet.dart';
import 'package:newfitness/features/notifications/logic/reminder_provider.dart';
import 'package:newfitness/features/workout/logic/workout_provider.dart';
import 'package:newfitness/shared/models/user_profile.dart';
import 'package:newfitness/shared/services/firestore_service.dart';

/// Aba inicial — layout diferente por papel:
///  - Aluno: resumo do que já existe nos outros providers (nenhuma leitura
///    nova de backend) — saudação, treino em andamento, lembretes de hoje
///    e atalhos para as outras abas.
///  - Instrutor: número de alunos vinculados, atalho para a lista de
///    alunos e acesso direto ao assistente de IA geral.
class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthProvider>().user?.uid;
      if (uid != null) {
        context.read<ReminderProvider>().listenTo(uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    final isInstructor = profile?.role == UserRole.instructor;

    return Scaffold(
      appBar: AppBar(title: const Text('NewFitness')),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: isInstructor
            ? _InstructorHomeBody(
                key: ValueKey(profile?.uid),
                profile: profile!,
              )
            : _StudentHomeBody(key: ValueKey(profile?.uid), profile: profile),
      ),
    );
  }
}

class _StudentHomeBody extends StatelessWidget {
  const _StudentHomeBody({super.key, required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final workout = context.watch<WorkoutProvider>();
    final reminders = context.watch<ReminderProvider>();
    final enabledReminders = reminders.reminders.where((r) => r.enabled).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Olá, ${profile?.name.split(' ').first ?? 'atleta'} 👋',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Vamos continuar sua evolução hoje.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 20),
        _WorkoutCard(hasActive: workout.hasActiveWorkout),
        const SizedBox(height: 12),
        _RemindersCard(count: enabledReminders),
        const SizedBox(height: 20),
        const Text('Atalhos', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _ShortcutChip(
              icon: Icons.list_alt,
              label: 'Exercícios',
              onTap: () => context.go(AppRoutes.exercises),
            ),
            _ShortcutChip(
              icon: Icons.show_chart,
              label: 'Progresso',
              onTap: () => context.go(AppRoutes.progress),
            ),
            _ShortcutChip(
              icon: Icons.smart_toy_outlined,
              label: 'IA',
              onTap: () => context.go(AppRoutes.ai),
            ),
          ],
        ),
      ],
    );
  }
}

class _InstructorHomeBody extends StatelessWidget {
  const _InstructorHomeBody({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Olá, ${profile.name.split(' ').first} 👋',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Acompanhe seus alunos e monte treinos com apoio de IA.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 20),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: getIt<FirestoreService>().watchStudents(profile.uid),
          builder: (context, snapshot) {
            final count = snapshot.data?.length ?? 0;
            return Card(
              child: ListTile(
                leading: Icon(
                  Icons.groups_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
                title: Text(
                  count == 0
                      ? 'Nenhum aluno vinculado'
                      : '$count aluno(s) vinculado(s)',
                ),
                subtitle: const Text('Toque para ver a lista de alunos.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go(AppRoutes.instructor),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: Icon(
              Icons.smart_toy_outlined,
              color: Theme.of(context).colorScheme.secondary,
              size: 32,
            ),
            title: const Text('Assistente de IA'),
            subtitle: const Text('Peça ideias de treino ou tire dúvidas.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showAiSuggestionSheet(context),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Atalhos', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _ShortcutChip(
              icon: Icons.groups_outlined,
              label: 'Meus alunos',
              onTap: () => context.go(AppRoutes.instructor),
            ),
            _ShortcutChip(
              icon: Icons.list_alt,
              label: 'Exercícios',
              onTap: () => context.go(AppRoutes.exercises),
            ),
          ],
        ),
      ],
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({required this.hasActive});

  final bool hasActive;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          hasActive ? Icons.play_circle_fill : Icons.fitness_center,
          color: Theme.of(context).colorScheme.primary,
          size: 32,
        ),
        title: Text(hasActive ? 'Treino em andamento' : 'Nenhum treino ativo'),
        subtitle: Text(
          hasActive
              ? 'Toque para continuar de onde parou.'
              : 'Comece um treino na aba Treino.',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go(AppRoutes.workout),
      ),
    );
  }
}

class _RemindersCard extends StatelessWidget {
  const _RemindersCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          Icons.notifications_active_outlined,
          color: Theme.of(context).colorScheme.secondary,
          size: 32,
        ),
        title: Text(
          count == 0 ? 'Nenhum lembrete ativo' : '$count lembrete(s) ativo(s)',
        ),
        subtitle: const Text('Água e suplementos do dia.'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go(AppRoutes.notifications),
      ),
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}
