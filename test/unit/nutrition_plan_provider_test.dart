import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:newfitness/features/nutrition/logic/nutrition_plan_provider.dart';
import 'package:newfitness/shared/models/nutrition_plan.dart';

import '../helpers/mocks.dart';

void main() {
  late MockFirestoreService firestoreService;
  late NutritionPlanProvider provider;

  setUpAll(() {
    registerFallbackValue(
      NutritionPlan(
        id: '',
        studentUid: '',
        nutritionistUid: '',
        title: '',
        createdAt: DateTime(2024),
      ),
    );
  });

  setUp(() {
    firestoreService = MockFirestoreService();
    provider = NutritionPlanProvider(firestoreService: firestoreService);
  });

  final plan = NutritionPlan(
    id: 'p1',
    studentUid: 'student1',
    nutritionistUid: 'nutritionist1',
    title: 'Reeducação alimentar',
    meals: const [
      NutritionMeal(label: 'Café da manhã', description: 'Ovos e fruta'),
    ],
    createdAt: DateTime(2024, 1, 1),
  );

  test('watchStudents delega ao FirestoreService', () async {
    final controller = StreamController<List<Map<String, dynamic>>>();
    when(() => firestoreService.watchNutritionStudents('nutritionist1'))
        .thenAnswer((_) => controller.stream);

    final future = provider.watchStudents('nutritionist1').first;
    controller.add([
      {'uid': 'student1', 'name': 'Ana'},
    ]);
    final result = await future;

    expect(result, [
      {'uid': 'student1', 'name': 'Ana'},
    ]);
    await controller.close();
  });

  test('watchPlans delega ao FirestoreService', () async {
    final controller = StreamController<List<NutritionPlan>>();
    when(() => firestoreService.watchNutritionPlans('student1'))
        .thenAnswer((_) => controller.stream);

    final future = provider.watchPlans('student1').first;
    controller.add([plan]);
    final result = await future;

    expect(result, [plan]);
    await controller.close();
  });

  test('savePlan delega ao FirestoreService', () async {
    when(() => firestoreService.saveNutritionPlan(any()))
        .thenAnswer((_) async {});

    await provider.savePlan(plan);

    verify(() => firestoreService.saveNutritionPlan(plan)).called(1);
  });

  test('deletePlan delega ao FirestoreService', () async {
    when(() => firestoreService.deleteNutritionPlan('student1', 'p1'))
        .thenAnswer((_) async {});

    await provider.deletePlan('student1', 'p1');

    verify(() => firestoreService.deleteNutritionPlan('student1', 'p1'))
        .called(1);
  });
}
