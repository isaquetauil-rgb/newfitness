import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:newfitness/features/workout/logic/training_plan_provider.dart';
import 'package:newfitness/shared/models/training_plan.dart';

import '../helpers/mocks.dart';

void main() {
  late MockFirestoreService firestoreService;
  late TrainingPlanProvider provider;

  setUpAll(() {
    registerFallbackValue(
      TrainingPlan(
        id: '',
        studentUid: '',
        instructorUid: '',
        title: '',
        createdAt: DateTime(2024),
      ),
    );
  });

  setUp(() {
    firestoreService = MockFirestoreService();
    provider = TrainingPlanProvider(firestoreService: firestoreService);
  });

  final plan = TrainingPlan(
    id: 'p1',
    studentUid: 'student1',
    instructorUid: 'instructor1',
    title: 'Treino de pernas',
    instructions: 'Foco em quadríceps',
    workouts: const [
      TrainingSubWorkout(
        label: 'Treino A',
        exercises: [
          PlanExercise(
            exerciseId: 'squat',
            exerciseName: 'Agachamento livre',
            targetSets: 4,
            targetReps: '8-10',
          ),
        ],
      ),
    ],
    createdAt: DateTime(2024, 1, 1),
  );

  test('watchPlans delega ao FirestoreService', () async {
    final controller = StreamController<List<TrainingPlan>>();
    when(() => firestoreService.watchTrainingPlans('student1'))
        .thenAnswer((_) => controller.stream);

    final future = provider.watchPlans('student1').first;
    controller.add([plan]);
    final result = await future;

    expect(result, [plan]);
    await controller.close();
  });

  test('savePlan delega ao FirestoreService', () async {
    when(() => firestoreService.saveTrainingPlan(any()))
        .thenAnswer((_) async {});

    await provider.savePlan(plan);

    verify(() => firestoreService.saveTrainingPlan(plan)).called(1);
  });

  test('deletePlan delega ao FirestoreService', () async {
    when(() => firestoreService.deleteTrainingPlan('student1', 'p1'))
        .thenAnswer((_) async {});

    await provider.deletePlan('student1', 'p1');

    verify(() => firestoreService.deleteTrainingPlan('student1', 'p1'))
        .called(1);
  });
}
