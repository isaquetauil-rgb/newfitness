import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/health/presentation/free_workout_gate.dart';
import 'package:newfitness/shared/models/parq.dart';
import 'package:newfitness/shared/models/user_profile.dart';

import '../helpers/mocks.dart';

void main() {
  group('PAR-Q', () {
    test('7 perguntas; algum "sim" recomenda liberação médica', () {
      expect(parqQuestions, hasLength(7));
      final ok = ParQ(answers: List.filled(7, false), answeredAt: 1);
      expect(ok.needsMedicalClearance, isFalse);
      final sim = ParQ(
        answers: [false, false, true, false, false, false, false],
        answeredAt: 1,
      );
      expect(sim.needsMedicalClearance, isTrue);
      expect(sim.flaggedQuestions, [parqQuestions[2]]);
    });

    test('vai e volta pelo perfil, com data; perfil antigo sem o campo', () {
      final p = UserProfile.fromMap('u', {
        'name': 'Ana',
        'email': 'a@x',
        'parq': {
          'answers': [true, false, false, false, false, false, false],
          'answeredAt': 1700000000000,
          'version': 1,
        },
        'freeWorkoutTermsAcceptedAt': 1700000000001,
      });
      expect(p.parq!.answeredDate.millisecondsSinceEpoch, 1700000000000);
      expect(p.freeWorkoutTermsAcceptedAt, 1700000000001);
      expect(p.toMap()['parq'], isA<Map<String, dynamic>>());
      final antigo = UserProfile.fromMap('u', {'name': 'B', 'email': 'b@x'});
      expect(antigo.parq, isNull);
      expect(antigo.toMap().containsKey('parq'), isFalse);
      expect(antigo.toMap().containsKey('freeWorkoutDisabled'), isFalse);
    });
  });

  group('freeWorkoutBlocked', () {
    test('só vale com personal vinculado', () {
      const bloqueado = UserProfile(
        uid: 'u',
        name: 'A',
        email: 'a',
        instructorId: 'p',
        freeWorkoutDisabled: true,
      );
      expect(bloqueado.freeWorkoutBlocked, isTrue);
      // Vínculo desfeito: o bloqueio deixa de valer.
      const semPersonal = UserProfile(
        uid: 'u',
        name: 'A',
        email: 'a',
        freeWorkoutDisabled: true,
      );
      expect(semPersonal.freeWorkoutBlocked, isFalse);
    });
  });

  group('ensureFreeWorkoutAllowed', () {
    late MockFirestoreService firestore;
    late MockAuthService authService;

    Future<(AuthProvider, bool?)> run(
      WidgetTester tester,
      UserProfile profile, {
      bool accept = true,
    }) async {
      firestore = MockFirestoreService();
      authService = MockAuthService();
      final user = MockUser();
      when(() => user.uid).thenReturn(profile.uid);
      when(() => user.email).thenReturn(profile.email);
      when(() => user.emailVerified).thenReturn(true);
      when(() => authService.authStateChanges)
          .thenAnswer((_) => Stream<User?>.value(user));
      when(() => firestore.getUserProfile(profile.uid))
          .thenAnswer((_) async => profile);
      when(() => firestore.acceptFreeWorkoutTerms(profile.uid, any()))
          .thenAnswer((_) async {});
      final auth = AuthProvider(
        authService: authService,
        firestoreService: firestore,
      );
      await tester.pump();
      await tester.pump();

      bool? result;
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async =>
                      result = await ensureFreeWorkoutAllowed(context),
                  child: const Text('livre'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('livre'));
      await tester.pumpAndSettle();
      return (auth, result);
    }

    testWidgets('primeira vez: mostra o aviso e grava o aceite com data', (
      tester,
    ) async {
      final (auth, _) = await run(
        tester,
        const UserProfile(uid: 'u1', name: 'A', email: 'a@x'),
      );
      expect(find.text('Antes do treino livre'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('accept-free-workout-terms')));
      await tester.pumpAndSettle();
      verify(() => firestore.acceptFreeWorkoutTerms('u1', any())).called(1);
      expect(auth.profile!.freeWorkoutTermsAcceptedAt, isNotNull);
    });

    testWidgets('já aceito: libera sem perguntar', (tester) async {
      final (_, result) = await run(
        tester,
        const UserProfile(
          uid: 'u1',
          name: 'A',
          email: 'a@x',
          freeWorkoutTermsAcceptedAt: 1,
        ),
      );
      expect(find.text('Antes do treino livre'), findsNothing);
      expect(result, isTrue);
    });

    testWidgets('personal desativou: avisa e não libera', (tester) async {
      await run(
        tester,
        const UserProfile(
          uid: 'u1',
          name: 'A',
          email: 'a@x',
          instructorId: 'p1',
          freeWorkoutDisabled: true,
          freeWorkoutTermsAcceptedAt: 1,
        ),
      );
      expect(find.text('Treino livre desativado'), findsOneWidget);
    });
  });
}
