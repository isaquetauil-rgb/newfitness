import 'package:flutter_test/flutter_test.dart';
import 'package:newfitness/features/home/logic/week_summary.dart';
import 'package:newfitness/shared/models/logged_exercise.dart';
import 'package:newfitness/shared/models/workout.dart';
import 'package:newfitness/shared/models/workout_set.dart';

Workout _workout(DateTime date, {double kg = 0, int reps = 0}) => Workout(
  id: '$date',
  userId: 'u',
  date: date,
  exercises: [
    LoggedExercise(
      exerciseId: 'e',
      exerciseName: 'Exercício',
      sets: [WorkoutSet(weightKg: kg, reps: reps, completed: true)],
    ),
  ],
);

void main() {
  // Quarta-feira.
  final now = DateTime(2026, 11, 4, 12);

  test('sem treinos, a semana fica zerada', () {
    final week = WeekSummary.from(const [], now);
    expect(week.trainedDays, List.filled(7, false));
    expect(week.workoutsThisWeek, 0);
    expect(week.weekStreak, 0);
  });

  test('marca os dias da semana atual e soma o volume', () {
    final week = WeekSummary.from([
      _workout(DateTime(2026, 11, 4, 8), kg: 10, reps: 10),
      _workout(DateTime(2026, 11, 2, 8), kg: 20, reps: 5),
      _workout(DateTime(2026, 11, 1, 8), kg: 50, reps: 10),
    ], now);
    expect(week.trainedDays, [true, false, true, false, false, false, false]);
    expect(week.workoutsThisWeek, 2);
    expect(week.volumeThisWeek, 200);
  });

  test('domingo pertence à semana iniciada na segunda anterior', () {
    final week = WeekSummary.from([
      _workout(DateTime(2026, 11, 8, 8)),
    ], DateTime(2026, 11, 8, 20));
    expect(week.trainedDays.last, isTrue);
    expect(week.workoutsThisWeek, 1);
  });

  test('conta semanas seguidas, mesmo sem treino ainda na atual', () {
    final week = WeekSummary.from([
      _workout(DateTime(2026, 10, 28)),
      _workout(DateTime(2026, 10, 21)),
      _workout(DateTime(2026, 10, 7)),
    ], now);
    expect(week.weekStreak, 2);
  });

  test('uma semana inteira sem treino encerra a sequência', () {
    final week = WeekSummary.from([_workout(DateTime(2026, 10, 21))], now);
    expect(week.weekStreak, 0);
  });
}
