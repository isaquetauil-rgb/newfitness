import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/instructor/presentation/instructor_dashboard_screen.dart';
import 'package:newfitness/shared/models/appointment.dart';
import 'package:newfitness/shared/models/training_plan.dart';
import 'package:newfitness/shared/models/user_profile.dart';
import 'package:newfitness/shared/models/workout.dart';

import '../helpers/mocks.dart';

/// Painel do personal: resumo, agenda de hoje, convite e situação de cada
/// aluno, com busca e filtros.
void main() {
  // Quarta-feira, 25/11/2026, 10h.
  final now = DateTime(2026, 11, 25, 10);
  late MockFirestoreService db;
  late MockAuthService authService;

  TrainingPlan plan(String uid) => TrainingPlan(
    id: 'p-$uid',
    studentUid: uid,
    instructorUid: 'p1',
    title: 'Plano',
    createdAt: DateTime(2026),
  );

  setUp(() {
    db = MockFirestoreService();
    authService = MockAuthService();
    when(() => db.watchStudents('p1')).thenAnswer(
      (_) => Stream.value([
        {'uid': 'ana', 'name': 'Ana Souza', 'email': 'ana@x.com'},
        {'uid': 'bia', 'name': 'Bia Lima', 'email': 'bia@x.com'},
        {'uid': 'caio', 'name': 'Caio Reis', 'email': 'caio@x.com'},
      ]),
    );
    // Ana: treinou ontem e segunda, tem plano.
    when(() => db.watchWorkouts('ana')).thenAnswer(
      (_) => Stream.value([
        Workout(id: 'w1', userId: 'ana', date: DateTime(2026, 11, 24, 18)),
        Workout(id: 'w2', userId: 'ana', date: DateTime(2026, 11, 23, 18)),
      ]),
    );
    when(() => db.watchTrainingPlans('ana'))
        .thenAnswer((_) => Stream.value([plan('ana')]));
    // Bia: parada há 20 dias, tem plano.
    when(() => db.watchWorkouts('bia')).thenAnswer(
      (_) => Stream.value([
        Workout(id: 'w3', userId: 'bia', date: DateTime(2026, 11, 5)),
      ]),
    );
    when(() => db.watchTrainingPlans('bia'))
        .thenAnswer((_) => Stream.value([plan('bia')]));
    // Caio: sem plano e sem treino.
    when(() => db.watchWorkouts('caio'))
        .thenAnswer((_) => Stream.value(const []));
    when(() => db.watchTrainingPlans('caio'))
        .thenAnswer((_) => Stream.value(const []));
    when(() => db.watchAppointmentsForInstructor('p1')).thenAnswer(
      (_) => Stream.value([
        Appointment(
          id: 'a1',
          instructorUid: 'p1',
          studentUid: 'ana',
          studentName: 'Ana Souza',
          title: 'Treino',
          start: DateTime(2026, 11, 25, 18, 30),
        ),
      ]),
    );
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 7000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    const profile = UserProfile(
      uid: 'p1',
      name: 'Isaque Personal',
      email: 'p@x.com',
      role: UserRole.instructor,
      inviteCode: 'ABC123',
    );
    final user = MockUser();
    when(() => user.uid).thenReturn('p1');
    when(() => user.email).thenReturn('p@x.com');
    when(() => user.emailVerified).thenReturn(true);
    when(() => authService.authStateChanges)
        .thenAnswer((_) => Stream<User?>.value(user));
    when(() => db.getUserProfile('p1')).thenAnswer((_) async => profile);
    final auth = AuthProvider(authService: authService, firestoreService: db);
    await tester.pump();
    await tester.pump();
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
          home: InstructorDashboardScreen(
            firestoreService: db,
            clock: () => now,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String statValue(WidgetTester tester, String key) => tester
      .widgetList<Text>(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(Text),
        ),
      )
      .first
      .data!;

  testWidgets('resumo, agenda, convite e situação de cada aluno', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Olá, Isaque'), findsOneWidget);
    expect(statValue(tester, 'stat-students'), '3');
    expect(statValue(tester, 'stat-week'), '1');
    expect(statValue(tester, 'stat-attention'), '2');
    expect(find.text('1 compromisso: 18:30 · Ana Souza'), findsOneWidget);
    expect(find.text('ABC123'), findsOneWidget);
    expect(find.byKey(const ValueKey('share-invite')), findsOneWidget);

    expect(find.text('Treinou ontem · 2 treinos na semana'), findsOneWidget);
    expect(find.text('Treinou há 2 semanas'), findsOneWidget);
    expect(find.text('Ainda não treinou · sem plano'), findsOneWidget);

    // Quem precisa de atenção vem primeiro (Caio sem plano, depois Bia).
    final caio = tester.getTopLeft(find.text('Caio Reis')).dy;
    final bia = tester.getTopLeft(find.text('Bia Lima')).dy;
    final ana = tester.getTopLeft(find.text('Ana Souza')).dy;
    expect(caio < bia && bia < ana, isTrue);
  });

  testWidgets('filtros e busca', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Precisam de atenção'));
    await tester.pumpAndSettle();
    expect(find.text('Ana Souza'), findsNothing);
    expect(find.text('Bia Lima'), findsOneWidget);
    expect(find.text('Caio Reis'), findsOneWidget);
    expect(find.text('2 de 3'), findsOneWidget);

    await tester.tap(find.text('Sem plano'));
    await tester.pumpAndSettle();
    expect(find.text('Bia Lima'), findsNothing);
    expect(find.text('Caio Reis'), findsOneWidget);

    await tester.tap(find.text('Todos'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('student-search')), 'bia');
    await tester.pumpAndSettle();
    expect(find.text('Bia Lima'), findsOneWidget);
    expect(find.text('Ana Souza'), findsNothing);
    expect(find.text('1 de 3'), findsOneWidget);
  });

  testWidgets('sem alunos: explica como convidar', (tester) async {
    when(() => db.watchStudents('p1'))
        .thenAnswer((_) => Stream.value(const []));
    await pump(tester);
    expect(find.textContaining('Nenhum aluno vinculado ainda'), findsOneWidget);
    expect(statValue(tester, 'stat-students'), '0');
  });
}
