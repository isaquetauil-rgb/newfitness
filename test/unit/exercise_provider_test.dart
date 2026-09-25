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

  test('semeia a biblioteca padrão quando a coleção está vazia', () async {
    ExerciseProvider(firestoreService: firestoreService);
    exercisesController.add(const []);
    await Future<void>.delayed(Duration.zero);

    verify(() => firestoreService.seedExercise(any()))
        .called(sampleExercises.length);
  });

  test('NÃO regrava a biblioteca quando o Firestore já tem exercícios — '
      'preserva edições/exclusões feitas pelo admin', () async {
    ExerciseProvider(firestoreService: firestoreService);
    exercisesController.add(sampleExercises.take(1).toList());
    await Future<void>.delayed(Duration.zero);

    verifyNever(() => firestoreService.seedExercise(any()));
  });

  test('restart refaz a assinatura (ex: após logout/login)', () async {
    final provider = ExerciseProvider(firestoreService: firestoreService);
    provider.restart();
    exercisesController.add(sampleExercises.take(2).toList());
    await Future<void>.delayed(Duration.zero);

    verify(() => firestoreService.watchExercises()).called(2);
    expect(provider.exercises, hasLength(2));
  });

  test('expõe a lista recebida do Firestore via watchExercises', () async {
    final provider = ExerciseProvider(firestoreService: firestoreService);
    final custom = sampleExercises.take(2).toList();

    exercisesController.add(custom);
    await Future<void>.delayed(Duration.zero);

    expect(provider.exercises, custom);
  });
}
