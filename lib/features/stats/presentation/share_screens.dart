import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/body_map/logic/muscle_map_logic.dart';
import 'package:newfitness/features/body_map/presentation/body_map_screen.dart';
import 'package:newfitness/features/stats/logic/period_stats.dart';
import 'package:newfitness/features/stats/presentation/share_card.dart';
import 'package:newfitness/features/workout/logic/workout_provider.dart';
import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/models/workout.dart';
import 'package:newfitness/shared/utils/one_rep_max.dart';

/// Músculos trabalhados num treino só, para o mapa pequeno do cartão.
Map<MuscleRegion, double> workoutMuscles(
  Workout workout,
  Exercise? Function(String) lookup,
) => computeMuscleMap(
  [workout],
  workout.date,
  lookup,
).intensities(BodyMapMode.weekVolume, workout.date);

/// Abre a prévia do cartão do treino com o botão "Compartilhar".
Future<void> openWorkoutShare(
  BuildContext context,
  Workout workout,
  List<PersonalRecord> records,
) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _WorkoutShareScreen(workout: workout, records: records),
    ),
  );
}

class _WorkoutShareScreen extends StatefulWidget {
  const _WorkoutShareScreen({required this.workout, required this.records});

  final Workout workout;
  final List<PersonalRecord> records;

  @override
  State<_WorkoutShareScreen> createState() => _WorkoutShareScreenState();
}

class _WorkoutShareScreenState extends State<_WorkoutShareScreen> {
  late final Future<Exercise? Function(String)> _lookup;

  @override
  void initState() {
    super.initState();
    _lookup = loadExerciseLookup(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compartilhar treino')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FutureBuilder<Exercise? Function(String)>(
            future: _lookup,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return ShareCardPreview(
                fileName: 'treino-newfitness.png',
                card: WorkoutShareCard(
                  workout: widget.workout,
                  records: widget.records,
                  muscles: workoutMuscles(widget.workout, snap.data!),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// "Meu mês" / "Meu ano": resumo do período, com setas para voltar a
/// meses/anos anteriores, e o cartão para compartilhar.
class PeriodSummaryScreen extends StatefulWidget {
  const PeriodSummaryScreen({super.key, required this.kind});

  final PeriodKind kind;

  @override
  State<PeriodSummaryScreen> createState() => _PeriodSummaryScreenState();
}

class _PeriodSummaryScreenState extends State<PeriodSummaryScreen> {
  late final Stream<List<Workout>> _history;
  late Period _period;

  @override
  void initState() {
    super.initState();
    final uid = context.read<AuthProvider>().user?.uid;
    _history = uid == null
        ? const Stream.empty()
        : context.read<WorkoutProvider>().watchHistory(uid);
    _period = Period.containing(widget.kind, DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final isMonth = widget.kind == PeriodKind.month;
    final current = Period.containing(widget.kind, DateTime.now());
    return Scaffold(
      appBar: AppBar(title: Text(isMonth ? 'Meu mês' : 'Meu ano')),
      body: SafeArea(
        child: StreamBuilder<List<Workout>>(
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
            final stats = PeriodStats.from(snap.data!, _period);
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        tooltip: isMonth ? 'Mês anterior' : 'Ano anterior',
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () =>
                            setState(() => _period = _period.previous),
                      ),
                      if (stats.isEmpty)
                        Text(
                          'Nenhum treino neste ${isMonth ? 'mês' : 'ano'}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      IconButton(
                        tooltip: isMonth ? 'Próximo mês' : 'Próximo ano',
                        icon: const Icon(Icons.chevron_right),
                        onPressed: _period == current
                            ? null
                            : () => setState(() => _period = _period.next),
                      ),
                    ],
                  ),
                  Expanded(
                    child: ShareCardPreview(
                      fileName: isMonth
                          ? 'meu-mes-newfitness.png'
                          : 'meu-ano-newfitness.png',
                      card: PeriodShareCard(stats: stats),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
