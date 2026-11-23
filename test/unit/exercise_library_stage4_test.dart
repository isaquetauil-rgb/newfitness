import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/exercises/logic/exercise_filter.dart';
import 'package:newfitness/features/exercises/logic/exercise_provider.dart';
import 'package:newfitness/features/exercises/logic/exercise_search.dart';
import 'package:newfitness/features/exercises/logic/exercise_similarity.dart';
import 'package:newfitness/features/exercises/logic/exercise_taxonomy_provider.dart';
import 'package:newfitness/features/instructor/logic/custom_exercise_provider.dart';
import 'package:newfitness/features/workout/presentation/exercise_picker_screen.dart';
import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/models/sample_exercises.dart';
import 'package:newfitness/shared/models/training_plan.dart';
import 'package:newfitness/shared/models/user_profile.dart';

import '../helpers/mocks.dart';

/// Pares exercício do personal → versão geral (o que o script da Etapa 4
/// grava em `baseExerciseId`).
const pares = {
  'pt_agachamento_pendulo': 'pendulum_squat',
  'pt_cadeira_adutora': 'hip_adduction',
  'pt_corrida_caminhada': 'treadmill_run_walk',
  'pt_crucifixo_inverso_maquina': 'machine_rear_delt_fly',
  'pt_elevacao_lateral_polia': 'cable_lateral_raise',
  'pt_encolhimento': 'dumbbell_shrug',
  'pt_panturrilha_smith': 'smith_calf_raise',
  'pt_puxada_triangulo': 'close_grip_lat_pulldown',
  'pt_rosca_45': 'incline_dumbbell_curl',
  'pt_rosca_direta_polia': 'cable_curl',
  'pt_triceps_frances_unilateral': 'single_arm_overhead_triceps_extension',
};

void main() {
  final byId = {for (final e in sampleExercises) e.id: e};
  final fixture = jsonDecode(
    File('test/fixtures/library/plano_mattheus.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final customRaw = Map<String, dynamic>.from(
    fixture['customExercises'] as Map,
  );
  List<Exercise> customs({bool linked = true}) => [
    for (final e in customRaw.entries)
      Exercise.fromMap(e.key, {
        ...Map<String, dynamic>.from(e.value as Map),
        // A cópia do Firestore real já tem o vínculo; sem ele = como era antes.
        'baseExerciseId': linked ? pares[e.key] : '',
      }),
  ];

  group('substituição', () {
    test('supino reto: halteres e máquina antes de crucifixo (com e sem a '
        'curadoria da ficha)', () {
      final bench = byId['bench_press']!;
      for (final target in [
        bench,
        Exercise.fromMap(bench.id, {
          ...bench.toMap(),
          'alternativeExerciseIds': <String>[],
        }),
      ]) {
        final ids = findExerciseAlternatives(
          target,
          sampleExercises,
          limit: 30,
        ).map((a) => a.exercise.id).toList();
        final fly = ids.indexOf('dumbbell_fly');
        expect(fly, greaterThan(0));
        expect(ids.indexOf('dumbbell_bench_press'), inInclusiveRange(0, fly));
        expect(ids.indexOf('machine_chest_press'), inInclusiveRange(0, fly));
      }
    });

    test('alternativas da ficha vêm primeiro, na ordem da ficha', () {
      final bench = byId['bench_press']!;
      final alts = findExerciseAlternatives(bench, sampleExercises, limit: 10);
      final curated = bench.alternativeExerciseIds;
      expect(
        alts.take(curated.length).map((a) => a.exercise.id).toList(),
        curated,
      );
      expect(alts.first.curated, isTrue);
      expect(alts.first.reason, 'escolhido na ficha · halteres');
      expect(alts[curated.length].curated, isFalse);
    });

    test('motivo curto: critério mais forte e equipamento', () {
      final bench = Exercise.fromMap('bench_press', {
        ...byId['bench_press']!.toMap(),
        'alternativeExerciseIds': <String>[],
      });
      final alts = findExerciseAlternatives(bench, sampleExercises, limit: 30);
      String reasonOf(String id) =>
          alts.firstWhere((a) => a.exercise.id == id).reason;
      expect(
        reasonOf('dumbbell_bench_press'),
        'mesmo padrão: empurrar horizontal · halteres',
      );
      expect(
        reasonOf('decline_bench_press'),
        'mesmo padrão: empurrar horizontal · mesmo equipamento',
      );
      expect(reasonOf('dumbbell_fly'), 'mesmo músculo: peito · halteres');
    });

    test('nomes antigos contam como o mesmo músculo ("Ombro" = "Ombros")', () {
      final antigo = Exercise(
        id: 'x',
        name: 'Elevação antiga',
        muscleGroup: 'Ombro',
        equipment: 'Halteres',
        description: '',
        videoUrl: '',
        movementPattern: 'Abdução de ombro',
      );
      final ids = findExerciseAlternatives(
        antigo,
        sampleExercises,
      ).map((a) => a.exercise.id);
      expect(ids.first, 'lateral_raise');
    });
  });

  group('filtros combinados', () {
    List<Exercise> run(ExerciseFilter f) =>
        sampleExercises.where(f.matches).toList();

    test('peito + halteres + iniciante', () {
      final r = run(
        const ExerciseFilter(
          muscleGroups: {'Peito'},
          equipment: {'Halteres'},
          difficultyLevels: {'iniciante'},
        ),
      );
      expect(r, isNotEmpty);
      for (final e in r) {
        expect(e.muscleGroup, 'Peito');
        expect(e.equipment, 'Halteres');
        expect(e.difficultyLevel, 'iniciante');
      }
      expect(r.map((e) => e.id), contains('dumbbell_fly'));
      expect(r.map((e) => e.id), isNot(contains('bench_press')));
    });

    test('músculo vale como principal ou secundário', () {
      final ids = run(const ExerciseFilter(muscles: {'Tríceps braquial'}))
          .map((e) => e.id);
      expect(ids, containsAll(['triceps_pushdown', 'bench_press', 'dips']));
      expect(ids, isNot(contains('squat')));
    });

    test('unilateral, categoria e busca juntos', () {
      final r = run(
        const ExerciseFilter(
          unilateral: true,
          categories: {'forca'},
          query: 'polia',
        ),
      );
      expect(r, isNotEmpty);
      for (final e in r) {
        expect(e.isUnilateral, isTrue);
        expect(e.category, 'forca');
      }
      expect(
        r.map((e) => e.id),
        containsAll(['single_arm_cable_row', 'cable_lateral_raise']),
      );
      final bilaterais = run(const ExerciseFilter(unilateral: false));
      expect(bilaterais.every((e) => !e.isUnilateral), isTrue);
    });

    test('contagem e limpar tudo', () {
      const f = ExerciseFilter(
        muscleGroups: {'Peito'},
        muscles: {'Tríceps braquial'},
        unilateral: false,
        query: 'supino',
      );
      expect(f.activeCount, 3);
      expect(f.isEmpty, isFalse);
      expect(const ExerciseFilter(query: '  ').isEmpty, isTrue);
      expect(f.copyWith(unilateral: () => null).unilateral, isNull);
      expect(f.copyWith(query: 'x').muscleGroups, {'Peito'});
    });
  });

  group('busca sem acento', () {
    List<String> search(String q) => [
      for (final e in sampleExercises)
        if (matchesExerciseQuery(e, q)) e.id,
    ];

    test('"triceps" acha "Tríceps"', () {
      final r = search('triceps');
      expect(
        r,
        containsAll([
          'triceps_pushdown',
          'triceps_bar_pushdown',
          'tricep_extension',
        ]),
      );
      expect(search('TRÍCEPS'), r);
    });

    test('acha pelo nome alternativo e pelas tags', () {
      expect(search('puxada neutra'), contains('close_grip_lat_pulldown'));
      expect(search('abdominal infra'), contains('leg_raise'));
      expect(search('rollout'), contains('ab_wheel_rollout'));
      expect(search('triceps corda'), contains('triceps_pushdown'));
      expect(search('triceps corda'), isNot(contains('triceps_bar_pushdown')));
      expect(search(''), hasLength(sampleExercises.length));
    });
  });

  group('duplicados personal × geral', () {
    test('os 11 pares apontam para exercícios gerais que existem', () {
      expect(pares.length, 11);
      // A cópia do Firestore real tem exatamente estes vínculos.
      for (final e in customRaw.entries) {
        expect((e.value as Map)['baseExerciseId'], pares[e.key], reason: e.key);
      }
      expect(pares.keys.toSet(), customRaw.keys.toSet());
      for (final base in pares.values) {
        expect(byId.containsKey(base), isTrue, reason: base);
      }
    });

    test('baseExerciseId é opcional e só gravado quando preenchido', () {
      final c = customs().first;
      expect(c.toMap()['baseExerciseId'], pares[c.id]);
      expect(
        Exercise.fromMap('y', {'name': 'y'}).toMap(),
        isNot(contains('baseExerciseId')),
      );
    });

    test('esconde só as versões gerais que o personal tem', () {
      final visible = hideGeneralDuplicates(sampleExercises, customs());
      expect(visible.length, sampleExercises.length - 11);
      for (final base in pares.values) {
        expect(visible.map((e) => e.id), isNot(contains(base)));
      }
      // Sem o vínculo, nada some.
      expect(
        hideGeneralDuplicates(sampleExercises, customs(linked: false)),
        sampleExercises,
      );
    });

    testWidgets('no seletor: escondido para o personal dono, visível para o '
        'aluno', (tester) async {
      Future<int> count(UserProfile profile) async {
        final firestore = MockFirestoreService();
        final authService = MockAuthService();
        final user = MockUser();
        when(() => user.uid).thenReturn(profile.uid);
        when(() => user.email).thenReturn(profile.email);
        when(() => user.emailVerified).thenReturn(true);
        when(() => authService.authStateChanges)
            .thenAnswer((_) => Stream<User?>.value(user));
        when(() => firestore.getUserProfile(profile.uid))
            .thenAnswer((_) async => profile);
        when(() => firestore.watchExercises())
            .thenAnswer((_) => Stream.value(sampleExercises));
        when(() => firestore.watchMuscleGroups())
            .thenAnswer((_) => Stream.value(const []));
        when(() => firestore.watchEquipment())
            .thenAnswer((_) => Stream.value(const []));
        when(() => firestore.watchCustomExercises('p1'))
            .thenAnswer((_) => Stream.value(customs()));
        final auth = AuthProvider(
          authService: authService,
          firestoreService: firestore,
        );
        await tester.pump();
        await tester.pump();
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: auth),
              ChangeNotifierProvider(
                create: (_) => ExerciseProvider(firestoreService: firestore),
              ),
              ChangeNotifierProvider(
                create: (_) =>
                    ExerciseTaxonomyProvider(firestoreService: firestore),
              ),
              ChangeNotifierProvider(
                create: (_) => CustomExerciseProvider(
                  firestoreService: firestore,
                  storageService: MockStorageService(),
                ),
              ),
            ],
            child: const MaterialApp(home: ExercisePickerScreen()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'rosca direta na polia');
        await tester.pumpAndSettle();
        final n = find.text('Rosca direta na polia').evaluate().length;
        expect(find.text('Limpar tudo'), findsOneWidget);
        expect(find.text(n == 1 ? '1 exercício' : '$n exercícios'), findsOne);
        await tester.tap(find.text('Limpar tudo'));
        await tester.pumpAndSettle();
        expect(find.text('Limpar tudo'), findsNothing);
        await tester.pumpWidget(const SizedBox());
        return n;
      }

      // Personal dono: só a versão dele.
      expect(
        await count(
          const UserProfile(
            uid: 'p1',
            name: 'P',
            email: 'p@x',
            role: UserRole.instructor,
          ),
        ),
        1,
      );
      // Aluno vinculado: as duas.
      expect(
        await count(
          const UserProfile(
            uid: 'a1',
            name: 'A',
            email: 'a@x',
            instructorId: 'p1',
          ),
        ),
        2,
      );
    });
  });

  test('plano do Mattheus intacto: todo exercício continua achável, com e '
      'sem esconder duplicados', () {
    final plan = TrainingPlan.fromMap(
      'plano',
      Map<String, dynamic>.from(fixture['plan'] as Map),
    );
    final all = [...customs(), ...sampleExercises];
    final ownerView = [
      ...customs(),
      ...hideGeneralDuplicates(sampleExercises, customs()),
    ];
    for (final pool in [all, ownerView]) {
      final ids = {for (final e in pool) e.id};
      for (final w in plan.workouts) {
        for (final e in w.exercises) {
          expect(ids, contains(e.exerciseId));
        }
      }
    }
    expect(plan.workouts.map((w) => w.exercises.length).toList(), [
      9,
      6,
      8,
      5,
      8,
    ]);
  });
}
