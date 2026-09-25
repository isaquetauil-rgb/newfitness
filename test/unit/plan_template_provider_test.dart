import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:newfitness/features/instructor/logic/plan_template_provider.dart';
import 'package:newfitness/shared/models/plan_template.dart';

import '../helpers/mocks.dart';

void main() {
  late MockFirestoreService firestoreService;
  late PlanTemplateProvider provider;

  setUpAll(() {
    registerFallbackValue(
      PlanTemplate(
        id: '',
        instructorUid: '',
        title: '',
        createdAt: DateTime(2024),
      ),
    );
  });

  setUp(() {
    firestoreService = MockFirestoreService();
    provider = PlanTemplateProvider(firestoreService: firestoreService);
  });

  final template = PlanTemplate(
    id: 't1',
    instructorUid: 'instructor1',
    title: 'Hipertrofia - iniciante',
    createdAt: DateTime(2024, 1, 1),
  );

  test('watchTemplates delega ao FirestoreService', () async {
    final controller = StreamController<List<PlanTemplate>>();
    when(() => firestoreService.watchPlanTemplates('instructor1'))
        .thenAnswer((_) => controller.stream);

    final future = provider.watchTemplates('instructor1').first;
    controller.add([template]);
    final result = await future;

    expect(result, [template]);
    await controller.close();
  });

  test('saveTemplate delega ao FirestoreService', () async {
    when(() => firestoreService.savePlanTemplate(any()))
        .thenAnswer((_) async {});

    await provider.saveTemplate(template);

    verify(() => firestoreService.savePlanTemplate(template)).called(1);
  });

  test('deleteTemplate delega ao FirestoreService', () async {
    when(() => firestoreService.deletePlanTemplate('instructor1', 't1'))
        .thenAnswer((_) async {});

    await provider.deleteTemplate('instructor1', 't1');

    verify(() => firestoreService.deletePlanTemplate('instructor1', 't1'))
        .called(1);
  });
}
