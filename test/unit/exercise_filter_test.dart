import 'package:flutter_test/flutter_test.dart';

import 'package:newfitness/features/exercises/logic/exercise_filter.dart';
import 'package:newfitness/shared/models/exercise.dart';

void main() {
  const benchPress = Exercise(
    id: 'bench_press',
    name: 'Supino reto',
    muscleGroup: 'Peito',
    equipment: 'Barra',
    description: '',
    videoUrl: '',
    difficultyLevel: 'intermediario',
    category: 'forca',
    objectives: ['forca', 'hipertrofia'],
  );

  test('filtro vazio aceita qualquer exercício', () {
    expect(const ExerciseFilter().matches(benchPress), isTrue);
    expect(const ExerciseFilter().isEmpty, isTrue);
  });

  test('filtra por equipamento', () {
    final filter = const ExerciseFilter(equipment: {'Halteres'});
    expect(filter.matches(benchPress), isFalse);
    expect(filter.copyWith(equipment: {'Barra'}).matches(benchPress), isTrue);
  });

  test('filtra por nível de dificuldade', () {
    final filter = const ExerciseFilter(difficultyLevels: {'avancado'});
    expect(filter.matches(benchPress), isFalse);
    expect(
      filter.copyWith(difficultyLevels: {'intermediario'}).matches(benchPress),
      isTrue,
    );
  });

  test('filtra por objetivo (basta um objetivo do exercício bater)', () {
    final filter = const ExerciseFilter(objectives: {'resistencia'});
    expect(filter.matches(benchPress), isFalse);
    expect(
      filter.copyWith(objectives: {'hipertrofia'}).matches(benchPress),
      isTrue,
    );
  });

  test('combina critérios com E — precisa bater em todos os ativos', () {
    final filter = const ExerciseFilter(
      equipment: {'Barra'},
      difficultyLevels: {'avancado'},
    );
    expect(filter.matches(benchPress), isFalse);
  });

  test('activeCount soma os critérios selecionados em todas as categorias', () {
    final filter = const ExerciseFilter(
      equipment: {'Barra', 'Halteres'},
      difficultyLevels: {'avancado'},
    );
    expect(filter.activeCount, 3);
  });
}
