import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newfitness/features/progress/presentation/workout_details.dart';
import 'package:newfitness/shared/models/logged_exercise.dart';
import 'package:newfitness/shared/models/workout.dart';
import 'package:newfitness/shared/models/workout_set.dart';

void main() {
  test('describeSet mostra carga, distância, tempo e RPE', () {
    expect(
      describeSet(WorkoutSet(reps: 8, weightKg: 62.5, rpe: 8)),
      '8 × 62,5 kg · RPE 8',
    );
    expect(
      describeSet(WorkoutSet(weightKg: 24, distanceMeters: 40, seconds: 60)),
      '24 kg · 40 m · 1 min',
    );
    expect(
      describeSet(WorkoutSet(distanceMeters: 5000, seconds: 1800)),
      '5 km · 30 min',
    );
    expect(
      describeSet(WorkoutSet(reps: 12, weightKg: 20, type: SetType.warmup)),
      'Aquecimento: 12 × 20 kg',
    );
  });

  testWidgets('histórico mostra anotações da série e do treino', (
    tester,
  ) async {
    final w = Workout(
      id: 'w',
      userId: 'u',
      date: DateTime(2026, 1, 17),
      notes: 'Sábado cedo',
      exercises: [
        LoggedExercise(
          exerciseId: 'squat',
          exerciseName: 'Agachamento livre',
          sets: [
            WorkoutSet(reps: 5, weightKg: 100, rpe: 8.5, notes: 'Descer bem'),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: WorkoutDetails(workout: w)),
      ),
    );
    expect(find.text('Agachamento livre'), findsOneWidget);
    expect(find.text('1. 5 × 100 kg · RPE 8,5'), findsOneWidget);
    expect(find.text('“Descer bem”'), findsOneWidget);
    expect(find.text('Sábado cedo'), findsOneWidget);
  });
}
