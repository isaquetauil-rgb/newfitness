import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/app/routes/app_routes.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/finance/logic/finance_provider.dart';
import 'package:newfitness/features/workout/logic/workout_provider.dart';
import 'package:newfitness/shared/models/subscription.dart';
import 'package:newfitness/shared/models/workout_templates.dart';

enum _Filter { all, free, premium }

/// Catálogo de treinos prontos. [initialTemplateId] abre direto o detalhe
/// de um treino (usado pelos cards da tela inicial).
class WorkoutTemplatesScreen extends StatefulWidget {
  const WorkoutTemplatesScreen({super.key, this.initialTemplateId});

  final String? initialTemplateId;

  @override
  State<WorkoutTemplatesScreen> createState() => _WorkoutTemplatesScreenState();
}

class _WorkoutTemplatesScreenState extends State<WorkoutTemplatesScreen> {
  _Filter _filter = _Filter.all;
  late final Stream<Subscription> _subscription;
  bool _openedInitial = false;

  @override
  void initState() {
    super.initState();
    final uid = context.read<AuthProvider>().user?.uid;
    _subscription = uid == null
        ? const Stream.empty()
        : context.read<FinanceProvider>().watchSubscription(uid);
  }

  List<WorkoutTemplate> get _visible => [
    for (final template in workoutTemplates)
      if (_filter == _Filter.all ||
          (_filter == _Filter.premium) == template.isPremium)
        template,
  ];

  void _openInitial(bool unlockedPremium) {
    if (_openedInitial) return;
    _openedInitial = true;
    final id = widget.initialTemplateId;
    if (id == null) return;
    final matches = workoutTemplates.where((t) => t.id == id);
    if (matches.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showDetail(matches.first, unlockedPremium);
    });
  }

  void _showDetail(WorkoutTemplate template, bool unlockedPremium) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TemplateSheet(
        template: template,
        locked: template.isPremium && !unlockedPremium,
        hostContext: context,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().isAdmin;

    return Scaffold(
      appBar: AppBar(title: const Text('Treinos prontos')),
      body: StreamBuilder<Subscription>(
        stream: _subscription,
        builder: (context, snapshot) {
          final waiting = snapshot.connectionState == ConnectionState.waiting;
          final tier = snapshot.data?.planTier ?? PlanTier.basic;
          final unlocked = isAdmin || tier == PlanTier.premium;
          if (!waiting) _openInitial(unlocked);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<_Filter>(
                segments: const [
                  ButtonSegment(value: _Filter.all, label: Text('Todos')),
                  ButtonSegment(value: _Filter.free, label: Text('Grátis')),
                  ButtonSegment(value: _Filter.premium, label: Text('Premium')),
                ],
                selected: {_filter},
                onSelectionChanged: (value) =>
                    setState(() => _filter = value.first),
              ),
              const SizedBox(height: 16),
              for (final (category, title) in const [
                (
                  TemplateCategory.general,
                  'Para treinar na academia e em casa',
                ),
                (TemplateCategory.sport, 'Para o seu esporte'),
                (TemplateCategory.care, 'Para o seu corpo'),
              ])
                if (_visible.any((t) => t.category == category)) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  for (final template in _visible)
                    if (template.category == category)
                      _TemplateTile(
                        template: template,
                        locked: template.isPremium && !unlocked,
                        onTap: () => _showDetail(template, unlocked),
                      ),
                ],
              const SizedBox(height: 8),
              Text(
                'Sugestões gerais, sem avaliação individual. Se você tem dor, '
                'lesão ou alguma condição de saúde, procure um profissional '
                'antes de começar.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({
    required this.template,
    required this.locked,
    required this.onTap,
  });

  final WorkoutTemplate template;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        title: Row(
          children: [
            Flexible(
              child: Text(
                template.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            TemplateBadge(isPremium: template.isPremium),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('${template.summary}\n${templateFacts(template)}'),
        ),
        isThreeLine: true,
        trailing: Icon(locked ? Icons.lock_outline : Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

/// Nível, frequência e duração em uma linha.
String templateFacts(WorkoutTemplate template) =>
    '${template.level} · ${template.daysPerWeek}x por semana · '
    '${template.minutes} min';

class TemplateBadge extends StatelessWidget {
  const TemplateBadge({super.key, required this.isPremium});

  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isPremium ? colors.tertiaryContainer : colors.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isPremium ? 'Premium' : 'Grátis',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isPremium
              ? colors.onTertiaryContainer
              : colors.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _TemplateSheet extends StatelessWidget {
  const _TemplateSheet({
    required this.template,
    required this.locked,
    required this.hostContext,
  });

  final WorkoutTemplate template;
  final bool locked;

  /// Contexto da tela: continua válido depois que a folha fecha.
  final BuildContext hostContext;

  void _start(BuildContext sheetContext, int index) {
    final workout = hostContext.read<WorkoutProvider>();
    final uid = hostContext.read<AuthProvider>().user?.uid;
    Navigator.pop(sheetContext);
    if (uid == null) return;
    if (workout.hasActiveWorkout) {
      ScaffoldMessenger.of(hostContext).showSnackBar(
        const SnackBar(
          content: Text('Termine ou cancele o treino em andamento primeiro.'),
        ),
      );
    } else {
      workout.startFromTemplate(uid, template, index);
    }
    hostContext.go(AppRoutes.workout);
  }

  void _findPersonal(BuildContext sheetContext) {
    Navigator.pop(sheetContext);
    hostContext.go(AppRoutes.profile);
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(
            template.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(template.summary),
          const SizedBox(height: 4),
          Text(templateFacts(template), style: TextStyle(color: muted)),
          if (template.safetyNote != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                template.safetyNote!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (locked) ...[
            Text(
              'Este treino faz parte do Premium, que ainda não pode ser '
              'assinado pelo app. Se quiser um treino feito para você, '
              'vincule-se a um personal com o código de convite dele.',
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _findPersonal(context),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Vincular personal'),
            ),
            const SizedBox(height: 8),
          ],
          for (int w = 0; w < template.workouts.length; w++) ...[
            const SizedBox(height: 12),
            Text(
              template.workouts[w].label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            for (final exercise in template.workouts[w].exercises)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  '${exercise.exerciseName}: ${exercise.targetSets} x '
                  '${exercise.targetReps}',
                ),
              ),
            if (!locked) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => _start(context, w),
                icon: const Icon(Icons.play_arrow),
                label: Text(
                  template.workouts.length == 1
                      ? 'Começar treino'
                      : 'Começar ${template.workouts[w].label}',
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
