import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:newfitness/features/body_map/logic/muscle_map_logic.dart';
import 'package:newfitness/features/stats/logic/period_stats.dart';
import 'package:newfitness/features/stats/presentation/share_card.dart';
import 'package:newfitness/shared/models/logged_exercise.dart';
import 'package:newfitness/shared/models/workout.dart';
import 'package:newfitness/shared/models/workout_set.dart';
import 'package:newfitness/shared/utils/one_rep_max.dart';

final _workout = Workout(
  id: 'w',
  userId: 'u',
  date: DateTime(2026, 11, 20, 18),
  name: 'Treino A - Peito e tríceps com um nome bem comprido para testar',
  durationSeconds: 3900,
  exercises: [
    LoggedExercise(
      exerciseId: 'bench',
      exerciseName: 'Supino reto',
      sets: [WorkoutSet(weightKg: 60, reps: 8, completed: true)],
    ),
  ],
);

const _records = [
  PersonalRecord(
    exerciseName: 'Supino reto com barra e pegada aberta',
    kind: PersonalRecordKind.load,
    valueKg: 62.5,
  ),
  PersonalRecord(
    exerciseName: 'Supino reto',
    kind: PersonalRecordKind.e1rm,
    valueKg: 77.5,
  ),
  PersonalRecord(
    exerciseName: 'Prancha',
    kind: PersonalRecordKind.duration,
    seconds: 90,
  ),
  PersonalRecord(
    exerciseName: 'Remada',
    kind: PersonalRecordKind.load,
    valueKg: 40,
  ),
];

Future<void> _pump(WidgetTester tester, Widget card) async {
  await tester.binding.setSurfaceSize(const Size(400, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox.fromSize(size: shareCardSize, child: card),
      ),
    ),
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('cartão do treino cabe em 9:16 com nome longo e 4 recordes', (
    tester,
  ) async {
    await _pump(
      tester,
      WorkoutShareCard(
        workout: _workout,
        records: _records,
        muscles: const {MuscleRegion.chest: 1, MuscleRegion.triceps: 0.5},
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('NewFitness'), findsOneWidget);
    expect(find.text('Recordes de hoje'), findsOneWidget);
    expect(find.text('+ 1 recorde'), findsOneWidget);
    expect(find.text('1 h 5 min'), findsOneWidget);
    expect(tester.getSize(find.byType(ShareCardFrame)), shareCardSize);
  });

  testWidgets('cartão do mês com tudo preenchido', (tester) async {
    final stats = PeriodStats(
      period: Period.containing(PeriodKind.month, DateTime(2026, 11, 1)),
      workouts: 14,
      totalSeconds: 14 * 3600,
      volumeKg: 123456,
      topExercise: const TopExercise('Agachamento livre', 9, 36),
      records: [..._records, ..._records],
      consecutiveWeeks: 4,
    );
    await _pump(tester, PeriodShareCard(stats: stats));
    expect(tester.takeException(), isNull);
    expect(find.text('Meu mês'), findsOneWidget);
    expect(find.text('Novembro de 2026'), findsOneWidget);
    expect(find.text('8 recordes batidos'), findsOneWidget);
  });

  testWidgets('cartão do ano vazio', (tester) async {
    final stats = PeriodStats.from(
      const [],
      Period.containing(PeriodKind.year, DateTime(2026, 1, 1)),
    );
    await _pump(tester, PeriodShareCard(stats: stats));
    expect(tester.takeException(), isNull);
    expect(find.text('2026'), findsOneWidget);
    expect(find.text('Nenhum recorde no período'), findsOneWidget);
  });
}
