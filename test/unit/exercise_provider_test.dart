import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:newfitness/features/exercises/logic/exercise_provider.dart';
import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/models/sample_exercises.dart';

import '../helpers/mocks.dart';

void main() {
  late MockFirestoreService firestoreService;
  late StreamController<List<Exercise>> exercisesController;

  setUpAll(() {
    registerFallbackValue(
      const Exercise(
        id: '',
        name: '',
        muscleGroup: '',
        equipment: '',
        description: '',
        videoUrl: '',
      ),
    );
  });

  setUp(() {
    firestoreService = MockFirestoreService();
    exercisesController = StreamController<List<Exercise>>.broadcast();
    when(() => firestoreService.watchExercises())
        .thenAnswer((_) => exercisesController.stream);
    when(() => firestoreService.seedExercise(any())).thenAnswer((_) async {});
  });

  tearDown(() => exercisesController.close());

  test(
    'quando o Firestore está vazio, popula com a biblioteca padrão',
    () async {
      ExerciseProvider(firestoreService: firestoreService);
      exercisesController.add([]);
      await Future<void>.delayed(Duration.zero);

      verify(() => firestoreService.seedExercise(any()))
          .called(sampleExercises.length);
    },
  );

  test('quando o Firestore já tem exercícios, não popula de novo', () async {
    ExerciseProvider(firestoreService: firestoreService);
    exercisesController.add(sampleExercises.take(1).toList());
    await Future<void>.delayed(Duration.zero);

    verifyNever(() => firestoreService.seedExercise(any()));
  });
}
