import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/core/storage/local_prefs.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/body_map/logic/missing_muscle_groups.dart';
import 'package:newfitness/features/body_map/logic/muscle_map_logic.dart';
import 'package:newfitness/features/body_map/presentation/complete_muscle_groups_screen.dart';
import 'package:newfitness/features/body_map/presentation/body_map_view.dart';
import 'package:newfitness/features/exercises/logic/exercise_pool.dart';
import 'package:newfitness/features/exercises/logic/exercise_similarity.dart';
import 'package:newfitness/features/workout/logic/workout_provider.dart';
import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/models/sample_exercises.dart';
import 'package:newfitness/shared/models/sample_functional_exercises.dart';
import 'package:newfitness/shared/models/workout.dart';

/// Abre o mapa de outro usuário (o personal vendo o aluno vinculado).
class BodyMapArgs {
  const BodyMapArgs({required this.studentUid, required this.studentName});
  final String studentUid;
  final String studentName;
}

/// Acha o exercício pelo id: biblioteca carregada (global + do personal) e,
/// por último, os exercícios de fábrica do app.
Future<Exercise? Function(String)> loadExerciseLookup(
  BuildContext context,
) async {
  final pool = await loadExercisePool(context, includeArchived: true);
  final byId = {
    for (final e in [...sampleFunctionalExercises, ...sampleExercises]) e.id: e,
    for (final e in pool) e.id: e,
  };
  return (id) => byId[id];
}

/// "6", "1,5": séries ponderadas (o secundário vale meia série).
String formatSets(double sets) {
  final text = sets == sets.roundToDouble()
      ? sets.toStringAsFixed(0)
      : sets.toStringAsFixed(1).replaceAll('.', ',');
  return '$text ${sets == 1 ? 'série' : 'séries'}';
}

String _ago(DateTime at, DateTime now) {
  final d = now.difference(at);
  if (d.inHours < 1) return 'agora há pouco';
  if (d.inHours < 48) return 'há ${d.inHours} h';
  return 'há ${d.inDays} dias';
}

/// Tela do mapa muscular: séries da semana, recuperando e esquecidos.
class BodyMapScreen extends StatefulWidget {
  const BodyMapScreen({super.key, this.args});

  /// `null`: o próprio usuário logado.
  final BodyMapArgs? args;

  @override
  State<BodyMapScreen> createState() => _BodyMapScreenState();
}

class _BodyMapScreenState extends State<BodyMapScreen> {
  late final Stream<List<Workout>> _history;
  late final Future<Exercise? Function(String)> _lookup;
  BodyMapMode _mode = BodyMapMode.weekVolume;
  bool _female = false;

  LocalPrefs? get _prefs =>
      getIt.isRegistered<LocalPrefs>() && getIt.isReadySync<LocalPrefs>()
      ? getIt<LocalPrefs>()
      : null;

  @override
  void initState() {
    super.initState();
    final uid =
        widget.args?.studentUid ?? context.read<AuthProvider>().user?.uid;
    _history = uid == null
        ? const Stream.empty()
        : context.read<WorkoutProvider>().watchHistory(uid);
    _lookup = loadExerciseLookup(context);
    _female = _prefs?.bodyMapFemale ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = widget.args == null
        ? 'Mapa muscular'
        : 'Mapa muscular · ${widget.args!.studentName.split(' ').first}';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: _female ? 'Ver desenho masculino' : 'Ver desenho feminino',
            icon: Icon(_female ? Icons.female : Icons.male),
            onPressed: () {
              setState(() => _female = !_female);
              _prefs?.setBodyMapFemale(_female);
            },
          ),
        ],
      ),
      body: FutureBuilder<Exercise? Function(String)>(
        future: _lookup,
        builder: (context, lookupSnap) => StreamBuilder<List<Workout>>(
          stream: _history,
          builder: (context, snap) {
            if (!snap.hasData || !lookupSnap.hasData) {
              if (snap.hasError) {
                return const Center(
                  child: Text('Não foi possível carregar os treinos.'),
                );
              }
              return const Center(child: CircularProgressIndicator());
            }
            final now = DateTime.now();
            final data = computeMuscleMap(snap.data!, now, lookupSnap.data!);
            final color = bodyMapColor(_mode, scheme);
            // Só o dono completa (o personal vendo o aluno não mexe).
            final missing = widget.args == null
                ? exercisesWithoutGroup(snap.data!, lookupSnap.data!)
                : const <ExerciseWithoutGroup>[];
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (missing.isNotEmpty) ...[
                  MissingGroupsBanner(
                    count: missing.length,
                    onComplete: () => _completeMissing(missing, snap.data!),
                  ),
                  const SizedBox(height: 12),
                ],
                SegmentedButton<BodyMapMode>(
                  segments: [
                    for (final m in BodyMapMode.values)
                      ButtonSegment(value: m, label: Text(m.label)),
                  ],
                  selected: {_mode},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _mode = s.first),
                ),
                const SizedBox(height: 8),
                Text(
                  _explain(_mode),
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 380,
                  child: BodyMapView(
                    intensities: data.intensities(_mode, now),
                    color: color,
                    female: _female,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text('Frente', style: TextStyle(color: scheme.outline)),
                    Text('Costas', style: TextStyle(color: scheme.outline)),
                  ],
                ),
                const SizedBox(height: 16),
                ..._details(data, now, color),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _completeMissing(
    List<ExerciseWithoutGroup> missing,
    List<Workout> history,
  ) async {
    final pool = await loadExercisePool(context);
    if (!mounted) return;
    final provider = context.read<WorkoutProvider>();
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CompleteMuscleGroupsScreen(
          items: [
            for (final m in missing)
              MissingGroupItem(
                id: m.exerciseId,
                name: m.name,
                subtitle: m.workouts == 1
                    ? 'Em 1 treino'
                    : 'Em ${m.workouts} treinos',
                suggestion: suggestMuscleGroup(m.name, pool),
              ),
          ],
          onSave: (id, group) => provider.saveWorkoutExercises(
            withMuscleGroup(history, id, group),
          ),
        ),
      ),
    );
  }

  String _explain(BodyMapMode mode) => switch (mode) {
    BodyMapMode.weekVolume =>
      'Séries desta semana (desde segunda). Cor mais forte = mais séries. '
          'Músculo secundário conta meia série; aquecimento não conta.',
    BodyMapMode.recovering =>
      'Músculos treinados nas últimas 48 horas. '
          'A cor vai clareando conforme o tempo passa.',
    BodyMapMode.forgotten => 'Músculos sem treino há 10 dias ou mais.',
  };

  List<Widget> _details(MuscleMapData data, DateTime now, Color color) {
    final rows = <(MuscleRegion, String)>[];
    switch (_mode) {
      case BodyMapMode.weekVolume:
        final entries = data.weekSets.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        for (final e in entries) {
          rows.add((e.key, formatSets(e.value)));
        }
      case BodyMapMode.recovering:
        final recent =
            data.intensities(BodyMapMode.recovering, now).keys.toList()..sort(
              (a, b) => data.lastTrained[b]!.compareTo(data.lastTrained[a]!),
            );
        for (final r in recent) {
          rows.add((r, _ago(data.lastTrained[r]!, now)));
        }
      case BodyMapMode.forgotten:
        for (final r in data.forgotten(now)) {
          final last = data.lastTrained[r];
          rows.add((r, last == null ? 'nunca treinado' : _ago(last, now)));
        }
    }
    if (rows.isEmpty) {
      return [
        Text(switch (_mode) {
          BodyMapMode.weekVolume => 'Nenhuma série registrada esta semana.',
          BodyMapMode.recovering => 'Nada treinado nas últimas 48 horas.',
          BodyMapMode.forgotten =>
            data.hasHistory
                ? 'Nenhum músculo esquecido. Bom trabalho!'
                : 'Ainda não há treinos registrados.',
        }, textAlign: TextAlign.center),
      ];
    }
    return [
      for (final (region, value) in rows)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.circle, size: 12, color: color),
          title: Text(region.label),
          trailing: Text(value),
        ),
    ];
  }
}
