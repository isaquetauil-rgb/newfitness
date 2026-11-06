import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/app/routes/app_routes.dart';
import 'package:newfitness/app/widgets/drawer_menu_button.dart';
import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/home/logic/week_summary.dart';
import 'package:newfitness/features/instructor/presentation/ai_suggestion_sheet.dart';
import 'package:newfitness/features/notifications/logic/reminder_provider.dart';
import 'package:newfitness/features/workout/logic/training_plan_provider.dart';
import 'package:newfitness/features/workout/logic/workout_provider.dart';
import 'package:newfitness/features/workout/presentation/workout_templates_screen.dart';
import 'package:newfitness/shared/models/training_plan.dart';
import 'package:newfitness/shared/models/user_profile.dart';
import 'package:newfitness/shared/models/workout.dart';
import 'package:newfitness/shared/models/workout_templates.dart';
import 'package:newfitness/shared/services/firestore_service.dart';

/// Aba inicial — layout diferente por papel:
///  - Aluno: próxima ação, resumo da semana, último treino, treinos prontos
///    e atalhos para as outras áreas.
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
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('NewFitness'),
      ),
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

class _StudentHomeBody extends StatefulWidget {
  const _StudentHomeBody({super.key, required this.profile});

  final UserProfile? profile;

  @override
  State<_StudentHomeBody> createState() => _StudentHomeBodyState();
}

class _StudentHomeBodyState extends State<_StudentHomeBody> {
  // Guardados para não recriar as consultas a cada reconstrução.
  late final Stream<List<Workout>> _history;
  late final Stream<List<TrainingPlan>> _plans;

  @override
  void initState() {
    super.initState();
    final uid = widget.profile?.uid;
    _history = uid == null
        ? const Stream.empty()
        : context.read<WorkoutProvider>().watchHistory(uid);
    _plans = uid == null
        ? const Stream.empty()
        : context.read<TrainingPlanProvider>().watchPlans(uid);
  }

  @override
  Widget build(BuildContext context) {
    final hasActive = context.watch<WorkoutProvider>().hasActiveWorkout;
    final reminders = context.watch<ReminderProvider>();
    final enabledReminders = reminders.reminders.where((r) => r.enabled).length;
    final name = widget.profile?.name.split(' ').first ?? 'atleta';

    return StreamBuilder<List<Workout>>(
      stream: _history,
      builder: (context, historySnapshot) {
        final workouts = historySnapshot.data ?? const <Workout>[];
        final loaded = historySnapshot.hasData;
        final week = WeekSummary.from(workouts, DateTime.now());

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Olá, $name 👋',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              week.workoutsThisWeek == 0
                  ? 'Veja por onde continuar hoje.'
                  : 'Você já treinou ${week.workoutsThisWeek}x esta semana.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<TrainingPlan>>(
              stream: _plans,
              builder: (context, plansSnapshot) => _NextStepCard(
                hasActive: hasActive,
                plans: plansSnapshot.data ?? const [],
                lastWorkout: workouts.isEmpty ? null : workouts.first,
                uid: widget.profile?.uid,
              ),
            ),
            const SizedBox(height: 12),
            _WeekCard(week: week),
            if (loaded && workouts.isEmpty) ...[
              const SizedBox(height: 12),
              _GettingStartedCard(hasReminders: enabledReminders > 0),
            ] else if (workouts.isNotEmpty) ...[
              const SizedBox(height: 12),
              _LastWorkoutCard(workout: workouts.first),
            ],
            const SizedBox(height: 20),
            _SectionHeader(
              title: 'Treinos prontos',
              actionLabel: 'Ver todos',
              onAction: () => context.push(AppRoutes.workoutTemplates),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 136,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: workoutTemplates.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) =>
                    _TemplateCard(template: workoutTemplates[index]),
              ),
            ),
            const SizedBox(height: 20),
            const _SectionHeader(title: 'Explorar'),
            const SizedBox(height: 8),
            const _ExploreGrid(),
            const SizedBox(height: 12),
            _RemindersCard(count: enabledReminders),
          ],
        );
      },
    );
  }
}

/// Sempre mostra uma única próxima ação, para ninguém abrir o app sem saber
/// para onde ir.
class _NextStepCard extends StatelessWidget {
  const _NextStepCard({
    required this.hasActive,
    required this.plans,
    required this.lastWorkout,
    required this.uid,
  });

  final bool hasActive;
  final List<TrainingPlan> plans;
  final Workout? lastWorkout;
  final String? uid;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF14171A);
    final String title;
    final String subtitle;
    final String action;
    final VoidCallback onPressed;
    final last = lastWorkout;

    if (hasActive) {
      title = 'Treino em andamento';
      subtitle = 'Continue de onde você parou.';
      action = 'Continuar treino';
      onPressed = () => context.go(AppRoutes.workout);
    } else if (plans.isNotEmpty) {
      title = plans.first.title;
      subtitle = 'Plano montado pelo seu personal.';
      action = 'Abrir plano';
      onPressed = () => context.go(AppRoutes.workout);
    } else if (last != null && uid != null) {
      title = 'Pronto para treinar?';
      subtitle = 'Repita "${last.name}" ou escolha outro.';
      action = 'Repetir treino';
      onPressed = () {
        context.read<WorkoutProvider>().repeatWorkout(uid!, last);
        context.go(AppRoutes.workout);
      };
    } else {
      title = 'Comece por aqui';
      subtitle = 'Escolha um treino pronto para o seu nível.';
      action = 'Ver treinos prontos';
      onPressed = () => context.push(AppRoutes.workoutTemplates);
    }

    return Card(
      color: Theme.of(context).colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ink,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: ink)),
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: ink,
                foregroundColor: Colors.white,
              ),
              onPressed: onPressed,
              icon: const Icon(Icons.play_arrow),
              label: Text(action),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.week});

  final WeekSummary week;

  static const _days = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final today = DateTime.now().weekday - 1;
    final streak = week.weekStreak;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(AppRoutes.progressCalendar),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sua semana',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (int d = 0; d < 7; d++)
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: week.trainedDays[d]
                            ? colors.primary
                            : colors.surfaceContainerHighest,
                        border: d == today
                            ? Border.all(color: colors.onSurface, width: 2)
                            : null,
                      ),
                      child: week.trainedDays[d]
                          ? const Icon(
                              Icons.check,
                              size: 18,
                              color: Color(0xFF14171A),
                            )
                          : Text(_days[d]),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                streak >= 2
                    ? '$streak semanas seguidas treinando · '
                          '${week.volumeThisWeek.toStringAsFixed(0)} kg nesta '
                          'semana'
                    : '${week.workoutsThisWeek} treino(s) · '
                          '${week.volumeThisWeek.toStringAsFixed(0)} kg nesta '
                          'semana',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GettingStartedCard extends StatelessWidget {
  const _GettingStartedCard({required this.hasReminders});

  final bool hasReminders;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Primeiros passos no app',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.radio_button_unchecked),
              title: const Text('Registre seu primeiro treino'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.workoutTemplates),
            ),
            ListTile(
              leading: Icon(
                hasReminders
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
              ),
              title: const Text('Crie um lembrete de água ou suplemento'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(AppRoutes.notifications),
            ),
            ListTile(
              leading: const Icon(Icons.radio_button_unchecked),
              title: const Text('Vincule seu personal, se tiver um'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(AppRoutes.profile),
            ),
          ],
        ),
      ),
    );
  }
}

class _LastWorkoutCard extends StatelessWidget {
  const _LastWorkoutCard({required this.workout});

  final Workout workout;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.history),
        title: Text(workout.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          'Último treino · ${DateFormat('dd/MM').format(workout.date)} · '
          '${workout.totalSets} série(s)',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go(AppRoutes.progress),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template});

  final WorkoutTemplate template;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () =>
              context.push(AppRoutes.workoutTemplates, extra: template.id),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TemplateBadge(isPremium: template.isPremium),
                const SizedBox(height: 8),
                Text(
                  template.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${template.level}\n${template.daysPerWeek}x por semana · '
                  '${template.minutes} min',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExploreGrid extends StatelessWidget {
  const _ExploreGrid();

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, VoidCallback)>[
      (Icons.list_alt, 'Exercícios', () => context.go(AppRoutes.exercises)),
      (Icons.show_chart, 'Progresso', () => context.go(AppRoutes.progress)),
      (
        Icons.calendar_month_outlined,
        'Calendário',
        () => context.push(AppRoutes.progressCalendar),
      ),
      (
        Icons.notifications_outlined,
        'Lembretes',
        () => context.go(AppRoutes.notifications),
      ),
      (Icons.smart_toy_outlined, 'IA', () => context.go(AppRoutes.ai)),
      (
        Icons.restaurant_outlined,
        'Nutrição',
        () => context.push(AppRoutes.nutrition),
      ),
    ];

    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.25,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final (icon, label, onTap) in items)
          Card(
            margin: EdgeInsets.zero,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 6),
                  Text(label, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
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
