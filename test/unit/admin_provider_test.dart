import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:newfitness/core/error/app_exception.dart';

import 'package:newfitness/features/admin/logic/admin_provider.dart';
import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/models/user_profile.dart';

import '../helpers/mocks.dart';

void main() {
  late MockFirestoreService firestoreService;
  late AdminProvider provider;

  setUpAll(registerTestFallbackValues);

  setUp(() {
    firestoreService = MockFirestoreService();
    provider = AdminProvider(firestoreService: firestoreService);
  });

  test('watchAllUsers delega ao FirestoreService', () async {
    final controller = StreamController<List<UserProfile>>();
    const user = UserProfile(uid: 'u1', name: 'Ana', email: 'ana@x.com');
    when(() => firestoreService.watchAllUsers())
        .thenAnswer((_) => controller.stream);

    final future = provider.watchAllUsers().first;
    controller.add([user]);
    final result = await future;

    expect(result, [user]);
    await controller.close();
  });

  group('troca de papel pela Cloud Function setUserRole', () {
    late MockFunctionsClient functionsClient;

    setUp(() {
      functionsClient = MockFunctionsClient();
      provider = AdminProvider(
        firestoreService: firestoreService,
        functionsClient: functionsClient,
      );
    });

    test('promoteToInstructor chama a Function com uid e papel', () async {
      const user = UserProfile(uid: 'u1', name: 'Ana', email: 'ana@x.com');
      when(() => functionsClient.call('setUserRole', any()))
          .thenAnswer((_) async => {'ok': true, 'revokedStudents': 0});

      await provider.promoteToInstructor(user);

      verify(
        () => functionsClient.call('setUserRole', {
          'uid': 'u1',
          'role': 'instructor',
        }),
      ).called(1);
    });

    test('demoteToStudent chama a Function e nunca grava direto', () async {
      const user = UserProfile(
        uid: 'u1',
        name: 'Ana',
        email: 'ana@x.com',
        role: UserRole.instructor,
      );
      when(() => functionsClient.call('setUserRole', any()))
          .thenAnswer((_) async => {'ok': true, 'revokedStudents': 3});

      final revoked = await provider.setRole(user, UserRole.student);

      expect(revoked, 3);
      verify(
        () => functionsClient.call('setUserRole', {
          'uid': 'u1',
          'role': 'student',
        }),
      ).called(1);
      verifyNever(() => firestoreService.updateUserProfile(any()));
    });

    test('erro da Function é propagado (papel não mudou)', () async {
      when(() => functionsClient.call('setUserRole', any())).thenThrow(
        const UnknownException('O papel NÃO foi alterado — tente de novo.'),
      );

      await expectLater(
        provider.setRole(
          const UserProfile(uid: 'u1', name: 'Ana', email: 'a@x.com'),
          UserRole.student,
        ),
        throwsA(isA<UnknownException>()),
      );
    });
  });

  test('saveExercise e deleteExercise delegam ao FirestoreService', () async {
    const exercise = Exercise(
      id: 'e1',
      name: 'Supino',
      muscleGroup: 'Peito',
      equipment: 'Barra',
      description: '',
      videoUrl: '',
    );
    when(() => firestoreService.seedExercise(exercise))
        .thenAnswer((_) async {});
    when(() => firestoreService.deleteExercise('e1')).thenAnswer((_) async {});

    await provider.saveExercise(exercise);
    await provider.deleteExercise('e1');

    verify(() => firestoreService.seedExercise(exercise)).called(1);
    verify(() => firestoreService.deleteExercise('e1')).called(1);
  });

  test(
    'loadStats lê as estatísticas da Cloud Function getAdminStats',
    () async {
      final functionsClient = MockFunctionsClient();
      provider = AdminProvider(
        firestoreService: firestoreService,
        functionsClient: functionsClient,
      );
      when(() => functionsClient.call('getAdminStats', any())).thenAnswer(
        (_) async => {
          'totalUsers': 10,
          'totalStudents': 8,
          'totalInstructors': 2,
          'totalNutritionists': 1,
          'totalExercises': 20,
          'totalWorkoutsLogged': 137,
          'activeSubscriptions': 5,
        },
      );

      final stats = await provider.loadStats();

      expect(stats.totalUsers, 10);
      expect(stats.totalStudents, 8);
      expect(stats.totalInstructors, 2);
      expect(stats.totalNutritionists, 1);
      expect(stats.totalExercises, 20);
      expect(stats.totalWorkoutsLogged, 137);
      expect(stats.activeSubscriptions, 5);
    },
  );

  test(
    'loadStats propaga o erro (painel mostra erro, não fica carregando)',
    () async {
      final functionsClient = MockFunctionsClient();
      provider = AdminProvider(
        firestoreService: firestoreService,
        functionsClient: functionsClient,
      );
      when(() => functionsClient.call('getAdminStats', any()))
          .thenThrow(Exception('permission-denied'));

      await expectLater(provider.loadStats(), throwsException);
    },
  );

  test('loadStats não espera para sempre (timeout)', () async {
    final functionsClient = MockFunctionsClient();
    provider = AdminProvider(
      firestoreService: firestoreService,
      functionsClient: functionsClient,
    );
    when(() => functionsClient.call('getAdminStats', any()))
        .thenAnswer((_) => Completer<Map<String, dynamic>>().future);

    await expectLater(
      provider.loadStats(timeout: const Duration(milliseconds: 20)),
      throwsA(isA<TimeoutException>()),
    );
  });
}
