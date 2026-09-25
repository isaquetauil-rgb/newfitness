import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:newfitness/core/storage/local_prefs.dart';
import 'package:newfitness/features/workout/data/active_workout_store.dart';
import 'package:newfitness/features/workout/logic/prescription_format.dart';
import 'package:newfitness/features/workout/logic/workout_provider.dart';
import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/models/exercise_progress_record.dart';
import 'package:newfitness/shared/models/logged_exercise.dart';
import 'package:newfitness/shared/models/training_plan.dart';
import 'package:newfitness/shared/models/workout.dart';
import 'package:newfitness/shared/models/workout_set.dart';

import '../helpers/mocks.dart';

/// Prescrição do plano durante o treino (#14): o PRESCRITO é uma cópia
/// congelada do `PlanExercise`; o REALIZADO continua sendo só `sets`.
void main() {
  late MockFirestoreService firestoreService;
  late WorkoutProvider provider;

  setUpAll(registerTestFallbackValues);

  setUp(() {
    firestoreService = MockFirestoreService();
    provider = WorkoutProvider(firestoreService: firestoreService);
  });

  const supinoReto = PlanExercise(
    exerciseId: 'supino_reto',
    exerciseName: 'Supino reto',
    targetSets: 4,
    targetReps: '10',
    targetWeightsKg: '30',
    restSeconds: 90,
    notes: 'Controlar a descida',
  );
  const remada = PlanExercise(
    exerciseId: 'remada',
    exerciseName: 'Remada',
    targetSets: 3,
    targetReps: '8-12',
    targetWeightsKg: '40/50/60',
    restSeconds: 60,
    replacedExerciseId: 'remada_antiga',
    replacedExerciseName: 'Remada antiga',
  );
  final plan = TrainingPlan(
    id: 'plan1',
    studentUid: 'u1',
    instructorUid: 'i1',
    title: 'Hipertrofia',
    createdAt: DateTime(2024),
    workouts: const [
      TrainingSubWorkout(label: 'Treino A', exercises: [supinoReto, remada]),
    ],
  );
  const supinoInclinado = Exercise(
    id: 'supino_inclinado',
    name: 'Supino inclinado',
    muscleGroup: 'Peito',
    equipment: 'Barra',
    description: '',
    videoUrl: '',
  );

  Workout active() => provider.activeWorkout!;
  LoggedExercise first() => active().exercises.first;

  void stubSave() {
    when(() => firestoreService.saveWorkout(any()))
        .thenAnswer((_) async => 'w');
    when(() => firestoreService.recordExerciseProgress(any()))
        .thenAnswer((_) async {});
  }

  Workout savedWorkout() =>
      verify(() => firestoreService.saveWorkout(captureAny())).captured.single
          as Workout;

  group('plano → treino', () {
    test('1. cada exercício recebe a cópia completa do PlanExercise', () {
      provider.startFromPlan('u1', plan, 0);

      expect(first().prescription!.toMap(), supinoReto.toMap());
      expect(active().exercises[1].prescription!.toMap(), remada.toMap());
      // cópia independente, não a mesma instância do plano
      expect(identical(first().prescription, supinoReto), isFalse);
    });

    test('1b. as séries prescritas nascem VAZIAS (nada vem da meta)', () {
      provider.startFromPlan('u1', plan, 0);

      expect(first().sets, hasLength(4));
      for (final s in first().sets) {
        expect(s.reps, 0);
        expect(s.weightKg, 0);
        expect(s.completed, isFalse);
      }
    });

    test('2. o treino guarda a origem (plano e sub-treino)', () {
      provider.startFromPlan('u1', plan, 0);

      expect(active().source!.planId, 'plan1');
      expect(active().source!.planTitle, 'Hipertrofia');
      expect(active().source!.subWorkoutLabel, 'Treino A');
    });

    test('3. treino livre: sem prescrição e sem origem (nem no mapa)', () {
      provider.startWorkout('u1');
      provider.addExercise(supinoInclinado);

      expect(active().source, isNull);
      expect(first().prescription, isNull);
      expect(active().toMap().containsKey('source'), isFalse);
      expect(first().toMap().containsKey('prescription'), isFalse);
    });

    test(
      '4. exercício adicionado à mão num treino de plano: sem prescrição',
      () {
        provider.startFromPlan('u1', plan, 0);
        provider.addExercise(supinoInclinado);

        expect(active().exercises.last.prescription, isNull);
        expect(active().source, isNotNull);
      },
    );

    test('5. updateSet não mexe na prescrição', () {
      provider.startFromPlan('u1', plan, 0);
      provider.updateSet(0, 2, reps: 8, weightKg: 32, completed: true);

      expect(first().prescription!.toMap(), supinoReto.toMap());
      expect(first().sets[2].reps, 8);
      expect(first().sets[2].weightKg, 32);
    });

    test('6. addSet não mexe na prescrição', () {
      provider.startFromPlan('u1', plan, 0);
      provider.addSet(0);

      expect(first().sets, hasLength(5));
      expect(first().prescription!.toMap(), supinoReto.toMap());
    });

    test('7. substituição mantém a prescrição do exercício ORIGINAL', () {
      provider.startFromPlan('u1', plan, 0);
      provider.updateSet(0, 0, reps: 10, weightKg: 30, completed: true);
      provider.substituteExercise(0, supinoInclinado);

      expect(first().exerciseId, 'supino_inclinado');
      expect(first().exerciseName, 'Supino inclinado');
      expect(first().replacedExerciseId, 'supino_reto');
      expect(first().replacedExerciseName, 'Supino reto');
      expect(first().prescription!.exerciseId, 'supino_reto');
      expect(first().prescription!.toMap(), supinoReto.toMap());
      expect(first().prescriptionMatchesExercise, isFalse);
      // séries já feitas preservadas (comportamento atual)
      expect(first().sets.first.reps, 10);
      // progresso vai para o exercício REALIZADO
      final progress = aggregateProgressInputs(active().exercises);
      expect(progress.keys, contains('supino_inclinado'));
      expect(progress.keys, isNot(contains('supino_reto')));
    });

    test('7b. duas trocas seguidas continuam com a prescrição original', () {
      provider.startFromPlan('u1', plan, 0);
      provider.substituteExercise(0, supinoInclinado);
      provider.substituteExercise(
        0,
        const Exercise(
          id: 'crucifixo',
          name: 'Crucifixo',
          muscleGroup: 'Peito',
          equipment: 'Halteres',
          description: '',
          videoUrl: '',
        ),
      );

      expect(first().replacedExerciseId, 'supino_reto');
      expect(first().prescription!.exerciseId, 'supino_reto');
    });
  });

  group('compatibilidade', () {
    test('8. treino antigo (sem prescription/source) abre como antes', () {
      final old = Workout.fromMap('w-old', {
        'userId': 'u1',
        'date': 1700000000000,
        'name': 'Treino antigo',
        'exercises': [
          {
            'exerciseId': 'e1',
            'exerciseName': 'Agachamento',
            'sets': [
              {'reps': 10, 'weightKg': 60, 'completed': true},
            ],
            'replacedExerciseId': null,
            'replacedExerciseName': null,
          },
        ],
        'durationSeconds': 1200,
      });

      expect(old.source, isNull);
      expect(old.exercises.single.prescription, isNull);
      expect(old.totalVolume, 600);
      expect(old.totalSets, 1);
      expect(old.toMap().containsKey('source'), isFalse);
    });

    test(
      '8b. plano criado antes da mudança (campos faltando) vira prescrição',
      () {
        final oldPlanExercise = PlanExercise.fromMap({
          'exerciseId': 'e1',
          'exerciseName': 'Leg press',
          'targetSets': 3,
          'targetReps': '12',
        });
        final oldPlan = TrainingPlan(
          id: 'p-old',
          studentUid: 'u1',
          instructorUid: 'i1',
          title: 'Antigo',
          createdAt: DateTime(2023),
          workouts: [
            TrainingSubWorkout(label: 'A', exercises: [oldPlanExercise]),
          ],
        );
        provider.startFromPlan('u1', oldPlan, 0);

        expect(first().prescription!.targetWeightsKg, '');
        expect(first().prescription!.restSeconds, 60);
        expect(first().sets, hasLength(3));
      },
    );

    test('toMap/fromMap preserva prescrição e origem', () {
      provider.startFromPlan('u1', plan, 0);
      final copy = Workout.fromMap('x', active().toMap());

      expect(copy.source!.planTitle, 'Hipertrofia');
      expect(copy.exercises.first.prescription!.toMap(), supinoReto.toMap());
      expect(copy.exercises[1].prescription!.toMap(), remada.toMap());
    });

    group('rascunho local', () {
      late LocalPrefs prefs;
      late ActiveWorkoutStore store;

      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        prefs = LocalPrefs(await SharedPreferences.getInstance());
        store = ActiveWorkoutStore(prefs);
      });

      test('9. rascunho com prescrição sobrevive a fechar/reabrir', () async {
        final before = WorkoutProvider(
          firestoreService: firestoreService,
          store: store,
        )..startFromPlan('u1', plan, 0);
        before.updateSet(0, 0, reps: 10, weightKg: 30);
        await Future<void>.delayed(Duration.zero);

        final after = WorkoutProvider(
          firestoreService: firestoreService,
          store: store,
        );
        expect(await after.restoreFor('u1'), isTrue);
        final e = after.activeWorkout!.exercises.first;
        expect(e.prescription!.toMap(), supinoReto.toMap());
        expect(after.activeWorkout!.source!.planId, 'plan1');
        expect(e.sets.first.reps, 10);
        expect(e.sets[1].reps, 0);
      });

      test(
        '10. rascunho antigo (sem prescrição/origem) restaura normalmente',
        () async {
          await prefs.setActiveWorkoutJson(
            jsonEncode({
              'v': 1,
              'userId': 'u1',
              'startedAt': 1700000000000,
              'workout': {
                'userId': 'u1',
                'date': 1700000000000,
                'name': 'Treino',
                'exercises': [
                  {
                    'exerciseId': 'e1',
                    'exerciseName': 'Remada',
                    'sets': [
                      {'reps': 8, 'weightKg': 40, 'completed': false},
                    ],
                    'replacedExerciseId': null,
                    'replacedExerciseName': null,
                  },
                ],
                'durationSeconds': 0,
              },
            }),
          );
          final p = WorkoutProvider(
            firestoreService: firestoreService,
            store: store,
          );

          expect(await p.restoreFor('u1'), isTrue);
          expect(p.activeWorkout!.source, isNull);
          expect(p.activeWorkout!.exercises.single.prescription, isNull);
          expect(p.activeWorkout!.exercises.single.sets.single.reps, 8);
        },
      );
    });
  });

  group('finalizar: só o realizado vai para o histórico', () {
    test(
      '11. progresso ignora a prescrição (4×10×100 prescrito, 2×8×30 feito)',
      () async {
        stubSave();
        provider.startFromPlan(
          'u1',
          TrainingPlan(
            id: 'p',
            studentUid: 'u1',
            instructorUid: 'i1',
            title: 'Força',
            createdAt: DateTime(2024),
            workouts: const [
              TrainingSubWorkout(
                label: 'A',
                exercises: [
                  PlanExercise(
                    exerciseId: 'agacho',
                    exerciseName: 'Agachamento',
                    targetSets: 4,
                    targetReps: '10',
                    targetWeightsKg: '100',
                  ),
                ],
              ),
            ],
          ),
          0,
        );
        provider.updateSet(0, 0, reps: 8, weightKg: 30, completed: true);
        provider.updateSet(0, 1, reps: 8, weightKg: 30, completed: true);

        expect(await provider.finishWorkout(), WorkoutFinishResult.saved);

        final saved = savedWorkout();
        final progress = aggregateProgressInputs(saved.exercises)['agacho']!;
        expect(progress.topSetLoadKg, 30);
        expect(progress.totalVolume, 480);
        expect(saved.totalSets, 2);
        final recorded =
            verify(() => firestoreService.recordExerciseProgress(captureAny()))
                    .captured
                    .single
                as Workout;
        expect(recorded.exercises.single.sets, hasLength(2));
        // a prescrição continua anexada, intacta, mas não entra em nada
        expect(saved.exercises.single.prescription!.targetWeightsKg, '100');
      },
    );

    test(
      '12–16. descarta só as séries vazias; 4 prescritas e 2 feitas = 2',
      () async {
        stubSave();
        provider.startFromPlan('u1', plan, 0);
        // supino (4 séries): 2 feitas, 2 vazias
        provider.updateSet(0, 0, reps: 10, weightKg: 30, completed: true);
        provider.updateSet(0, 1, reps: 10, weightKg: 30, completed: true);
        // remada (3 séries): concluída com 0 kg (peso do corpo), reps sem
        // concluir, carga sem reps
        provider.updateSet(1, 0, completed: true);
        provider.updateSet(1, 1, reps: 12);
        provider.updateSet(1, 2, weightKg: 20);

        await provider.finishWorkout();
        final saved = savedWorkout();

        expect(saved.exercises[0].sets, hasLength(2)); // 12 e 16
        final remadaSets = saved.exercises[1].sets;
        expect(remadaSets, hasLength(3));
        expect(remadaSets[0].completed, isTrue); // 13: concluída com 0 kg
        expect(remadaSets[0].weightKg, 0);
        expect(remadaSets[1].reps, 12); // 14: reps > 0
        expect(remadaSets[2].weightKg, 20); // 15: carga > 0
        expect(saved.totalSets, 5);
        expect(saved.source!.planId, 'plan1');
      },
    );

    test(
      'exercício sem nenhuma série feita é mantido, com lista vazia',
      () async {
        stubSave();
        provider.startFromPlan('u1', plan, 0);
        provider.updateSet(0, 0, reps: 10, weightKg: 30, completed: true);

        await provider.finishWorkout();
        final saved = savedWorkout();

        expect(saved.exercises, hasLength(2));
        expect(saved.exercises[1].exerciseId, 'remada');
        expect(saved.exercises[1].sets, isEmpty);
        // e continua vazio ao ler de volta (não vira a série padrão)
        final reread = Workout.fromMap('w', saved.toMap());
        expect(reread.exercises[1].sets, isEmpty);
        expect(aggregateProgressInputs(saved.exercises).keys, ['supino_reto']);
      },
    );

    test(
      'se a gravação falhar, o treino em andamento não perde as séries vazias',
      () async {
        when(() => firestoreService.saveWorkout(any())).thenThrow(Exception());
        provider.startFromPlan('u1', plan, 0);
        // uma série feita, para chegar à gravação (sem nenhuma, o treino de
        // plano nem é gravado — ver o grupo "treino de plano sem séries")
        provider.updateSet(0, 0, reps: 10, weightKg: 30, completed: true);

        expect(await provider.finishWorkout(), WorkoutFinishResult.failed);
        expect(first().sets, hasLength(4));
      },
    );

    test('17. mais séries feitas que as prescritas', () async {
      stubSave();
      provider.startFromPlan('u1', plan, 0);
      provider.addSet(0);
      provider.addSet(0);
      for (var i = 0; i < 6; i++) {
        provider.updateSet(0, i, reps: 10, weightKg: 30, completed: true);
      }

      await provider.finishWorkout();
      final saved = savedWorkout();

      expect(saved.exercises.first.sets, hasLength(6));
      expect(saved.exercises.first.prescription!.targetSets, 4);
    });

    test('mesmo exercício duas vezes: cada um com a sua prescrição; progresso soma', () async {
      stubSave();
      provider.startFromPlan(
        'u1',
        TrainingPlan(
          id: 'p',
          studentUid: 'u1',
          instructorUid: 'i1',
          title: 'Bi-set',
          createdAt: DateTime(2024),
          workouts: const [
            TrainingSubWorkout(
              label: 'A',
              exercises: [
                PlanExercise(
                  exerciseId: 'rosca',
                  exerciseName: 'Rosca',
                  targetSets: 1,
                  targetReps: '10',
                  targetWeightsKg: '10',
                ),
                PlanExercise(
                  exerciseId: 'rosca',
                  exerciseName: 'Rosca',
                  targetSets: 1,
                  targetReps: '15',
                  targetWeightsKg: '8',
                ),
              ],
            ),
          ],
        ),
        0,
      );
      provider.updateSet(0, 0, reps: 10, weightKg: 12, completed: true);
      provider.updateSet(1, 0, reps: 15, weightKg: 8, completed: true);

      await provider.finishWorkout();
      final saved = savedWorkout();

      expect(saved.exercises[0].prescription!.targetReps, '10');
      expect(saved.exercises[1].prescription!.targetReps, '15');
      final progress = aggregateProgressInputs(saved.exercises)['rosca']!;
      expect(progress.topSetLoadKg, 12);
      expect(progress.totalVolume, 120 + 120);
    });
  });

  group('prescrição é só texto', () {
    test('18. "8-12" continua texto; exibido como faixa, sem virar número', () {
      provider.startFromPlan('u1', plan, 0);
      final p = active().exercises[1].prescription!;

      expect(p.targetReps, '8-12');
      expect(prescriptionSetsReps(p), '3 séries × 8–12 reps');
      expect(active().exercises[1].sets.every((s) => s.reps == 0), isTrue);
    });

    test(
      '19. "40/50/60" continua texto; exibido exatamente como prescrito',
      () {
        provider.startFromPlan('u1', plan, 0);
        final p = active().exercises[1].prescription!;

        expect(p.targetWeightsKg, '40/50/60');
        expect(prescriptionLoad(p), '40/50/60 kg');
        expect(
          active().exercises[1].sets.every((s) => s.weightKg == 0),
          isTrue,
        );
      },
    );

    test('20. unilateral só muda o texto; o modelo da série não muda', () {
      expect(
        prescriptionSetsReps(supinoReto, unilateral: true),
        '4 séries × 10 reps (cada lado)',
      );
      expect(WorkoutSet().toMap().keys.toSet(), {
        'reps',
        'weightKg',
        'completed',
      });
    });

    test(
      'formatos: 1 série, reps em texto livre, carga com "kg", sem carga',
      () {
        const p = PlanExercise(
          exerciseId: 'x',
          exerciseName: 'X',
          targetSets: 1,
          targetReps: 'até a falha',
          targetWeightsKg: '32,5kg',
          restSeconds: 45,
        );
        expect(prescriptionSetsReps(p), '1 série × até a falha');
        expect(prescriptionLoad(p), '32,5kg');
        expect(prescriptionRest(p), 'Descanso: 45 s');
        expect(
          prescriptionLoad(
            const PlanExercise(
              exerciseId: 'y',
              exerciseName: 'Y',
              targetSets: 3,
              targetReps: '10',
            ),
          ),
          isNull,
        );
      },
    );
  });
}
