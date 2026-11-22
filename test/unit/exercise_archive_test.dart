import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:newfitness/features/body_map/logic/muscle_map_logic.dart';
import 'package:newfitness/features/instructor/logic/custom_exercise_provider.dart';
import 'package:newfitness/features/workout/logic/workout_provider.dart';
import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/models/logged_exercise.dart';
import 'package:newfitness/shared/models/workout.dart';
import 'package:newfitness/shared/models/workout_set.dart';

import '../helpers/mocks.dart';

Exercise _ex(
  String id,
  String group, {
  List<String> sec = const [],
  bool archived = false,
}) => Exercise(
  id: id,
  name: id,
  muscleGroup: group,
  equipment: '',
  description: '',
  videoUrl: '',
  secondaryMuscles: sec,
  archived: archived,
);

LoggedExercise _logged(String id, {String? group, List<String>? sec}) =>
    LoggedExercise(
      exerciseId: id,
      exerciseName: id,
      muscleGroup: group,
      secondaryMuscles: sec,
      sets: [WorkoutSet(reps: 8, weightKg: 40, completed: true)],
    );

void main() {
  final now = DateTime(2026, 11, 19, 18);
  Workout w(List<LoggedExercise> ex) => Workout(
    id: 'w',
    userId: 'u',
    date: DateTime(2026, 11, 17),
    exercises: ex,
  );

  group('retrato dos músculos ao finalizar', () {
    test('grava grupo e secundários da biblioteca', () {
      final out = WorkoutProvider.withMuscleSnapshot(
        [_logged('supino')],
        (id) =>
            id == 'supino' ? _ex('supino', 'Peito', sec: ['Tríceps']) : null,
      );
      expect(out.single.muscleGroup, 'Peito');
      expect(out.single.secondaryMuscles, ['Tríceps']);
    });

    test('exercício que a biblioteca não acha mantém o que tinha', () {
      final out = WorkoutProvider.withMuscleSnapshot([
        _logged('own_x', group: 'Costas'),
      ], (_) => null);
      expect(out.single.muscleGroup, 'Costas');
    });

    test('sem lookup: nada muda', () {
      final list = [_logged('supino')];
      expect(WorkoutProvider.withMuscleSnapshot(list, null), same(list));
    });

    test('o retrato vai para o Firestore e volta', () {
      final m = _logged('supino', group: 'Peito', sec: ['Tríceps']).toMap();
      expect(m['muscleGroup'], 'Peito');
      expect(m['secondaryMuscles'], ['Tríceps']);
      final back = LoggedExercise.fromMap(m);
      expect(back.secondaryMuscles, ['Tríceps']);
      // Treino antigo, sem retrato:
      expect(_logged('x').toMap().containsKey('secondaryMuscles'), isFalse);
    });
  });

  group('mapa usa o retrato', () {
    test('exercício apagado de vez continua no mapa pelo retrato', () {
      final data = computeMuscleMap(
        [
          w([
            _logged('apagado', group: 'Peito', sec: ['Tríceps']),
          ]),
        ],
        now,
        (_) => null,
      );
      expect(data.weekSets[MuscleRegion.chest], 1);
      expect(data.weekSets[MuscleRegion.triceps], 0.5);
    });

    test('retrato vale mais que a biblioteca editada depois', () {
      final data = computeMuscleMap(
        [
          w([_logged('x', group: 'Peito')]),
        ],
        now,
        (_) => _ex('x', 'Costas'),
      );
      expect(data.weekSets.keys, [MuscleRegion.chest]);
    });

    test(
      'treino antigo sem retrato busca na biblioteca (inclusive arquivado)',
      () {
        final data = computeMuscleMap(
          [
            w([_logged('x')]),
          ],
          now,
          (_) => _ex('x', 'Costas', archived: true),
        );
        expect(data.weekSets.keys, [MuscleRegion.upperBack]);
      },
    );
  });

  group('arquivar', () {
    test('campo archived só é gravado quando true', () {
      expect(_ex('a', 'Peito').toMap().containsKey('archived'), isFalse);
      final m = _ex('a', 'Peito', archived: true).toMap();
      expect(m['archived'], isTrue);
      expect(Exercise.fromMap('a', m).archived, isTrue);
      expect(Exercise.fromMap('a', const {}).archived, isFalse);
    });

    test(
      'biblioteca do personal esconde arquivados, histórico vê todos',
      () async {
        final fs = MockFirestoreService();
        final storage = MockStorageService();
        when(() => fs.watchCustomExercises('p')).thenAnswer(
          (_) => Stream.value([
            _ex('a', 'Peito'),
            _ex('b', 'Costas', archived: true),
          ]),
        );
        final provider = CustomExerciseProvider(
          firestoreService: fs,
          storageService: storage,
        );
        expect((await provider.watchExercises('p').first).map((e) => e.id), [
          'a',
        ]);
        expect(
          (await provider.watchExercises('p', includeArchived: true).first).map(
            (e) => e.id,
          ),
          ['a', 'b'],
        );
      },
    );
  });
}
