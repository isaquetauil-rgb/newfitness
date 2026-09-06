import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

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

  test(
    'promoteToInstructor gera código de convite quando o usuário não tem um',
    () async {
      const user = UserProfile(uid: 'u1', name: 'Ana', email: 'ana@x.com');
      when(() => firestoreService.generateUniqueInviteCode())
          .thenAnswer((_) async => 'ABC123');
      when(() => firestoreService.updateUserProfile(any()))
          .thenAnswer((_) async {});

      await provider.promoteToInstructor(user);

      final saved =
          verify(() => firestoreService.updateUserProfile(captureAny()))
                  .captured
                  .single
              as UserProfile;
      expect(saved.role, UserRole.instructor);
      expect(saved.inviteCode, 'ABC123');
    },
  );

  test(
    'promoteToInstructor reaproveita o código de convite já existente',
    () async {
      const user = UserProfile(
        uid: 'u1',
        name: 'Ana',
        email: 'ana@x.com',
        inviteCode: 'JÁEXISTE',
      );
      when(() => firestoreService.updateUserProfile(any()))
          .thenAnswer((_) async {});

      await provider.promoteToInstructor(user);

      verifyNever(() => firestoreService.generateUniqueInviteCode());
      final saved =
          verify(() => firestoreService.updateUserProfile(captureAny()))
                  .captured
                  .single
              as UserProfile;
      expect(saved.inviteCode, 'JÁEXISTE');
    },
  );

  test('demoteToStudent muda o papel para aluno', () async {
    const user = UserProfile(
      uid: 'u1',
      name: 'Ana',
      email: 'ana@x.com',
      role: UserRole.instructor,
    );
    when(() => firestoreService.updateUserProfile(any()))
        .thenAnswer((_) async {});

    await provider.demoteToStudent(user);

    final saved =
        verify(() => firestoreService.updateUserProfile(captureAny()))
                .captured
                .single
            as UserProfile;
    expect(saved.role, UserRole.student);
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

  test('loadStats agrega as contagens do FirestoreService', () async {
    when(() => firestoreService.countUsers()).thenAnswer((_) async => 10);
    when(() => firestoreService.countUsersByRole('student'))
        .thenAnswer((_) async => 8);
    when(() => firestoreService.countUsersByRole('instructor'))
        .thenAnswer((_) async => 2);
    when(() => firestoreService.countExercises()).thenAnswer((_) async => 20);
    when(() => firestoreService.countWorkoutsLogged())
        .thenAnswer((_) async => 137);

    final stats = await provider.loadStats();

    expect(stats.totalUsers, 10);
    expect(stats.totalStudents, 8);
    expect(stats.totalInstructors, 2);
    expect(stats.totalExercises, 20);
    expect(stats.totalWorkoutsLogged, 137);
  });
}
