import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:newfitness/app/routes/app_routes.dart';
import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/core/storage/local_prefs.dart';
import 'package:newfitness/features/body_map/logic/muscle_map_logic.dart';
import 'package:newfitness/features/body_map/presentation/body_map_screen.dart';
import 'package:newfitness/features/body_map/presentation/body_map_view.dart';
import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/models/workout.dart';

/// Miniatura do mapa muscular da semana, para a tela inicial. Toque abre a
/// tela completa.
class BodyMapCard extends StatefulWidget {
  const BodyMapCard({super.key, required this.workouts});

  final List<Workout> workouts;

  @override
  State<BodyMapCard> createState() => _BodyMapCardState();
}

class _BodyMapCardState extends State<BodyMapCard> {
  late final Future<Exercise? Function(String)> _lookup;

  @override
  void initState() {
    super.initState();
    _lookup = loadExerciseLookup(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final female =
        getIt.isRegistered<LocalPrefs>() && getIt.isReadySync<LocalPrefs>()
        ? getIt<LocalPrefs>().bodyMapFemale
        : false;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(AppRoutes.bodyMap),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FutureBuilder<Exercise? Function(String)>(
            future: _lookup,
            builder: (context, snap) {
              final now = DateTime.now();
              final data = snap.hasData
                  ? computeMuscleMap(widget.workouts, now, snap.data!)
                  : null;
              final trained = data?.weekSets.length ?? 0;
              final forgotten = data?.forgotten(now).length ?? 0;
              return Row(
                children: [
                  SizedBox(
                    width: 120,
                    height: 110,
                    child: BodyMapView(
                      intensities:
                          data?.intensities(BodyMapMode.weekVolume, now) ??
                          const {},
                      color: bodyMapColor(BodyMapMode.weekVolume, scheme),
                      female: female,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mapa muscular',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          trained == 0
                              ? 'Nenhum músculo treinado esta semana.'
                              : '$trained ${trained == 1 ? 'músculo trabalhado' : 'músculos trabalhados'} esta semana.',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                        if (forgotten > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            '$forgotten sem treino há 10+ dias',
                            style: TextStyle(color: Colors.amber.shade800),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
