/// Cálculo do mapa muscular: quanto cada região do corpo foi treinada.
/// Lógica pura: sem Flutter e sem Firebase.
library;

import 'package:newfitness/features/home/logic/week_summary.dart';
import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/models/logged_exercise.dart';
import 'package:newfitness/shared/models/workout.dart';
import 'package:newfitness/shared/models/workout_set.dart';

/// Regiões do desenho. O [name] de cada uma é a chave do path no
/// MuscleMap (ver `muscle_map_paths.dart`).
enum MuscleRegion {
  chest('Peito'),
  deltoids('Ombros'),
  biceps('Bíceps'),
  triceps('Tríceps'),
  forearm('Antebraço'),
  abs('Abdômen'),
  obliques('Oblíquos'),
  serratus('Serrátil'),
  trapezius('Trapézio'),
  upperBack('Costas (dorsal)'),
  rhomboids('Romboides'),
  rotatorCuff('Manguito rotador'),
  lowerBack('Lombar'),
  gluteal('Glúteos'),
  quadriceps('Quadríceps'),
  hamstring('Posterior de coxa'),
  adductors('Adutores'),
  hipFlexors('Flexores do quadril'),
  calves('Panturrilha'),
  tibialis('Tibial');

  const MuscleRegion(this.label);
  final String label;

  static MuscleRegion? fromSlug(String slug) {
    for (final r in values) {
      if (r.name == slug) return r;
    }
    return null;
  }
}

/// Os três jeitos de ver o mapa.
enum BodyMapMode {
  /// Séries da semana: cor mais forte = mais séries.
  weekVolume('Semana'),

  /// Treinado nas últimas 48 horas.
  recovering('Recuperando'),

  /// Sem treino há 10 dias ou mais.
  forgotten('Esquecidos');

  const BodyMapMode(this.label);
  final String label;
}

/// Peso de uma série para o músculo principal e para os secundários.
const double primaryWeight = 1;
const double secondaryWeight = 0.5;

/// Janela de "recuperando" e limite de "esquecido".
const Duration recoveryWindow = Duration(hours: 48);
const Duration forgottenAfter = Duration(days: 10);

/// Séries na semana que já pintam a região com a cor mais forte.
const double fullWeekSets = 12;

String _norm(String s) => s
    .trim()
    .toLowerCase()
    .replaceAll(RegExp('[áàâã]'), 'a')
    .replaceAll(RegExp('[éê]'), 'e')
    .replaceAll('í', 'i')
    .replaceAll(RegExp('[óôõ]'), 'o')
    .replaceAll('ú', 'u')
    .replaceAll('ç', 'c');

const _legRegion = [
  MuscleRegion.quadriceps,
  MuscleRegion.hamstring,
  MuscleRegion.gluteal,
  MuscleRegion.calves,
];

/// Nome de grupo muscular (como está na biblioteca) → regiões do desenho.
const Map<String, List<MuscleRegion>> _groupRegions = {
  'peito': [MuscleRegion.chest],
  'peitoral': [MuscleRegion.chest],
  'costas': [MuscleRegion.upperBack],
  'dorsal': [MuscleRegion.upperBack],
  'ombro': [MuscleRegion.deltoids],
  'ombros': [MuscleRegion.deltoids],
  'deltoide': [MuscleRegion.deltoids],
  'biceps': [MuscleRegion.biceps],
  'triceps': [MuscleRegion.triceps],
  'antebraco': [MuscleRegion.forearm],
  'braco': [MuscleRegion.biceps, MuscleRegion.triceps],
  'bracos': [MuscleRegion.biceps, MuscleRegion.triceps],
  'abdomen': [MuscleRegion.abs],
  'abdominal': [MuscleRegion.abs],
  'core': [MuscleRegion.abs],
  'obliquos': [MuscleRegion.obliques],
  'trapezio': [MuscleRegion.trapezius],
  'lombar': [MuscleRegion.lowerBack],
  'gluteos': [MuscleRegion.gluteal],
  'gluteo': [MuscleRegion.gluteal],
  'quadriceps': [MuscleRegion.quadriceps],
  'posterior de coxa': [MuscleRegion.hamstring],
  'posteriores': [MuscleRegion.hamstring],
  'isquiotibiais': [MuscleRegion.hamstring],
  'adutores': [MuscleRegion.adductors],
  'panturrilha': [MuscleRegion.calves],
  'panturrilhas': [MuscleRegion.calves],
  // Grupo genérico: se espalha pelos músculos da região (o 1 da série é
  // dividido entre eles), em vez de cair num músculo só.
  'pernas': _legRegion,
  'perna': _legRegion,
  'membros inferiores': _legRegion,
  'corpo todo': [
    MuscleRegion.quadriceps,
    MuscleRegion.gluteal,
    MuscleRegion.chest,
    MuscleRegion.upperBack,
    MuscleRegion.deltoids,
    MuscleRegion.abs,
  ],
};

/// Exercícios cujo grupo da biblioteca é genérico ("Pernas", "Braço",
/// "Corpo todo"...): aqui está a região principal de verdade.
const Map<String, List<MuscleRegion>> _exerciseRegions = {
  // "Pernas" da biblioteca com o músculo certo (sem espalhar à toa).
  'squat': [MuscleRegion.quadriceps, MuscleRegion.gluteal],
  'lunge': [MuscleRegion.quadriceps, MuscleRegion.gluteal],
  'leg_press': [MuscleRegion.quadriceps, MuscleRegion.gluteal],
  'leg_extension': [MuscleRegion.quadriceps],
  'hack_squat': [MuscleRegion.quadriceps],
  'bulgarian_split_squat': [MuscleRegion.quadriceps, MuscleRegion.gluteal],
  'sit_to_stand': [MuscleRegion.quadriceps, MuscleRegion.gluteal],
  'step_up': [MuscleRegion.quadriceps, MuscleRegion.gluteal],
  'squat_jump': [
    MuscleRegion.quadriceps,
    MuscleRegion.gluteal,
    MuscleRegion.calves,
  ],
  'box_jump': [
    MuscleRegion.quadriceps,
    MuscleRegion.gluteal,
    MuscleRegion.calves,
  ],
  'lateral_bound': [
    MuscleRegion.gluteal,
    MuscleRegion.quadriceps,
    MuscleRegion.calves,
  ],
  'leg_curl': [MuscleRegion.hamstring],
  'nordic_curl': [MuscleRegion.hamstring],
  'romanian_deadlift': [MuscleRegion.hamstring],
  'calf_raise': [MuscleRegion.calves],
  'seated_calf_raise': [MuscleRegion.calves],
  'ankle_mobility': [MuscleRegion.tibialis],
  'bicep_curl': [MuscleRegion.biceps],
  'hammer_curl': [MuscleRegion.biceps],
  'tricep_extension': [MuscleRegion.triceps],
  'triceps_pushdown': [MuscleRegion.triceps],
  'deadlift': [
    MuscleRegion.gluteal,
    MuscleRegion.hamstring,
    MuscleRegion.lowerBack,
  ],
  'band_external_rotation': [MuscleRegion.rotatorCuff],
  'face_pull': [MuscleRegion.deltoids, MuscleRegion.rhomboids],
  'band_pull_apart': [MuscleRegion.deltoids, MuscleRegion.rhomboids],
  'dead_hang': [MuscleRegion.forearm],
  'hip_abduction': [MuscleRegion.gluteal],
  'russian_twist': [MuscleRegion.obliques],
  'side_plank': [MuscleRegion.obliques],
  'side_lunge': [MuscleRegion.adductors, MuscleRegion.quadriceps],
  'farmer_walk': [MuscleRegion.forearm, MuscleRegion.trapezius],
  'jump_rope': [MuscleRegion.calves],
  'shadow_boxing': [MuscleRegion.deltoids],
  'kettlebell_swing': [MuscleRegion.gluteal, MuscleRegion.hamstring],
  'hip_90_90': [MuscleRegion.hipFlexors, MuscleRegion.gluteal],
  'leg_raise': [MuscleRegion.abs, MuscleRegion.hipFlexors],
  'hip_escape': [MuscleRegion.gluteal, MuscleRegion.abs],
  'single_leg_balance': [MuscleRegion.calves, MuscleRegion.gluteal],
  'heel_toe_walk': [MuscleRegion.calves, MuscleRegion.tibialis],
  'med_ball_slam': [MuscleRegion.abs, MuscleRegion.deltoids],
  'bear_crawl': [MuscleRegion.deltoids, MuscleRegion.abs],
};

/// Regiões de um nome de grupo/músculo ("Peito", "Posterior de coxa"...).
/// Vazio quando o nome não é conhecido.
List<MuscleRegion> regionsForName(String name) =>
    _groupRegions[_norm(name)] ?? const [];

/// Quanto UMA série deste exercício vale para cada região: 1 dividido entre
/// as regiões principais e 0,5 para cada secundária (a região conta pelo
/// maior dos dois, sem somar).
Map<MuscleRegion, double> regionWeights(Exercise exercise) {
  final primary =
      _exerciseRegions[exercise.id] ?? regionsForName(exercise.muscleGroup);
  final weights = <MuscleRegion, double>{};
  for (final r in primary) {
    weights[r] = primaryWeight / primary.length;
  }
  for (final name in exercise.secondaryMuscles) {
    for (final r in regionsForName(name)) {
      final current = weights[r] ?? 0;
      if (secondaryWeight > current) weights[r] = secondaryWeight;
    }
  }
  return weights;
}

/// Resultado do cálculo para um aluno.
class MuscleMapData {
  const MuscleMapData({
    required this.weekSets,
    required this.lastTrained,
    required this.hasHistory,
  });

  /// Séries ponderadas por região na semana atual (segunda a domingo).
  final Map<MuscleRegion, double> weekSets;

  /// Último treino de cada região (principal ou secundária).
  final Map<MuscleRegion, DateTime> lastTrained;

  /// O aluno tem algum treino com exercício reconhecido.
  final bool hasHistory;

  /// Força da cor de cada região (0 a 1) no [mode].
  Map<MuscleRegion, double> intensities(BodyMapMode mode, DateTime now) {
    switch (mode) {
      case BodyMapMode.weekVolume:
        return {
          for (final e in weekSets.entries)
            if (e.value > 0) e.key: (e.value / fullWeekSets).clamp(0.15, 1.0),
        };
      case BodyMapMode.recovering:
        final out = <MuscleRegion, double>{};
        lastTrained.forEach((region, at) {
          final ago = now.difference(at);
          if (!ago.isNegative && ago < recoveryWindow) {
            // Mais forte logo depois do treino, some até 48 h.
            out[region] = (1 - ago.inMinutes / recoveryWindow.inMinutes).clamp(
              0.2,
              1.0,
            );
          }
        });
        return out;
      case BodyMapMode.forgotten:
        return {for (final r in forgotten(now)) r: 1.0};
    }
  }

  /// Regiões sem treino há 10 dias ou mais. Quem nunca treinou nada não tem
  /// "esquecidos" (o mapa ficaria todo pintado).
  List<MuscleRegion> forgotten(DateTime now) {
    if (!hasHistory) return const [];
    return [
      for (final r in MuscleRegion.values)
        if (lastTrained[r] == null ||
            now.difference(lastTrained[r]!) >= forgottenAfter)
          r,
    ];
  }
}

/// Exercício próprio (fora da biblioteca) com grupo muscular gravado no
/// treino: vira um exercício só com o grupo, para entrar no mapa.
Exercise? _ownExercise(LoggedExercise logged) {
  final group = logged.muscleGroup?.trim() ?? '';
  if (group.isEmpty) return null;
  return Exercise(
    id: logged.exerciseId,
    name: logged.exerciseName,
    muscleGroup: group,
    equipment: '',
    description: '',
    videoUrl: '',
  );
}

/// A série entra no mapa? Aquecimento não; série vazia (sem reps nem tempo)
/// ou só sugerida também não.
bool countsForMap(WorkoutSet set) =>
    !set.isWarmup && !set.suggested && (set.reps > 0 || set.seconds > 0);

/// Calcula o mapa a partir do histórico. [exerciseById] acha o exercício na
/// biblioteca (global + do personal); exercícios desconhecidos são
/// ignorados. Séries de aquecimento não contam.
MuscleMapData computeMuscleMap(
  List<Workout> workouts,
  DateTime now,
  Exercise? Function(String exerciseId) exerciseById,
) {
  final weekStart = WeekSummary.weekStartOf(now);
  final weekSets = <MuscleRegion, double>{};
  final lastTrained = <MuscleRegion, DateTime>{};
  var hasHistory = false;

  for (final workout in workouts) {
    final inWeek =
        !workout.date.isBefore(weekStart) && !workout.date.isAfter(now);
    for (final logged in workout.exercises) {
      final exercise = exerciseById(logged.exerciseId) ?? _ownExercise(logged);
      if (exercise == null) continue;
      final sets = logged.sets.where(countsForMap).length;
      if (sets == 0) continue;
      final weights = regionWeights(exercise);
      if (weights.isEmpty) continue;
      hasHistory = true;
      weights.forEach((region, weight) {
        if (inWeek) {
          weekSets[region] = (weekSets[region] ?? 0) + weight * sets;
        }
        final last = lastTrained[region];
        if (last == null || workout.date.isAfter(last)) {
          lastTrained[region] = workout.date;
        }
      });
    }
  }
  return MuscleMapData(
    weekSets: weekSets,
    lastTrained: lastTrained,
    hasHistory: hasHistory,
  );
}
