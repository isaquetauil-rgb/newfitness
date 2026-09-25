import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:newfitness/features/progress/logic/physical_assessment_provider.dart';
import 'package:newfitness/shared/models/physical_assessment.dart';

import '../helpers/mocks.dart';

void main() {
  late MockFirestoreService firestoreService;
  late PhysicalAssessmentProvider provider;

  setUpAll(() {
    registerFallbackValue(
      PhysicalAssessment(id: '', userId: '', date: DateTime(2024)),
    );
  });

  setUp(() {
    firestoreService = MockFirestoreService();
    provider = PhysicalAssessmentProvider(firestoreService: firestoreService);
  });

  final assessment = PhysicalAssessment(
    id: 'p1',
    userId: 'student1',
    date: DateTime(2024, 1, 1),
    weightKg: 72.5,
    bodyFatPercent: 18,
  );

  test('watchAssessments delega ao FirestoreService', () async {
    final controller = StreamController<List<PhysicalAssessment>>();
    when(() => firestoreService.watchPhysicalAssessments('student1'))
        .thenAnswer((_) => controller.stream);

    final future = provider.watchAssessments('student1').first;
    controller.add([assessment]);
    final result = await future;

    expect(result, [assessment]);
    await controller.close();
  });

  test('addAssessment carimba autor e datas de criação/atualização', () async {
    final now = DateTime(2024, 5, 1, 10);
    provider = PhysicalAssessmentProvider(
      firestoreService: firestoreService,
      clock: () => now,
    );
    when(() => firestoreService.addPhysicalAssessment(any()))
        .thenAnswer((_) async {});

    await provider.addAssessment(
      assessment,
      authorUid: 'instructor1',
      authorName: 'Prof. João',
    );

    final saved =
        verify(() => firestoreService.addPhysicalAssessment(captureAny()))
                .captured
                .single
            as PhysicalAssessment;
    expect(saved.createdByUid, 'instructor1');
    expect(saved.createdByName, 'Prof. João');
    expect(saved.createdAt, now);
    expect(saved.updatedAt, now);
    expect(saved.weightKg, 72.5);
  });

  test(
    'updateAssessment preserva autor, origem e criação do original',
    () async {
      final created = DateTime(2024, 1, 1);
      final now = DateTime(2024, 6, 1);
      provider = PhysicalAssessmentProvider(
        firestoreService: firestoreService,
        clock: () => now,
      );
      final original = PhysicalAssessment(
        id: 'p1',
        userId: 'student1',
        date: created,
        weightKg: 80,
        recordedBy: AssessmentSource.instructor,
        createdByUid: 'instructor1',
        createdAt: created,
      );
      final edited = PhysicalAssessment(
        id: 'p1',
        userId: 'student1',
        date: DateTime(2024, 1, 2),
        weightKg: 79,
        measurementsCm: const {BodyMeasurement.waist: 88},
        // um formulário nunca deveria mandar isto, mas mesmo assim é ignorado:
        recordedBy: AssessmentSource.self,
        createdByUid: 'student1',
      );
      when(() => firestoreService.updatePhysicalAssessment(any()))
          .thenAnswer((_) async {});

      await provider.updateAssessment(original, edited);

      final saved =
          verify(() => firestoreService.updatePhysicalAssessment(captureAny()))
                  .captured
                  .single
              as PhysicalAssessment;
      expect(saved.id, 'p1');
      expect(saved.weightKg, 79);
      expect(saved.date, DateTime(2024, 1, 2));
      expect(saved.measurementsCm, {BodyMeasurement.waist: 88});
      expect(saved.recordedBy, AssessmentSource.instructor);
      expect(saved.createdByUid, 'instructor1');
      expect(saved.createdAt, created);
      expect(saved.updatedAt, now);
    },
  );

  group('canModify (espelha a regra de autoria)', () {
    PhysicalAssessment a({String? author, String source = 'self'}) =>
        PhysicalAssessment(
          id: 'x',
          userId: 'student1',
          date: DateTime(2024),
          recordedBy: source,
          createdByUid: author,
        );

    test('com autor: só o autor pode', () {
      final byInstructor = a(author: 'instructor1', source: 'instructor');
      expect(
        PhysicalAssessmentProvider.canModify(
          byInstructor,
          viewerUid: 'student1',
          viewerIsOwner: true,
        ),
        isFalse,
      );
      expect(
        PhysicalAssessmentProvider.canModify(
          byInstructor,
          viewerUid: 'instructor1',
          viewerIsOwner: false,
        ),
        isTrue,
      );
    });

    test('avaliação antiga (sem autor) segue a origem', () {
      expect(
        PhysicalAssessmentProvider.canModify(
          a(),
          viewerUid: 'student1',
          viewerIsOwner: true,
        ),
        isTrue,
      );
      expect(
        PhysicalAssessmentProvider.canModify(
          a(),
          viewerUid: 'instructor1',
          viewerIsOwner: false,
        ),
        isFalse,
      );
    });
  });

  test('deleteAssessment delega ao FirestoreService', () async {
    when(() => firestoreService.deletePhysicalAssessment('student1', 'p1'))
        .thenAnswer((_) async {});

    await provider.deleteAssessment('student1', 'p1');

    verify(() => firestoreService.deletePhysicalAssessment('student1', 'p1'))
        .called(1);
  });
}
