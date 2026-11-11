import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/features/progress/logic/progress_record_provider.dart';
import 'package:newfitness/features/progress/presentation/exercise_progress_list.dart';
import 'package:newfitness/shared/models/exercise_progress_record.dart';

import '../helpers/mocks.dart';

ProgressPoint _p(int day, double load, [double? e1rm]) => ProgressPoint(
  date: DateTime(2026, 1, day),
  topSetLoadKg: load,
  totalVolume: load * 10,
  e1rmKg: e1rm,
);

void main() {
  test('só pontos com 1RM entram no gráfico', () {
    expect(e1rmPoints([_p(1, 40), _p(2, 42, 55), _p(3, 45, 58)]), hasLength(2));
  });

  Future<void> pump(WidgetTester tester, ExerciseProgressRecord record) async {
    final firestore = MockFirestoreService();
    when(() => firestore.watchProgressRecords('u1'))
        .thenAnswer((_) => Stream.value([record]));
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ProgressRecordProvider(firestoreService: firestore),
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: ExerciseProgressList(uid: 'u1')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('mostra o 1RM estimado e o gráfico ao longo do tempo', (
    tester,
  ) async {
    await pump(
      tester,
      ExerciseProgressRecord(
        exerciseId: 'supino',
        exerciseName: 'Supino',
        bestLoadKg: 45,
        lastLoadKg: 45,
        lastPerformedAt: DateTime(2026, 1, 3),
        totalSessions: 3,
        bestE1rmKg: 58,
        history: [_p(1, 40), _p(2, 42, 55), _p(3, 45, 58)],
      ),
    );
    expect(find.text('1RM estimado'), findsOneWidget);
    expect(find.text('58 kg'), findsOneWidget);
    expect(find.byKey(const ValueKey('e1rm-chart')), findsOneWidget);
    expect(find.byType(E1rmChart), findsOneWidget);
  });

  testWidgets('registro antigo, sem 1RM: sem gráfico de 1RM', (tester) async {
    await pump(
      tester,
      ExerciseProgressRecord(
        exerciseId: 'supino',
        exerciseName: 'Supino',
        bestLoadKg: 45,
        lastLoadKg: 45,
        lastPerformedAt: DateTime(2026, 1, 3),
        totalSessions: 2,
        history: [_p(1, 40), _p(2, 45)],
      ),
    );
    expect(find.text('1RM estimado'), findsNothing);
    expect(find.byType(E1rmChart), findsNothing);
  });
}
