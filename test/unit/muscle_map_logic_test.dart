import 'package:flutter_test/flutter_test.dart';
import 'package:newfitness/features/body_map/data/muscle_map_paths.dart';
import 'package:newfitness/features/body_map/logic/muscle_map_logic.dart';
import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/models/logged_exercise.dart';
import 'package:newfitness/shared/models/sample_exercises.dart';
import 'package:newfitness/shared/models/sample_functional_exercises.dart';
import 'package:newfitness/shared/models/workout.dart';
import 'package:newfitness/shared/models/workout_set.dart';

Exercise _ex(String id, String group, [List<String> secondary = const []]) =>
    Exercise(
      id: id,
      name: id,
      muscleGroup: group,
      equipment: '',
      description: '',
      videoUrl: '',
      secondaryMuscles: secondary,
    );

final _bench = _ex('bench', 'Peito', ['Tríceps', 'Ombro']);
final _squat = _ex('squat', 'Pernas', ['Glúteos', 'Core']);
final _curl = _ex('bicep_curl', 'Braço');

Exercise? _lookup(String id) =>
    {'bench': _bench, 'squat': _squat, 'bicep_curl': _curl}[id];

WorkoutSet _set({SetType type = SetType.normal, int reps = 10}) =>
    WorkoutSet(reps: reps, weightKg: 20, completed: true, type: type);

Workout _workout(DateTime date, Map<String, List<WorkoutSet>> sets) => Workout(
  id: date.toIso8601String(),
  userId: 'u',
  date: date,
  exercises: [
    for (final e in sets.entries)
      LoggedExercise(exerciseId: e.key, exerciseName: e.key, sets: e.value),
  ],
);

void main() {
  // Quinta-feira, 19/11/2026, 18h. A semana começa na segunda 16/11.
  final now = DateTime(2026, 11, 19, 18);

  group('regionWeights', () {
    test('principal vale 1 e secundário 0,5', () {
      final w = regionWeights(_bench);
      expect(w[MuscleRegion.chest], 1);
      expect(w[MuscleRegion.triceps], 0.5);
      expect(w[MuscleRegion.deltoids], 0.5);
      expect(w.length, 3);
    });

    test('grupo com várias regiões divide o 1', () {
      final w = regionWeights(_ex('x', 'Braço'));
      expect(w[MuscleRegion.biceps], 0.5);
      expect(w[MuscleRegion.triceps], 0.5);
    });

    test('"Pernas" se espalha pela região (não cai num músculo só)', () {
      final w = regionWeights(_ex('meu_exercicio', 'Pernas'));
      expect(w, {
        MuscleRegion.quadriceps: 0.25,
        MuscleRegion.hamstring: 0.25,
        MuscleRegion.gluteal: 0.25,
        MuscleRegion.calves: 0.25,
      });
    });

    test('agachamento da biblioteca usa os músculos certos', () {
      final w = regionWeights(_ex('squat', 'Pernas'));
      expect(w, {MuscleRegion.quadriceps: 0.5, MuscleRegion.gluteal: 0.5});
      expect(regionWeights(_ex('leg_extension', 'Pernas')), {
        MuscleRegion.quadriceps: 1.0,
      });
    });

    test('exercício próprio entra no mapa pelo grupo gravado no treino', () {
      final data = computeMuscleMap(
        [
          Workout(
            id: 'w',
            userId: 'u',
            date: DateTime(2026, 11, 17),
            exercises: [
              LoggedExercise(
                exerciseId: 'own_zercher',
                exerciseName: 'Zercher',
                muscleGroup: 'Posterior de coxa',
                sets: [_set(), _set()],
              ),
              LoggedExercise(
                exerciseId: 'own_sem_grupo',
                exerciseName: 'Sem grupo',
                sets: [_set()],
              ),
            ],
          ),
        ],
        DateTime(2026, 11, 19, 18),
        (_) => null,
      );
      expect(data.weekSets, {MuscleRegion.hamstring: 2.0});
    });

    test('exercício conhecido usa a região certa, não o grupo genérico', () {
      expect(regionWeights(_curl), {MuscleRegion.biceps: 1.0});
      expect(regionWeights(_ex('leg_curl', 'Pernas')), {
        MuscleRegion.hamstring: 1.0,
      });
    });

    test('secundário igual ao principal não rebaixa o principal', () {
      final w = regionWeights(_ex('x', 'Peito', ['Peito']));
      expect(w[MuscleRegion.chest], 1);
    });

    test('acentos e maiúsculas não importam', () {
      expect(regionsForName('GLÚTEOS'), [MuscleRegion.gluteal]);
      expect(regionsForName(' posterior de coxa '), [MuscleRegion.hamstring]);
      expect(regionsForName('Abdomen'), [MuscleRegion.abs]);
      expect(regionsForName('desconhecido'), isEmpty);
    });

    test('todo exercício da biblioteca cai em pelo menos uma região', () {
      for (final e in [...sampleExercises, ...sampleFunctionalExercises]) {
        expect(regionWeights(e), isNotEmpty, reason: '${e.id} sem região');
      }
    });

    test('toda região existe no desenho (frente ou costas)', () {
      for (final r in MuscleRegion.values) {
        final drawn =
            maleFrontPaths.containsKey(r.name) ||
            maleBackPaths.containsKey(r.name);
        expect(drawn, isTrue, reason: '${r.name} não está no desenho');
      }
    });
  });

  group('séries da semana', () {
    test('cada série soma 1 no principal e 0,5 nos secundários', () {
      final data = computeMuscleMap(
        [
          _workout(DateTime(2026, 11, 17, 8), {
            'bench': [_set(), _set(), _set()],
          }),
        ],
        now,
        _lookup,
      );
      expect(data.weekSets[MuscleRegion.chest], 3);
      expect(data.weekSets[MuscleRegion.triceps], 1.5);
      expect(data.weekSets[MuscleRegion.deltoids], 1.5);
    });

    test('aquecimento e série vazia não contam', () {
      final data = computeMuscleMap(
        [
          _workout(DateTime(2026, 11, 17), {
            'bench': [
              _set(type: SetType.warmup),
              _set(type: SetType.warmup),
              _set(reps: 0),
              _set(),
              _set(type: SetType.drop),
            ],
          }),
        ],
        now,
        _lookup,
      );
      expect(data.weekSets[MuscleRegion.chest], 2);
    });

    test('só aquecimento: região nem aparece', () {
      final data = computeMuscleMap(
        [
          _workout(DateTime(2026, 11, 17), {
            'bench': [_set(type: SetType.warmup)],
          }),
        ],
        now,
        _lookup,
      );
      expect(data.weekSets, isEmpty);
      expect(data.lastTrained, isEmpty);
      expect(data.hasHistory, isFalse);
    });

    test('semana passada não entra; semana começa na segunda', () {
      final data = computeMuscleMap(
        [
          _workout(DateTime(2026, 11, 15, 23), {
            'bench': [_set()],
          }), // domingo anterior
          _workout(DateTime(2026, 11, 16, 0, 1), {
            'squat': [_set()],
          }), // segunda
        ],
        now,
        _lookup,
      );
      expect(data.weekSets[MuscleRegion.chest], isNull);
      // Agachamento: quadríceps e glúteos dividem o 1; core é secundário.
      expect(data.weekSets[MuscleRegion.quadriceps], 0.5);
      expect(data.weekSets[MuscleRegion.gluteal], 0.5);
      expect(data.weekSets[MuscleRegion.abs], 0.5);
    });

    test('exercício que não está na biblioteca é ignorado', () {
      final data = computeMuscleMap(
        [
          _workout(DateTime(2026, 11, 17), {
            'apagado': [_set()],
          }),
        ],
        now,
        _lookup,
      );
      expect(data.weekSets, isEmpty);
    });

    test('intensidade: mais séries, cor mais forte; satura em 12', () {
      final data = MuscleMapData(
        weekSets: {
          MuscleRegion.chest: 6,
          MuscleRegion.biceps: 20,
          MuscleRegion.calves: 0.5,
        },
        lastTrained: const {},
        hasHistory: true,
      );
      final i = data.intensities(BodyMapMode.weekVolume, now);
      expect(i[MuscleRegion.chest], 0.5);
      expect(i[MuscleRegion.biceps], 1);
      expect(i[MuscleRegion.calves], 0.15); // mínimo visível
      expect(i[MuscleRegion.abs], isNull);
    });
  });

  group('recuperando (48 h)', () {
    test('treinado há pouco aparece forte; depois de 48 h some', () {
      final data = computeMuscleMap(
        [
          _workout(now.subtract(const Duration(hours: 2)), {
            'bench': [_set()],
          }),
          _workout(now.subtract(const Duration(hours: 47)), {
            'bicep_curl': [_set()],
          }),
          _workout(now.subtract(const Duration(hours: 49)), {
            'squat': [_set()],
          }),
        ],
        now,
        _lookup,
      );
      final i = data.intensities(BodyMapMode.recovering, now);
      expect(i[MuscleRegion.chest]!, greaterThan(0.9));
      expect(i[MuscleRegion.biceps]!, closeTo(0.2, 0.001)); // piso
      expect(i.containsKey(MuscleRegion.quadriceps), isFalse);
    });

    test('usa o treino mais recente de cada região', () {
      final data = computeMuscleMap(
        [
          _workout(now.subtract(const Duration(days: 5)), {
            'bench': [_set()],
          }),
          _workout(now.subtract(const Duration(hours: 1)), {
            'bench': [_set()],
          }),
        ],
        now,
        _lookup,
      );
      expect(
        data.lastTrained[MuscleRegion.chest],
        now.subtract(const Duration(hours: 1)),
      );
    });
  });

  group('esquecidos (10 dias)', () {
    test('10 dias ou mais sem treino, ou nunca treinado', () {
      final data = computeMuscleMap(
        [
          _workout(now.subtract(const Duration(days: 10)), {
            'bench': [_set()],
          }),
          _workout(now.subtract(const Duration(days: 9)), {
            'squat': [_set()],
          }),
        ],
        now,
        _lookup,
      );
      final forgotten = data.forgotten(now);
      expect(forgotten, contains(MuscleRegion.chest)); // 10 dias
      expect(forgotten, contains(MuscleRegion.hamstring)); // nunca
      expect(forgotten, isNot(contains(MuscleRegion.quadriceps))); // 9 dias
      expect(forgotten, isNot(contains(MuscleRegion.gluteal))); // secundário
      expect(
        data.intensities(BodyMapMode.forgotten, now)[MuscleRegion.chest],
        1,
      );
    });

    test('sem nenhum treino, nada aparece como esquecido', () {
      final data = computeMuscleMap(const [], now, _lookup);
      expect(data.forgotten(now), isEmpty);
      expect(data.intensities(BodyMapMode.forgotten, now), isEmpty);
    });
  });
}
