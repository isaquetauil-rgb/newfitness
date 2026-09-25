import 'package:flutter_test/flutter_test.dart';

import 'package:newfitness/features/exercises/logic/exercise_similarity.dart';
import 'package:newfitness/shared/models/exercise.dart';

void main() {
  const benchPress = Exercise(
    id: 'bench_press',
    name: 'Supino reto',
    muscleGroup: 'Peito',
    equipment: 'Barra',
    description: '',
    videoUrl: '',
    secondaryMuscles: ['Tríceps', 'Ombro'],
    movementPattern: 'Empurrar horizontal',
    difficultyLevel: 'intermediario',
    objectives: ['forca', 'hipertrofia'],
    alternativeExerciseIds: ['dumbbell_bench_press'],
  );

  const dumbbellBenchPress = Exercise(
    id: 'dumbbell_bench_press',
    name: 'Supino reto com halteres',
    muscleGroup: 'Peito',
    equipment: 'Halteres',
    description: '',
    videoUrl: '',
    secondaryMuscles: ['Tríceps', 'Ombro'],
    movementPattern: 'Empurrar horizontal',
    difficultyLevel: 'iniciante',
    objectives: ['hipertrofia'],
  );

  const machineChestPress = Exercise(
    id: 'machine_chest_press',
    name: 'Supino na máquina',
    muscleGroup: 'Peito',
    equipment: 'Máquina',
    description: '',
    videoUrl: '',
    secondaryMuscles: ['Tríceps', 'Ombro'],
    movementPattern: 'Empurrar horizontal',
    difficultyLevel: 'iniciante',
    objectives: ['hipertrofia'],
  );

  const bicepCurl = Exercise(
    id: 'bicep_curl',
    name: 'Rosca direta',
    muscleGroup: 'Braço',
    equipment: 'Barra',
    description: '',
    videoUrl: '',
    movementPattern: 'Isolamento',
    difficultyLevel: 'iniciante',
    objectives: ['hipertrofia'],
  );

  const squat = Exercise(
    id: 'squat',
    name: 'Agachamento livre',
    muscleGroup: 'Pernas',
    equipment: 'Barra',
    description: '',
    videoUrl: '',
    movementPattern: 'Agachamento',
    difficultyLevel: 'intermediario',
    objectives: ['forca'],
  );

  final pool = [
    benchPress,
    dumbbellBenchPress,
    machineChestPress,
    bicepCurl,
    squat,
  ];

  test('a curadoria manual (alternativeExerciseIds) vem primeiro, com score máximo', () {
    final result = findExerciseAlternatives(benchPress, pool);

    expect(result.first.exercise.id, 'dumbbell_bench_press');
    expect(result.first.score, 1.0);
    expect(result.first.curated, isTrue);
  });

  test('não sugere o próprio exercício como alternativa dele mesmo', () {
    final result = findExerciseAlternatives(benchPress, pool);

    expect(result.any((a) => a.exercise.id == benchPress.id), isFalse);
  });

  test('não duplica um exercício já curado quando ele também pontuaria bem sozinho', () {
    final result = findExerciseAlternatives(benchPress, pool);

    final dumbbellMatches = result.where(
      (a) => a.exercise.id == 'dumbbell_bench_press',
    );
    expect(dumbbellMatches, hasLength(1));
  });

  test('ranqueia por semelhança estruturada quando não há curadoria', () {
    final result = findExerciseAlternatives(dumbbellBenchPress, pool);

    // machine_chest_press bate em grupo muscular + padrão de movimento +
    // objetivo; squat e rosca direta (grupo muscular diferente) não devem
    // aparecer com uma pontuação melhor.
    expect(result.first.exercise.id, 'machine_chest_press');
    expect(result.any((a) => a.exercise.id == 'squat'), isFalse);
    expect(result.any((a) => a.exercise.id == 'bicep_curl'), isFalse);
  });

  test('exercícios de grupo muscular totalmente diferente não aparecem como alternativa', () {
    final result = findExerciseAlternatives(squat, pool);

    expect(result, isEmpty);
  });

  test('respeita o limite máximo de resultados', () {
    final bigPool = List.generate(
      20,
      (i) => Exercise(
        id: 'chest_$i',
        name: 'Exercício de peito $i',
        muscleGroup: 'Peito',
        equipment: 'Halteres',
        description: '',
        videoUrl: '',
      ),
    );

    final result = findExerciseAlternatives(benchPress, bigPool, limit: 5);

    expect(result, hasLength(5));
  });

  group('findExerciseVariations', () {
    const benchPressWithVariation = Exercise(
      id: 'bench_press',
      name: 'Supino reto',
      muscleGroup: 'Peito',
      equipment: 'Barra',
      description: '',
      videoUrl: '',
      variationExerciseIds: ['dumbbell_bench_press'],
    );

    test('resolve os ids curados de variação para os exercícios do pool', () {
      final result = findExerciseVariations(benchPressWithVariation, pool);

      expect(result, hasLength(1));
      expect(result.first.id, 'dumbbell_bench_press');
    });

    test('não inclui o próprio exercício mesmo se ele se autorreferenciar', () {
      const selfReferencing = Exercise(
        id: 'bench_press',
        name: 'Supino reto',
        muscleGroup: 'Peito',
        equipment: 'Barra',
        description: '',
        videoUrl: '',
        variationExerciseIds: ['bench_press'],
      );

      final result = findExerciseVariations(selfReferencing, pool);

      expect(result, isEmpty);
    });

    test('ignora ids que não existem no pool', () {
      const withMissingVariation = Exercise(
        id: 'bench_press',
        name: 'Supino reto',
        muscleGroup: 'Peito',
        equipment: 'Barra',
        description: '',
        videoUrl: '',
        variationExerciseIds: ['exercicio_inexistente'],
      );

      final result = findExerciseVariations(withMissingVariation, pool);

      expect(result, isEmpty);
    });
  });

  test('findExerciseAlternatives com excludeIds não repete o que já apareceu como variação', () {
    final result = findExerciseAlternatives(
      benchPress,
      pool,
      excludeIds: {'dumbbell_bench_press'},
    );

    expect(result.any((a) => a.exercise.id == 'dumbbell_bench_press'), isFalse);
  });
}
