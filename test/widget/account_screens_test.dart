import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/features/account/presentation/active_contracts_screen.dart';
import 'package:newfitness/features/account/presentation/documents_screen.dart';
import 'package:newfitness/features/account/presentation/my_cards_screen.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/shared/models/parq.dart';
import 'package:newfitness/shared/models/professional_request.dart';
import 'package:newfitness/shared/models/subscription.dart';
import 'package:newfitness/shared/models/training_plan.dart';
import 'package:newfitness/shared/models/user_profile.dart';

import '../helpers/mocks.dart';

/// Telas que antes diziam "em breve": Meus cartões, Contratos ativos e
/// Documentos, agora com os dados que o app já tem.
void main() {
  late MockFirestoreService db;
  late MockAuthService authService;

  setUp(() {
    db = MockFirestoreService();
    authService = MockAuthService();
  });

  Future<void> pump(
    WidgetTester tester,
    UserProfile profile,
    Widget Function(MockFirestoreService db) screen,
  ) async {
    tester.view.physicalSize = const Size(1080, 5000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final user = MockUser();
    when(() => user.uid).thenReturn(profile.uid);
    when(() => user.email).thenReturn(profile.email);
    when(() => user.emailVerified).thenReturn(true);
    when(() => authService.authStateChanges)
        .thenAnswer((_) => Stream<User?>.value(user));
    when(() => db.getUserProfile(profile.uid)).thenAnswer((_) async => profile);
    final auth = AuthProvider(authService: authService, firestoreService: db);
    await tester.pump();
    await tester.pump();
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(home: screen(db)),
      ),
    );
    await tester.pumpAndSettle();
  }

  const aluno = UserProfile(uid: 'a1', name: 'Ana', email: 'a@x.com');

  group('Meus cartões', () {
    testWidgets('aluno: mensalidade, pagamentos e cartão só no Mercado Pago', (
      tester,
    ) async {
      when(() => db.watchSubscription('a1')).thenAnswer(
        (_) => Stream.value(
          Subscription(
            status: SubscriptionStatus.authorized,
            amountCents: 12000,
            nextPaymentDate: DateTime(2026, 12, 10),
          ),
        ),
      );
      when(() => db.watchPayments('a1')).thenAnswer(
        (_) => Stream.value([
          SubscriptionPayment(
            id: 'p1',
            amountCents: 12000,
            date: DateTime(2026, 11, 10),
            status: 'approved',
          ),
        ]),
      );
      await pump(tester, aluno, (db) => MyCardsScreen(firestoreService: db));

      expect(find.textContaining('Mercado Pago'), findsOneWidget);
      expect(find.text('Em dia'), findsOneWidget);
      expect(
        find.text('R\$ 120,00 · próxima cobrança em 10/12/2026'),
        findsOneWidget,
      );
      expect(find.text('10/11/2026 · aprovado'), findsOneWidget);
      expect(find.text('Pagar ou trocar o cartão'), findsOneWidget);
      expect(find.textContaining('Em breve'), findsNothing);
    });

    testWidgets('aluno sem assinatura', (tester) async {
      when(() => db.watchSubscription('a1'))
          .thenAnswer((_) => Stream.value(const Subscription()));
      when(() => db.watchPayments('a1'))
          .thenAnswer((_) => Stream.value(const []));
      await pump(tester, aluno, (db) => MyCardsScreen(firestoreService: db));
      expect(find.text('Sem assinatura'), findsOneWidget);
      expect(find.text('Cadastrar cartão e assinar'), findsOneWidget);
      expect(find.text('Nenhum pagamento registrado ainda.'), findsOneWidget);
    });
  });

  group('Contratos ativos', () {
    testWidgets('aluno sem vínculos', (tester) async {
      when(() => db.watchSubscription('a1'))
          .thenAnswer((_) => Stream.value(const Subscription()));
      await pump(
        tester,
        aluno,
        (db) => ActiveContractsScreen(firestoreService: db),
      );
      expect(find.byKey(const ValueKey('no-instructor')), findsOneWidget);
      expect(find.byKey(const ValueKey('no-nutritionist')), findsOneWidget);
      expect(find.text('Nenhuma mensalidade ativa.'), findsOneWidget);
    });

    testWidgets('aluno com personal e plano', (tester) async {
      when(() => db.watchTrainingPlans('a1')).thenAnswer(
        (_) => Stream.value([
          TrainingPlan(
            id: 'p',
            studentUid: 'a1',
            instructorUid: 'i1',
            title: 'Treino Hipertrofia',
            createdAt: DateTime(2026, 11, 2),
            workouts: const [
              TrainingSubWorkout(label: 'A'),
              TrainingSubWorkout(label: 'B'),
            ],
          ),
        ]),
      );
      when(() => db.watchSubscription('a1'))
          .thenAnswer((_) => Stream.value(const Subscription()));
      await pump(
        tester,
        aluno.copyWith(instructorId: 'i1'),
        (db) => ActiveContractsScreen(firestoreService: db),
      );
      expect(find.byKey(const ValueKey('instructor-linked')), findsOneWidget);
      expect(find.text('Treino Hipertrofia'), findsOneWidget);
      expect(find.text('2 treino(s) · desde 02/11/2026'), findsOneWidget);
    });

    testWidgets('personal: alunos vinculados', (tester) async {
      when(() => db.watchStudents('i1')).thenAnswer(
        (_) => Stream.value([
          {'uid': 'a1', 'name': 'Ana'},
          {'uid': 'a2', 'name': 'Bia'},
        ]),
      );
      await pump(
        tester,
        const UserProfile(
          uid: 'i1',
          name: 'P',
          email: 'p@x.com',
          role: UserRole.instructor,
        ),
        (db) => ActiveContractsScreen(firestoreService: db),
      );
      expect(find.text('2 alunos vinculados'), findsOneWidget);
    });
  });

  group('Documentos', () {
    testWidgets('aluno: PAR-Q, termo do treino livre e pedido em análise', (
      tester,
    ) async {
      when(() => db.watchProfessionalRequest('a1')).thenAnswer(
        (_) => Stream.value(
          ProfessionalRequest(
            uid: 'a1',
            kind: UserRole.instructor,
            registrationNumber: '123456-G',
            registrationRegion: 'SP',
            name: 'Ana',
            email: 'a@x.com',
            status: ProfessionalRequestStatus.pending,
            createdAt: DateTime(2026, 11, 20),
          ),
        ),
      );
      await pump(
        tester,
        aluno.copyWith(
          parq: ParQ(
            answers: List.filled(7, false),
            answeredAt: DateTime(2026, 11, 1).millisecondsSinceEpoch,
          ),
          freeWorkoutTermsAcceptedAt: DateTime(
            2026,
            11,
            3,
          ).millisecondsSinceEpoch,
        ),
        (db) => DocumentsScreen(firestoreService: db),
      );
      expect(find.text('Respondido em 01/11/2026'), findsOneWidget);
      expect(find.text('Aceito em 03/11/2026'), findsOneWidget);
      expect(find.text('Pedido em análise'), findsOneWidget);
      expect(find.text('Enviado em 20/11/2026.'), findsOneWidget);
      expect(find.byKey(const ValueKey('doc-privacy')), findsOneWidget);
      expect(find.byKey(const ValueKey('doc-export')), findsOneWidget);
    });

    testWidgets('aluno sem PAR-Q', (tester) async {
      when(() => db.watchProfessionalRequest('a1'))
          .thenAnswer((_) => Stream.value(null));
      await pump(tester, aluno, (db) => DocumentsScreen(firestoreService: db));
      expect(
        find.text('Ainda não respondido. Toque para responder.'),
        findsOneWidget,
      );
      expect(find.text('É personal ou nutricionista?'), findsOneWidget);
    });
  });
}
