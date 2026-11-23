import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newfitness/features/body_map/logic/missing_muscle_groups.dart';
import 'package:newfitness/features/body_map/logic/muscle_map_logic.dart';
import 'package:newfitness/features/body_map/presentation/complete_muscle_groups_screen.dart';
import 'package:newfitness/features/exercises/logic/exercise_similarity.dart';
import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/models/logged_exercise.dart';
import 'package:newfitness/shared/models/sample_exercises.dart';
import 'package:newfitness/shared/models/sample_functional_exercises.dart';
import 'package:newfitness/shared/models/workout.dart';
import 'package:newfitness/shared/models/workout_set.dart';

final _pool = [...sampleExercises, ...sampleFunctionalExercises];
Exercise? _lookup(String id) {
  for (final e in _pool) {
    if (e.id == id) return e;
  }
  return null;
}

LoggedExercise _l(String id, String name, {String? group}) => LoggedExercise(
  exerciseId: id,
  exerciseName: name,
  muscleGroup: group,
  sets: [WorkoutSet(reps: 8, weightKg: 20, completed: true)],
);

Workout _w(String id, DateTime d, List<LoggedExercise> ex) =>
    Workout(id: id, userId: 'u', date: d, exercises: ex);

void main() {
  final history = [
    _w('a', DateTime(2026, 11, 16), [
      _l('bench_press', 'Supino reto'),
      _l('own_remada_cavalinho', 'Remada cavalinho'),
    ]),
    _w('b', DateTime(2026, 11, 17), [
      _l('own_remada_cavalinho', 'Remada cavalinho'),
      _l('own_com_grupo', 'Com grupo', group: 'Peito'),
      _l('apagado_de_vez', 'Leg press antigo'),
    ]),
  ];

  test('acha só os exercícios que o mapa não consegue colocar no corpo', () {
    final missing = exercisesWithoutGroup(history, _lookup);
    expect(missing.map((m) => m.exerciseId), [
      'apagado_de_vez',
      'own_remada_cavalinho',
    ]);
    expect(
      missing
          .firstWhere((m) => m.exerciseId == 'own_remada_cavalinho')
          .workouts,
      2,
    );
  });

  test('sugere o grupo pelo nome (exercise_similarity)', () {
    // Biblioteca padronizada (Etapa 2): leg press é de quadríceps.
    expect(suggestMuscleGroup('Leg press antigo', _pool), 'Quadríceps');
    expect(suggestMuscleGroup('Supino reto inclinado', _pool), 'Peito');
    expect(suggestMuscleGroup('Xyzw qwerty', _pool), isNull);
  });

  test('completar grava o grupo em todos os treinos e entra no mapa', () {
    final changed = withMuscleGroup(history, 'own_remada_cavalinho', 'Costas');
    expect(changed.map((w) => w.id), ['a', 'b']);
    // Só o exercício escolhido muda; o resto do treino fica igual.
    final b = changed.firstWhere((w) => w.id == 'b');
    expect(b.exercises[0].muscleGroup, 'Costas');
    expect(b.exercises[1].muscleGroup, 'Peito');
    expect(b.exercises[2].muscleGroup, isNull);

    final after = [
      for (final w in history)
        changed.firstWhere((c) => c.id == w.id, orElse: () => w),
    ];
    final data = computeMuscleMap(after, DateTime(2026, 11, 19), _lookup);
    expect(data.weekSets[MuscleRegion.upperBack], 2);
    expect(exercisesWithoutGroup(after, _lookup).map((m) => m.exerciseId), [
      'apagado_de_vez',
    ]);
  });

  test('personal: exercícios próprios sem grupo (arquivados não contam)', () {
    Exercise ex(String id, String group, {bool archived = false}) => Exercise(
      id: id,
      name: id,
      muscleGroup: group,
      equipment: '',
      description: '',
      videoUrl: '',
      archived: archived,
    );
    final list = [ex('a', ''), ex('b', 'Peito'), ex('c', '', archived: true)];
    expect(customWithoutGroup(list).map((e) => e.id), ['a']);
    final fixed = withExerciseGroup(list.first, 'Costas');
    expect(fixed.muscleGroup, 'Costas');
    expect(fixed.id, 'a');
  });

  testWidgets('tela de completar vem com a sugestão e salva', (tester) async {
    final saved = <String, String>{};
    await tester.pumpWidget(
      MaterialApp(
        home: CompleteMuscleGroupsScreen(
          items: const [
            MissingGroupItem(
              id: 'x',
              name: 'Remada cavalinho',
              suggestion: 'Costas',
            ),
            MissingGroupItem(id: 'y', name: 'Sem ideia'),
          ],
          onSave: (id, g) async => saved[id] = g,
        ),
      ),
    );
    expect(find.text('Sugerido pelo nome'), findsOneWidget);
    expect(find.text('Salvar 1 exercício'), findsOneWidget);
    await tester.tap(find.text('Salvar 1 exercício'));
    await tester.pumpAndSettle();
    expect(saved, {'x': 'Costas'});
  });
}
