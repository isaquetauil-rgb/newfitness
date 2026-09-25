import 'package:flutter_test/flutter_test.dart';

import 'package:newfitness/features/progress/logic/evolution_summary.dart';
import 'package:newfitness/shared/models/body_photo.dart';
import 'package:newfitness/shared/models/physical_assessment.dart';

PhysicalAssessment _a(
  String id,
  DateTime date, {
  double? weight,
  double? height,
  double? fat,
  Map<String, double> m = const {},
}) => PhysicalAssessment(
  id: id,
  userId: 'student1',
  date: date,
  weightKg: weight,
  heightCm: height,
  bodyFatPercent: fat,
  measurementsCm: m,
);

void main() {
  group('PhysicalAssessment', () {
    test('lê documento ANTIGO (sem campos novos) sem quebrar', () {
      final a = PhysicalAssessment.fromMap('old', {
        'userId': 'student1',
        'date': 1700000000000,
        'weightKg': 82,
        'bodyFatPercent': null,
        'measurementsCm': {'waist': 90, 'arm': 35},
        'recordedBy': 'instructor',
        'notes': null,
      });
      expect(a.weightKg, 82);
      expect(a.heightCm, isNull);
      expect(a.createdByUid, isNull);
      expect(a.recordedBy, AssessmentSource.instructor);
      expect(a.measurementsCm, {'waist': 90.0, 'arm': 35.0});
      expect(BodyMeasurement.labelOf('arm'), 'Braço (sem lado)');
    });

    test('toMap/fromMap preserva todos os campos', () {
      final original = PhysicalAssessment(
        id: 'x',
        userId: 'student1',
        date: DateTime(2024, 3, 1),
        weightKg: 80,
        heightCm: 175,
        bodyFatPercent: 20,
        bodyFatMethod: BodyFatMethod.skinfold,
        muscleMassKg: 35,
        measurementsCm: const {BodyMeasurement.leftCalf: 38},
        recordedBy: AssessmentSource.instructor,
        createdByUid: 'instructor1',
        createdByName: 'Prof',
        createdAt: DateTime(2024, 3, 1, 9),
        updatedAt: DateTime(2024, 3, 2),
        notes: 'obs',
      );
      final copy = PhysicalAssessment.fromMap('x', original.toMap());
      expect(copy.toMap(), original.toMap());
    });

    test('IMC calculado (nunca gravado) e com altura de fallback', () {
      final a = _a('1', DateTime(2024), weight: 80, height: 200);
      expect(a.bmi(), closeTo(20, 0.001));
      expect(a.toMap().containsKey('bmi'), isFalse);
      final noHeight = _a('2', DateTime(2024), weight: 81);
      expect(noHeight.bmi(), isNull);
      expect(noHeight.bmi(fallbackHeightCm: 180), closeTo(25, 0.001));
    });

    test('medida desconhecida (versão futura) é exibida pela chave', () {
      expect(BodyMeasurement.labelOf('wrist'), 'wrist');
      final keys = BodyMeasurement.keysIn([
        _a('1', DateTime(2024), m: {'wrist': 16, 'waist': 80, 'arm': 30}),
      ]);
      expect(keys, ['waist', 'arm', 'wrist']);
    });
  });

  group('EvolutionSummary', () {
    final summary = EvolutionSummary([
      // fora de ordem de propósito
      _a('c', DateTime(2024, 3, 1), weight: 76, m: {'waist': 84}),
      _a('a', DateTime(2024, 1, 1), weight: 80, height: 175, m: {'waist': 90}),
      _a('b', DateTime(2024, 2, 1), fat: 22, m: {'rightArm': 35}),
    ]);

    test('ordena cronologicamente', () {
      expect(summary.chronological.map((a) => a.id), ['a', 'b', 'c']);
      expect(summary.first!.id, 'a');
      expect(summary.latest!.id, 'c');
    });

    test('peso atual e variação desde o primeiro peso', () {
      expect(summary.currentWeightKg, 76);
      expect(summary.initialWeightKg, 80);
      expect(summary.weightChangeKg, -4);
    });

    test('dados atuais pegam o último valor registrado de cada métrica', () {
      expect(summary.currentHeightCm, 175);
      expect(summary.currentBodyFatPercent, 22);
      expect(summary.currentMeasurements, {'waist': 84.0, 'rightArm': 35.0});
      expect(summary.currentBmi, closeTo(76 / (1.75 * 1.75), 0.001));
    });

    test('variação é nula com um único peso', () {
      final single = EvolutionSummary([
        _a('a', DateTime(2024), weight: 80),
        _a('b', DateTime(2024, 2), m: {'waist': 80}),
      ]);
      expect(single.weightChangeKg, isNull);
      expect(EvolutionSummary(const []).currentWeightKg, isNull);
    });

    test('série só inclui pontos registrados', () {
      final s = summary.series((a) => a.weightKg);
      expect(s.map((p) => p.$2), [80, 76]);
    });

    test('comparação inicial VS atual com diferença', () {
      final rows = summary.compare(summary.first!, summary.latest!);
      final weight = rows.firstWhere((r) => r.key == 'weightKg');
      expect(weight.before, 80);
      expect(weight.after, 76);
      expect(weight.difference, -4);
      final waist = rows.firstWhere((r) => r.key == 'waist');
      expect(waist.difference, -6);
      // altura só na primeira → aparece, mas sem diferença
      final height = rows.firstWhere((r) => r.key == 'heightCm');
      expect(height.after, isNull);
      expect(height.difference, isNull);
      // nada de % de gordura em nenhuma das duas → linha omitida
      expect(rows.any((r) => r.key == 'bodyFatPercent'), isFalse);
    });
  });

  group('formatação', () {
    test('formatMetric usa vírgula e remove zeros', () {
      expect(formatMetric(80), '80');
      expect(formatMetric(80.25), '80,3');
      expect(formatMetric(75.5), '75,5');
    });

    test('formatDifference tem sinal explícito', () {
      expect(formatDifference(-4), '-4');
      expect(formatDifference(1.5), '+1,5');
      expect(formatDifference(0.01), '0');
      expect(formatDifference(-6), '-6');
    });
  });

  group('BodyPhoto', () {
    test('foto ANTIGA com imageUrl continua legível', () {
      final p = BodyPhoto.fromMap('p', {
        'userId': 'student1',
        'date': 1700000000000,
        'imageUrl': 'https://x/y.jpg',
        'note': null,
      });
      expect(p.imageUrl, 'https://x/y.jpg');
      expect(p.storagePath, isNull);
      expect(p.position, isNull);
      expect(PhotoPosition.labelOf(p.position), 'Sem posição');
    });

    test('foto nova grava só campos preenchidos (lista das regras)', () {
      final p = BodyPhoto(
        id: '',
        userId: 'student1',
        date: DateTime(2024),
        position: PhotoPosition.back,
        storagePath: 'users/student1/body_photos/1.jpg',
        uploadedByUid: 'student1',
      );
      expect(p.toMap().keys.toSet(), {
        'userId',
        'date',
        'position',
        'storagePath',
        'uploadedByUid',
      });
      expect(PhotoPosition.labelOf('new_position'), 'Outra');
    });
  });
}
