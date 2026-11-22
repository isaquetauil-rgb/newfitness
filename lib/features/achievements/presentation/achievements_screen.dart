import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/features/achievements/logic/achievements.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/home/logic/week_summary.dart';
import 'package:newfitness/features/stats/logic/record_history.dart';
import 'package:newfitness/features/workout/logic/workout_provider.dart';
import 'package:newfitness/shared/models/user_profile.dart';
import 'package:newfitness/shared/models/workout.dart';

IconData achievementIcon(Achievement a) => switch (a.kind) {
  AchievementKind.workouts => Icons.fitness_center,
  AchievementKind.record => Icons.emoji_events,
  AchievementKind.weekStreak => Icons.local_fire_department,
};

/// Escolher a meta semanal (1 a 7 treinos). Salva no perfil.
Future<void> showWeeklyGoalDialog(BuildContext context) async {
  final auth = context.read<AuthProvider>();
  var selected = auth.profile?.effectiveWeeklyGoal ?? defaultWeeklyGoal;
  final chosen = await showDialog<int>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Meta semanal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quantos treinos por semana você quer fazer? A sequência '
              'conta as semanas em que você bate a meta; dias de descanso '
              'não quebram nada.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var n = 1; n <= 7; n++)
                  ChoiceChip(
                    label: Text('$n'),
                    selected: selected == n,
                    onSelected: (_) => setState(() => selected = n),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, selected),
            child: const Text('Salvar'),
          ),
        ],
      ),
    ),
  );
  if (chosen == null) return;
  final ok = await auth.saveWeeklyGoal(chosen);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não foi possível salvar a meta.')),
    );
  }
}

/// Aviso de conquista nova (depois de salvar um treino).
Future<void> showAchievementsEarned(
  BuildContext context,
  List<Achievement> earned,
) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.military_tech, size: 48, color: Color(0xFFF5C451)),
      title: Text(
        earned.length == 1
            ? 'Conquista desbloqueada!'
            : 'Conquistas desbloqueadas!',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final a in earned)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(achievementIcon(a)),
              title: Text(a.title),
              subtitle: Text(a.description),
            ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Boa!'),
        ),
      ],
    ),
  );
}

/// Depois de salvar [saved]: calcula as conquistas que ele trouxe, grava o
/// resumo no perfil e devolve as novas (para o aviso). Falha de rede não
/// atrapalha o treino: devolve lista vazia.
Future<List<Achievement>> syncAchievementsAfterWorkout(
  BuildContext context,
  Workout saved,
) async {
  final auth = context.read<AuthProvider>();
  final profile = auth.profile;
  if (profile == null) return const [];
  try {
    final history = await context
        .read<WorkoutProvider>()
        .watchHistory(profile.uid)
        .first
        .timeout(const Duration(seconds: 5));
    final goal = profile.effectiveWeeklyGoal;
    final perWeek = profile.goalSchedule.goalFor;
    final all = [...history.where((w) => w.id != saved.id), saved];
    final fresh = newlyEarned(
      all,
      saved,
      weeklyGoal: goal,
      goalForWeek: perWeek,
    );
    final merged = mergeAchievements(
      computeAchievements(all, weeklyGoal: goal, goalForWeek: perWeek),
      profile.achievements,
    );
    await auth.saveAchievements(achievementsToMap(merged));
    // Já estava no perfil (ex.: ganha antes com outra meta)? Não avisa de novo.
    final stored = profile.achievements ?? const {};
    return [
      for (final a in fresh)
        if (!stored.containsKey(a.name)) a,
    ];
  } catch (_) {
    return const [];
  }
}

/// Conquistas ganhas e bloqueadas, sequência atual e meta semanal.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  late final Stream<List<Workout>> _history;
  bool _synced = false;

  @override
  void initState() {
    super.initState();
    final uid = context.read<AuthProvider>().user?.uid;
    _history = uid == null
        ? const Stream.empty()
        : context.read<WorkoutProvider>().watchHistory(uid);
  }

  /// Primeira vez (ou histórico antigo): grava no perfil, sem aviso.
  void _syncOnce(Map<Achievement, DateTime> earned) {
    if (_synced) return;
    _synced = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthProvider>().saveAchievements(achievementsToMap(earned));
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    final goal = profile?.effectiveWeeklyGoal ?? defaultWeeklyGoal;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Conquistas')),
      body: StreamBuilder<List<Workout>>(
        stream: _history,
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(
              child: Text('Não foi possível carregar os treinos.'),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final workouts = snap.data!;
          final now = DateTime.now();
          // Cada semana pela meta que valia nela.
          final perWeek = profile?.goalSchedule.goalFor;
          final earned = mergeAchievements(
            computeAchievements(
              workouts,
              weeklyGoal: goal,
              goalForWeek: perWeek,
            ),
            profile?.achievements,
          );
          _syncOnce(earned);
          final week = WeekSummary.from(
            workouts,
            now,
            weeklyGoal: goal,
            goalForWeek: perWeek,
          );
          final weeks = WeekSummary.goalWeeks(
            workouts,
            goal: goal,
            goalForWeek: perWeek,
          );
          final best = WeekSummary.longestStreak(
            weeks,
            DateTime(1970),
            WeekSummary.nextWeek(WeekSummary.weekStartOf(now)),
          );
          final hasRecord = recordsFromHistory(workouts).isNotEmpty;

          String progress(Achievement a) => switch (a.kind) {
            AchievementKind.workouts =>
              '${workouts.length.clamp(0, a.target)} de ${a.target} treinos',
            AchievementKind.record =>
              hasRecord ? '' : 'Supere sua melhor marca num exercício',
            AchievementKind.weekStreak =>
              '${best.clamp(0, a.target)} de ${a.target} semanas (melhor sequência)',
          };

          final date = DateFormat("d 'de' MMM 'de' y", 'pt_BR');
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        size: 40,
                        color: week.weekStreak > 0
                            ? Colors.deepOrange
                            : scheme.outline,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              week.weekStreak == 1
                                  ? '1 semana seguida'
                                  : '${week.weekStreak} semanas seguidas',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Esta semana: ${week.workoutsThisWeek} de $goal '
                              '${goal == 1 ? 'treino' : 'treinos'}'
                              '${week.goalMetThisWeek ? ' · meta batida!' : ''}',
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => showWeeklyGoalDialog(context),
                        child: const Text('Mudar meta'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${earned.length} de ${Achievement.values.length} conquistas',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              for (final a in Achievement.values)
                Card(
                  color: earned.containsKey(a)
                      ? null
                      : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: earned.containsKey(a)
                          ? const Color(0xFFF5C451)
                          : scheme.surfaceContainerHighest,
                      foregroundColor: earned.containsKey(a)
                          ? Colors.black87
                          : scheme.outline,
                      child: Icon(
                        earned.containsKey(a) ? achievementIcon(a) : Icons.lock,
                      ),
                    ),
                    title: Text(
                      a.title,
                      style: TextStyle(
                        color: earned.containsKey(a) ? null : scheme.outline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      earned.containsKey(a)
                          ? 'Conquistada em ${date.format(earned[a]!)}'
                          : [
                              a.description,
                              progress(a),
                            ].where((s) => s.isNotEmpty).join('\n'),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
