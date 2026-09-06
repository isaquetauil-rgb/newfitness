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

  test('sincroniza a biblioteca padrão ao iniciar', () async {
    ExerciseProvider(firestoreService: firestoreService);
    await Future<void>.delayed(Duration.zero);

    verify(() => firestoreService.seedExercise(any()))
        .called(sampleExercises.length);
  });

  test(
    'sincroniza de novo mesmo quando o Firestore já tem exercícios — '
    'corrige documentos desatualizados (ex: sem descrição/passo-a-passo)',
    () async {
      ExerciseProvider(firestoreService: firestoreService);
      exercisesController.add(sampleExercises.take(1).toList());
      await Future<void>.delayed(Duration.zero);

      verify(() => firestoreService.seedExercise(any()))
          .called(sampleExercises.length);
    },
  );

  test('expõe a lista recebida do Firestore via watchExercises', () async {
    final provider = ExerciseProvider(firestoreService: firestoreService);
    final custom = sampleExercises.take(2).toList();

    exercisesController.add(custom);
    await Future<void>.delayed(Duration.zero);

    expect(provider.exercises, custom);
  });
}
