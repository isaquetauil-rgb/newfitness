import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:newfitness/core/storage/local_prefs.dart';
import 'package:newfitness/features/workout/data/active_workout_store.dart';
import 'package:newfitness/features/workout/logic/workout_provider.dart';
import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/services/firestore_service.dart';

import '../helpers/mocks.dart';

const _exercise = Exercise(
  id: 'e1',
  name: 'Supino',
  muscleGroup: 'Peito',
  equipment: 'Barra',
  description: '',
  videoUrl: '',
);

void main() {
  late LocalPrefs prefs;
  late ActiveWorkoutStore store;
  late MockFirestoreService firestoreService;

  setUpAll(registerTestFallbackValues);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = LocalPrefs(await SharedPreferences.getInstance());
    store = ActiveWorkoutStore(prefs);
    firestoreService = MockFirestoreService();
  });

  WorkoutProvider newProvider() =>
      WorkoutProvider(firestoreService: firestoreService, store: store);

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  group('treino em andamento sobrevive a fechar/reabrir o app', () {
    test('séries digitadas são restauradas para o mesmo usuário', () async {
      final before = newProvider()
        ..startWorkout('u1', name: 'Treino A')
        ..addExercise(_exercise);
      before.updateSet(0, 0, reps: 10, weightKg: 22.5, completed: true);
      await flush();

      // "Reabre o app": provider novo, mesmo armazenamento local.
      final after = newProvider();
      final restored = await after.restoreFor('u1');

      expect(restored, isTrue);
      expect(after.activeWorkout!.name, 'Treino A');
      final set = after.activeWorkout!.exercises.single.sets.single;
      expect(set.reps, 10);
      expect(set.weightKg, 22.5);
      expect(set.completed, isTrue);
    });

    test(
      'NUNCA restaura o treino de outro usuário (e descarta o rascunho)',
      () async {
        newProvider()
          ..startWorkout('u1')
          ..addExercise(_exercise);
        await flush();

        final other = newProvider();
        expect(await other.restoreFor('u2'), isFalse);
        expect(other.hasActiveWorkout, isFalse);
        // O rascunho do u1 foi apagado — não fica esperando no aparelho.
        expect(prefs.activeWorkoutJson, isNull);
      },
    );

    test('cancelar limpa o rascunho local', () async {
      final p = newProvider()..startWorkout('u1');
      await flush();
      expect(prefs.activeWorkoutJson, isNotNull);

      p.cancelWorkout();
      await flush();

      expect(prefs.activeWorkoutJson, isNull);
      expect(await newProvider().restoreFor('u1'), isFalse);
    });

    test('finalizar com sucesso limpa o rascunho local', () async {
      when(() => firestoreService.saveWorkout(any()))
          .thenAnswer((_) async => 'w1');
      when(() => firestoreService.recordExerciseProgress(any()))
          .thenAnswer((_) async {});
      final p = newProvider()
        ..startWorkout('u1')
        ..addExercise(_exercise)
        ..updateSet(0, 0, reps: 10, weightKg: 20, completed: true);
      await flush();

      expect(await p.finishWorkout(), WorkoutFinishResult.saved);
      await flush();

      expect(prefs.activeWorkoutJson, isNull);
    });

    test(
      'se salvar no Firestore falhar, o rascunho continua guardado',
      () async {
        when(() => firestoreService.saveWorkout(any()))
            .thenThrow(Exception('offline'));
        final p = newProvider()
          ..startWorkout('u1')
          ..addExercise(_exercise)
          ..updateSet(0, 0, reps: 10, weightKg: 20, completed: true);
        await flush();

        expect(await p.finishWorkout(), WorkoutFinishResult.failed);
        await flush();

        expect(prefs.activeWorkoutJson, isNotNull);
      },
    );

    test('não sobrescreve um treino que já está ativo', () async {
      newProvider().startWorkout('u1', name: 'Antigo');
      await flush();

      final p = newProvider()..startWorkout('u1', name: 'Novo');
      expect(await p.restoreFor('u1'), isFalse);
      expect(p.activeWorkout!.name, 'Novo');
    });

    test('rascunho corrompido é descartado sem quebrar', () async {
      await prefs.setActiveWorkoutJson('{isto não é json');
      expect(await store.load('u1'), isNull);
      expect(prefs.activeWorkoutJson, isNull);
    });
  });

  group('combineLinkedStudents (lista de alunos do profissional)', () {
    test(
      'só aparece quem está vinculado AGORA; dados extras vêm da entrada',
      () async {
        final linked = StreamController<List<Map<String, dynamic>>>();
        final entries = StreamController<Map<String, Map<String, dynamic>>>();
        final results = <List<Map<String, dynamic>>>[];
        final sub = combineLinkedStudents(
          linked.stream,
          entries.stream,
        ).listen(results.add);

        entries.add({
          // Aluno que trocou de instrutor: entrada antiga continua (com as
          // notas do instrutor), mas ele não está mais em `linked`.
          'old': {'name': 'Antigo', 'notes': 'nota antiga', 'active': false},
          'a': {
            'name': 'Nome velho',
            'notes': 'joelho',
            'monthlyFeeCents': 9900,
          },
        });
        linked.add([
          {'uid': 'b', 'name': 'bia', 'email': 'b@x'},
          {'uid': 'a', 'name': 'Ana', 'email': 'a@x'},
        ]);
        await flush();

        final list = results.last;
        expect(list.map((s) => s['uid']), ['a', 'b']); // ordenado por nome
        expect(list.first['name'], 'Ana'); // nome atual do perfil
        expect(list.first['notes'], 'joelho');
        expect(list.first['monthlyFeeCents'], 9900);
        expect(list.any((s) => s['uid'] == 'old'), isFalse);

        await sub.cancel();
        await linked.close();
        await entries.close();
      },
    );

    test(
      'erro de uma das fontes chega à tela (não vira lista vazia)',
      () async {
        final linked = StreamController<List<Map<String, dynamic>>>();
        final entries = StreamController<Map<String, Map<String, dynamic>>>();
        final errors = <Object>[];
        final sub = combineLinkedStudents(
          linked.stream,
          entries.stream,
        ).listen((_) {}, onError: errors.add);

        linked.addError(StateError('permission-denied'));
        await flush();

        expect(errors, hasLength(1));
        await sub.cancel();
        await linked.close();
        await entries.close();
      },
    );
  });
}
