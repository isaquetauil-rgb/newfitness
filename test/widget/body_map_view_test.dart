import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newfitness/features/body_map/logic/muscle_map_logic.dart';
import 'package:newfitness/features/body_map/presentation/body_map_screen.dart';
import 'package:newfitness/features/body_map/presentation/body_map_view.dart';

void main() {
  for (final female in [false, true]) {
    testWidgets('desenha o corpo (${female ? 'feminino' : 'masculino'})', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 300,
            height: 300,
            child: BodyMapView(
              intensities: const {
                MuscleRegion.chest: 1,
                MuscleRegion.hamstring: 0.5,
              },
              color: Colors.green,
              female: female,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(BodyMapView), findsOneWidget);
    });
  }

  test('formatSets usa vírgula e singular', () {
    expect(formatSets(1), '1 série');
    expect(formatSets(1.5), '1,5 séries');
    expect(formatSets(6), '6 séries');
  });
}
