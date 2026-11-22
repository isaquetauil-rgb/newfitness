import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/features/integrations/logic/health_sync.dart';
import 'package:newfitness/features/stats/logic/period_stats.dart';
import 'package:newfitness/features/workout/logic/workout_provider.dart';
import 'package:newfitness/features/workout/logic/workout_timing.dart';
import 'package:newfitness/features/workout/presentation/stale_workout_prompt.dart';
import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/models/logged_exercise.dart';
import 'package:newfitness/shared/models/workout.dart';
import 'package:newfitness/shared/models/workout_set.dart';

import '../helpers/mocks.dart';

const _supino = Exercise(
  id: 'supino',
  name: 'Supino',
  muscleGroup: 'Peito',
  equipment: '',
  description: '',
  videoUrl: '',
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    registerFallbackValue(Workout(id: '', userId: '', date: DateTime(2026)));
  });

  // Relógio controlado: começa 12/11 às 18:00.
  late DateTime clock;
  late MockFirestoreService fs;
  late WorkoutProvider provider;
  final start = DateTime(2026, 11, 12, 18);

  setUp(() {
    clock = start;
    fs = MockFirestoreService();
    when(() => fs.saveWorkout(any())).thenAnswer((_) async => 'w');
    when(() => fs.recordExerciseProgress(any())).thenAnswer((_) async {});
    provider = WorkoutProvider(firestoreService: fs, clock: () => clock);
    resetStaleWorkoutPrompt();
  });

  /// Treino com uma série marcada às 18:20 (descanso padrão de 60 s).
  void startWithOneSetAt(Duration after) {
    provider.startWorkout('u');
    provider.addExercise(_supino);
    provider.updateSet(0, 0, reps: 8, weightKg: 60);
    clock = start.add(after);
    provider.updateSet(0, 0, completed: true);
  }

  group('1. hora da série concluída', () {
    test('marcar grava completedAt; desmarcar apaga', () {
      startWithOneSetAt(const Duration(minutes: 20));
      final set = provider.activeWorkout!.exercises[0].sets[0];
      expect(set.completedAt, DateTime(2026, 11, 12, 18, 20));
      provider.updateSet(0, 0, completed: false);
      expect(set.completedAt, isNull);
    });

    test('vai e volta do Firestore; série antiga continua abrindo', () {
      final s = WorkoutSet(reps: 8, completed: true, completedAt: start);
      expect(WorkoutSet.fromMap(s.toMap()).completedAt, start);
      final old = WorkoutSet(reps: 8).toMap();
      expect(old.containsKey('completedAt'), isFalse);
      expect(WorkoutSet.fromMap(old).completedAt, isNull);
    });
  });

  group('2. fim real = última série + descanso', () {
    test(
      'finalizar dias depois grava só até a última série + descanso',
      () async {
        startWithOneSetAt(const Duration(minutes: 20));
        clock = DateTime(
          2026,
          11,
          22,
          11,
          47,
        ); // tocou em Finalizar 10 dias depois
        expect(await provider.finishWorkout(), WorkoutFinishResult.saved);
        // 20 min + 60 s de descanso.
        expect(provider.lastSaved!.durationSeconds, 20 * 60 + 60);
        expect(provider.lastSaved!.date, start);
      },
    );

    test('o descanso não passa da hora em que finalizou', () {
      final w = Workout(
        id: '',
        userId: 'u',
        date: start,
        exercises: [
          LoggedExercise(
            exerciseId: 'x',
            exerciseName: 'x',
            sets: [
              WorkoutSet(
                reps: 5,
                completed: true,
                completedAt: start.add(const Duration(minutes: 30)),
              ),
            ],
          ),
        ],
      );
      final now = start.add(const Duration(minutes: 30, seconds: 20));
      expect(realWorkoutEnd(w, start, now, restFor: (_, _) => 90), now);
    });

    test('a última série é a de hora mais tarde, em qualquer exercício', () {
      final w = Workout(
        id: '',
        userId: 'u',
        date: start,
        exercises: [
          LoggedExercise(
            exerciseId: 'a',
            exerciseName: 'a',
            sets: [
              WorkoutSet(
                reps: 5,
                completed: true,
                completedAt: start.add(const Duration(minutes: 50)),
              ),
            ],
          ),
          LoggedExercise(
            exerciseId: 'b',
            exerciseName: 'b',
            sets: [
              WorkoutSet(
                reps: 5,
                completed: true,
                completedAt: start.add(const Duration(minutes: 10)),
              ),
            ],
          ),
        ],
      );
      final end = realWorkoutEnd(
        w,
        start,
        start.add(const Duration(days: 2)),
        restFor: (i, _) => i == 0 ? 120 : 0,
      );
      expect(end, start.add(const Duration(minutes: 52)));
    });

    test('Health Connect recebe o fim real', () {
      final w = Workout(
        id: 'w',
        userId: 'u',
        date: start,
        durationSeconds: 21 * 60,
        exercises: [
          LoggedExercise(
            exerciseId: 'x',
            exerciseName: 'x',
            sets: [WorkoutSet(reps: 5, completed: true, completedAt: start)],
          ),
        ],
      );
      final window = workoutWindow(w);
      expect(window.end, start.add(const Duration(minutes: 21)));
    });
  });

  group('3 e 4. treino esquecido aberto', () {
    test('mais de 3 h sem série marcada: esquecido', () {
      startWithOneSetAt(const Duration(minutes: 20));
      clock = start.add(const Duration(hours: 3, minutes: 20));
      expect(provider.hasStaleWorkout, isFalse); // exatamente 3 h
      clock = start.add(const Duration(hours: 3, minutes: 21));
      expect(provider.hasStaleWorkout, isTrue);
      expect(provider.activeHasCompletedSet, isTrue);
    });

    test('sem nenhuma série: conta desde o início', () {
      provider.startWorkout('u');
      provider.addExercise(_supino);
      clock = start.add(const Duration(hours: 4));
      expect(provider.hasStaleWorkout, isTrue);
      expect(provider.activeHasCompletedSet, isFalse);
    });

    test('rótulo do dia', () {
      final now = DateTime(2026, 11, 22, 11);
      expect(staleDayLabel(DateTime(2026, 11, 22, 7), now), 'hoje');
      expect(staleDayLabel(DateTime(2026, 11, 21, 18), now), 'ontem');
      expect(
        staleDayLabel(DateTime(2026, 11, 12, 18), now),
        'quinta-feira, 12/11',
      );
    });

    Future<void> pumpHome(WidgetTester tester) => tester.pumpWidget(
      ChangeNotifierProvider<WorkoutProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              scheduleStaleWorkoutCheck(context);
              return const Scaffold(body: Text('Início'));
            },
          ),
        ),
      ),
    );

    testWidgets('com série feita: Finalizar, Continuar e Descartar', (
      tester,
    ) async {
      startWithOneSetAt(const Duration(minutes: 20));
      clock = start.add(const Duration(days: 10));
      await pumpHome(tester);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Você esqueceu de finalizar o treino de'),
        findsOneWidget,
      );
      expect(find.text('Finalizar'), findsOneWidget);
      expect(find.text('Continuar treinando'), findsOneWidget);
      expect(find.text('Descartar'), findsOneWidget);

      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();
      expect(provider.hasActiveWorkout, isFalse);
      expect(find.text('Treino descartado.'), findsOneWidget);
    });

    testWidgets('sem série feita: só Continuar e Descartar', (tester) async {
      provider.startWorkout('u');
      provider.addExercise(_supino);
      clock = start.add(const Duration(hours: 5));
      await pumpHome(tester);
      await tester.pumpAndSettle();
      expect(find.text('Finalizar'), findsNothing);
      expect(find.text('Continuar treinando'), findsOneWidget);
      expect(find.text('Descartar'), findsOneWidget);
    });

    testWidgets('treino recente: não pergunta', (tester) async {
      startWithOneSetAt(const Duration(minutes: 20));
      clock = start.add(const Duration(hours: 1));
      await pumpHome(tester);
      await tester.pumpAndSettle();
      expect(find.textContaining('esqueceu'), findsNothing);
      provider.skipRest(); // encerra o cronômetro de descanso do teste
    });
  });

  group('5. treinos antigos sem hora das séries: até 3 h', () {
    Workout old(int seconds, {bool withTimes = false}) => Workout(
      id: 'o',
      userId: 'u',
      date: start,
      durationSeconds: seconds,
      exercises: [
        LoggedExercise(
          exerciseId: 'x',
          exerciseName: 'x',
          sets: [
            WorkoutSet(
              reps: 5,
              completed: true,
              completedAt: withTimes ? start : null,
            ),
          ],
        ),
      ],
    );

    test('duração limitada a 3 h só nos antigos', () {
      expect(effectiveDurationSeconds(old(10 * 24 * 3600)), 3 * 3600);
      expect(effectiveDurationSeconds(old(3600)), 3600);
      expect(
        effectiveDurationSeconds(old(4 * 3600, withTimes: true)),
        4 * 3600,
      );
    });

    test('Meu mês e Health Connect usam a duração limitada', () {
      final w = old(10 * 24 * 3600);
      final stats = PeriodStats.from([
        w,
      ], Period.containing(PeriodKind.month, start));
      expect(stats.totalSeconds, 3 * 3600);
      expect(workoutWindow(w).end, start.add(const Duration(hours: 3)));
    });

    test(
      'rascunho antigo sem hora das séries finaliza com no máximo 3 h',
      () async {
        provider.startWorkout('u');
        provider.addExercise(_supino);
        provider.updateSet(0, 0, reps: 8, weightKg: 60);
        // Série marcada como feita, mas sem hora (como num rascunho antigo).
        provider.activeWorkout!.exercises[0].sets[0].completed = true;
        clock = start.add(const Duration(days: 10));
        await provider.finishWorkout();
        expect(provider.lastSaved!.durationSeconds, 3 * 3600);
      },
    );
  });
}
