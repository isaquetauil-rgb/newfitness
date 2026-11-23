import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:newfitness/features/body_map/logic/muscle_map_logic.dart';
import 'package:newfitness/features/exercises/logic/exercise_filter.dart';
import 'package:newfitness/features/workout/logic/prescription_format.dart';
import 'package:newfitness/features/workout/logic/workout_provider.dart';
import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/models/logged_exercise.dart';
import 'package:newfitness/shared/models/sample_exercise_corrections.dart';
import 'package:newfitness/shared/models/sample_exercises.dart';
import 'package:newfitness/shared/models/sample_taxonomy.dart';
import 'package:newfitness/shared/models/training_plan.dart';
import 'package:newfitness/shared/models/workout.dart';
import 'package:newfitness/shared/models/workout_set.dart';

import '../helpers/mocks.dart';

Exercise _ex(
  String id,
  String group, {
  String equipment = '',
  String category = '',
}) => Exercise(
  id: id,
  name: id,
  muscleGroup: group,
  equipment: equipment,
  description: '',
  videoUrl: '',
  category: category,
);

void main() {
  group('nomes antigos continuam sendo entendidos (leitura)', () {
    test('grupos', () {
      expect(
        canonicalGroupsOf('Pernas'),
        containsAll(['Quadríceps', 'Posteriores de coxa', 'Panturrilha']),
      );
      expect(canonicalGroupsOf('Braço'), {'Bíceps', 'Tríceps', 'Antebraço'});
      expect(canonicalGroupsOf('Ombro'), {'Ombros'});
      expect(canonicalGroupsOf('posterior de coxa'), {'Posteriores de coxa'});
      expect(canonicalGroupsOf('Corpo todo'), {'Corpo todo'});
      expect(canonicalGroupsOf('Quadríceps'), {'Quadríceps'});
    });

    test('equipamentos', () {
      expect(canonicalEquipmentName('Peso do corpo'), 'Peso corporal');
      expect(canonicalEquipmentName('Esteira/bike'), 'Esteira');
      expect(canonicalEquipmentName('barra FIXA'), 'Barra fixa');
      expect(canonicalEquipmentName('Coisa nova'), 'Coisa nova');
    });

    test('categorias e rótulos', () {
      expect(canonicalCategory('funcional'), 'forca');
      expect(canonicalCategory('potencia'), 'forca');
      expect(canonicalCategory('condicionamento'), 'cardio');
      expect(canonicalCategory('Cardio'), 'cardio');
      expect(exerciseCategoryLabel('funcional'), 'Força');
      expect(exerciseCategoryLabel('Cardio'), 'Cardio');
      expect(exerciseCategoryLabel('condicionamento'), 'Cardio');
    });

    test('filtros: exercício antigo aparece nos filtros novos', () {
      final old = _ex(
        'x',
        'Pernas',
        equipment: 'Peso do corpo',
        category: 'funcional',
      );
      expect(
        const ExerciseFilter(muscleGroups: {'Quadríceps'}).matches(old),
        isTrue,
      );
      expect(
        const ExerciseFilter(muscleGroups: {'Peito'}).matches(old),
        isFalse,
      );
      expect(
        const ExerciseFilter(equipment: {'Peso corporal'}).matches(old),
        isTrue,
      );
      expect(const ExerciseFilter(categories: {'forca'}).matches(old), isTrue);
      // E um exercício novo aparece ao filtrar pelo nome antigo.
      final novo = _ex('y', 'Bíceps', equipment: 'Halteres', category: 'forca');
      expect(
        const ExerciseFilter(muscleGroups: {'Braço'}).matches(novo),
        isTrue,
      );
      expect(
        const ExerciseFilter(
          muscleGroups: {'Bíceps'},
          equipment: {'Halteres'},
          categories: {'forca'},
        ).matches(novo),
        isTrue,
      );
    });

    test('mapa: treino antigo com retrato "Braço" e treino novo com músculos padronizados', () {
      final now = DateTime(2026, 11, 19, 18);
      LoggedExercise logged(String id, String group, List<String> sec) =>
          LoggedExercise(
            exerciseId: id,
            exerciseName: id,
            muscleGroup: group,
            secondaryMuscles: sec,
            sets: [WorkoutSet(reps: 8, weightKg: 20, completed: true)],
          );
      final data = computeMuscleMap(
        [
          Workout(
            id: 'w',
            userId: 'u',
            date: DateTime(2026, 11, 17),
            exercises: [
              logged('antigo', 'Braço', const []),
              logged('novo', 'Peito', const [
                'Tríceps braquial',
                'Deltoide anterior',
              ]),
            ],
          ),
        ],
        now,
        (_) => null,
      );
      expect(data.weekSets[MuscleRegion.biceps], 0.5);
      // 0,5 do "Braço" antigo + 0,5 como secundário do exercício de peito.
      expect(data.weekSets[MuscleRegion.triceps], 1);
      expect(data.weekSets[MuscleRegion.chest], 1);
      expect(data.weekSets[MuscleRegion.deltoids], 0.5);
    });

    test('cardio e mobilidade não contam séries no mapa', () {
      expect(
        regionWeights(_ex('a', 'Corpo todo', category: 'cardio')),
        isEmpty,
      );
      expect(
        regionWeights(_ex('b', 'Costas', category: 'mobilidade')),
        isEmpty,
      );
      expect(regionWeights(_ex('c', 'Pernas', category: 'Cardio')), isEmpty);
      expect(regionWeights(_ex('d', 'Peito', category: 'forca')), isNotEmpty);
    });
  });

  group('biblioteca padronizada (Etapa 2)', () {
    final groups = canonicalMuscleGroups.toSet();
    final muscles = canonicalMuscles.toSet();
    final equipment = canonicalEquipment.toSet();

    test('todos os exercícios padrão usam só a taxonomia aprovada', () {
      for (final e in sampleExercises) {
        expect(
          groups,
          contains(e.muscleGroup),
          reason: '${e.id}: ${e.muscleGroup}',
        );
        expect(
          equipment,
          contains(e.equipment),
          reason: '${e.id}: ${e.equipment}',
        );
        expect(
          exerciseCategories,
          contains(e.category),
          reason: '${e.id}: ${e.category}',
        );
        expect(
          exerciseDifficultyLevels,
          contains(e.difficultyLevel),
          reason: e.id,
        );
        expect(e.movementPattern.trim(), isNotEmpty, reason: e.id);
        for (final m in e.secondaryMuscles) {
          expect(muscles, contains(m), reason: '${e.id}: $m');
        }
      }
    });

    test('todo músculo da taxonomia tem região no mapa', () {
      for (final m in canonicalMuscles) {
        expect(regionsForName(m), isNotEmpty, reason: m);
      }
      for (final g in canonicalMuscleGroups) {
        expect(regionsForName(g), isNotEmpty, reason: g);
      }
    });

    test('IDs únicos, nomes únicos e correções só em IDs que existem', () {
      final ids = sampleExercises.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
      final names = sampleExercises.map((e) => e.name.toLowerCase()).toList();
      expect(names.toSet().length, names.length);
      for (final id in sampleExerciseCorrections.keys) {
        expect(ids, contains(id));
      }
      expect(sampleExercises.length, 71); // 67 + 4 versões gerais novas
    });

    test('unilaterais, prancha por tempo e as 4 versões gerais novas', () {
      Exercise byId(String id) => sampleExercises.firstWhere((e) => e.id == id);
      for (final id in [
        'dumbbell_row',
        'bulgarian_split_squat',
        'lunge',
        'side_lunge',
        'step_up',
        'single_leg_balance',
        'cable_kickback',
        'cable_lateral_raise',
      ]) {
        expect(byId(id).isUnilateral, isTrue, reason: id);
      }
      expect(byId('plank').tracksDuration, isTrue);
      expect(byId('pull_up').equipment, 'Barra fixa');
      expect(byId('med_ball_slam').equipment, 'Bola medicinal');
      expect(byId('jump_rope').equipment, 'Corda');
      for (final id in [
        'close_grip_lat_pulldown',
        'cable_curl',
        'machine_rear_delt_fly',
        'cable_lateral_raise',
      ]) {
        final e = byId(id);
        expect(e.professionalReviewPending, isTrue, reason: id);
        expect(e.videoUrl, isEmpty, reason: 'não inventar vídeo: $id');
        expect(e.id.startsWith('pt_'), isFalse);
      }
    });

    test('taxonomia de seed: grupos e equipamentos aprovados, IDs antigos mantidos', () {
      expect(sampleMuscleGroups.map((g) => g.name).toSet(), groups);
      expect(sampleEquipment.map((e) => e.name).toSet(), equipment);
      final groupIds = sampleMuscleGroups.map((g) => g.id).toSet();
      expect(
        groupIds,
        containsAll([
          'peito',
          'costas',
          'ombro',
          'abdomen',
          'gluteos',
          'panturrilha',
          'corpo_todo',
        ]),
      );
      final equipIds = sampleEquipment.map((e) => e.id).toSet();
      expect(
        equipIds,
        containsAll(['peso_do_corpo', 'esteira_bike', 'barra', 'halteres']),
      );
    });
  });

  group('plano do Mattheus continua abrindo igual', () {
    final fixture = jsonDecode(
      File('test/fixtures/library/plano_mattheus.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final plan = TrainingPlan.fromMap(
      'plano',
      Map<String, dynamic>.from(fixture['plan'] as Map),
    );
    final custom = {
      for (final e in (fixture['customExercises'] as Map).entries)
        e.key as String: Exercise.fromMap(
          e.key as String,
          Map<String, dynamic>.from(e.value as Map),
        ),
    };
    final library = {for (final e in sampleExercises) e.id: e};

    test('mesmos dias, exercícios e prescrições', () {
      expect(plan.title, 'Treino Matheus');
      expect(plan.workouts.map((w) => w.exercises.length).toList(), [
        9,
        6,
        8,
        5,
        8,
      ]);
      final first = plan.workouts.first.exercises.first;
      expect(first.exerciseId, 'lat_pulldown');
      expect(first.targetSets, 3);
      expect(first.targetReps, '10');
      expect(first.targetWeightsKg, '25');
      final aberto = plan.workouts.last.exercises.first;
      expect(prescriptionSetsReps(aberto), 'Séries em aberto');
    });

    test('todo exercício do plano existe (biblioteca ou personal)', () {
      for (final w in plan.workouts) {
        for (final e in w.exercises) {
          expect(
            library.containsKey(e.exerciseId) ||
                custom.containsKey(e.exerciseId),
            isTrue,
            reason: e.exerciseId,
          );
        }
      }
      // Os exercícios do personal não foram tocados: continuam com o grupo
      // que tinham (mesmo os nomes antigos são entendidos).
      expect(custom['pt_corrida_caminhada']!.muscleGroup, 'Pernas');
      expect(custom.length, 11);
    });

    test('cada dia abre no treino com as séries prescritas', () {
      for (var i = 0; i < plan.workouts.length; i++) {
        final provider = WorkoutProvider(
          firestoreService: MockFirestoreService(),
        );
        provider.startFromPlan('aluno-teste', plan, i);
        final active = provider.activeWorkout!;
        final expected = plan.workouts[i].exercises;
        expect(active.exercises.length, expected.length);
        for (var j = 0; j < expected.length; j++) {
          expect(active.exercises[j].exerciseId, expected[j].exerciseId);
          expect(active.exercises[j].exerciseName, expected[j].exerciseName);
          expect(
            active.exercises[j].sets.length,
            expected[j].targetSets.clamp(1, 20),
          );
        }
        provider.cancelWorkout();
      }
    });
  });
}
