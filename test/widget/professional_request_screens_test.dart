import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/features/admin/presentation/admin_professional_requests_screen.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/auth/presentation/register_screen.dart';
import 'package:newfitness/features/professional/logic/professional_request_provider.dart';
import 'package:newfitness/features/professional/presentation/professional_request_screen.dart';
import 'package:newfitness/shared/models/professional_request.dart';
import 'package:newfitness/shared/models/user_profile.dart';

import '../helpers/mocks.dart';

/// Telas do fluxo de aprovação: cadastro só de aluno, "Sou profissional"
/// (formulário, pendente, recusado com motivo) e a lista do admin.
void main() {
  late MockFirestoreService firestoreService;
  late MockFunctionsClient functionsClient;
  late MockAuthService authService;
  late StreamController<User?> authState;
  late StreamController<ProfessionalRequest?> mine;

  setUpAll(registerTestFallbackValues);

  setUp(() {
    firestoreService = MockFirestoreService();
    functionsClient = MockFunctionsClient();
    authService = MockAuthService();
    authState = StreamController<User?>.broadcast();
    mine = StreamController<ProfessionalRequest?>.broadcast();
    when(() => authService.authStateChanges)
        .thenAnswer((_) => authState.stream);
    when(() => firestoreService.watchProfessionalRequest(any()))
        .thenAnswer((_) => mine.stream);
    when(() => functionsClient.call(any(), any())).thenAnswer((_) async => {});
  });

  tearDown(() async {
    await authState.close();
    await mine.close();
  });

  Future<AuthProvider> loggedIn(
    WidgetTester tester, {
    UserRole role = UserRole.student,
    bool emailVerified = true,
  }) async {
    final user = MockUser();
    when(() => user.uid).thenReturn('u1');
    when(() => user.email).thenReturn('ana@x.com');
    when(() => user.emailVerified).thenReturn(emailVerified);
    when(() => firestoreService.getUserProfile('u1')).thenAnswer(
      (_) async =>
          UserProfile(uid: 'u1', name: 'Ana', email: 'ana@x.com', role: role),
    );
    final auth = AuthProvider(
      authService: authService,
      firestoreService: firestoreService,
    );
    authState.add(user);
    await tester.pump();
    return auth;
  }

  Future<void> pumpRequestScreen(WidgetTester tester, AuthProvider auth) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider(
            create: (_) => ProfessionalRequestProvider(
              firestoreService: firestoreService,
              functionsClient: functionsClient,
            ),
          ),
        ],
        child: const MaterialApp(home: ProfessionalRequestScreen()),
      ),
    );
    await tester.pump();
  }

  ProfessionalRequest request(
    ProfessionalRequestStatus status, {
    String? reason,
  }) => ProfessionalRequest(
    uid: 'u1',
    kind: UserRole.instructor,
    registrationNumber: '123456-G',
    registrationRegion: 'SP',
    name: 'Ana',
    email: 'ana@x.com',
    status: status,
    createdAt: DateTime(2026, 9, 1),
    rejectionReason: reason,
  );

  group('Cadastro', () {
    testWidgets('não oferece escolha de papel e cria perfil de aluno', (
      tester,
    ) async {
      final user = MockUser();
      when(() => user.uid).thenReturn('n1');
      when(
        () => authService.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          name: any(named: 'name'),
        ),
      ).thenAnswer((_) async => user);
      when(() => firestoreService.createUserProfile(any()))
          .thenAnswer((_) async {});
      final auth = AuthProvider(
        authService: authService,
        firestoreService: firestoreService,
        functionsClient: functionsClient,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RegisterScreen(),
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      expect(find.byType(SegmentedButton<UserRole>), findsNothing);
      expect(find.text('Instrutor'), findsNothing);
      expect(
        find.byKey(const ValueKey('professional-signup-note')),
        findsOneWidget,
      );

      await tester.enterText(find.widgetWithText(TextFormField, 'Nome'), 'Ana');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-mail'),
        'ana@x.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Senha'),
        '123456',
      );
      final submit = find.widgetWithText(ElevatedButton, 'Criar conta');
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();

      final created =
          verify(() => firestoreService.createUserProfile(captureAny()))
                  .captured
                  .single
              as UserProfile;
      expect(created.role, UserRole.student);
    });
  });

  group('Sou profissional', () {
    testWidgets('sem pedido: formulário valida registro e região', (
      tester,
    ) async {
      final auth = await loggedIn(tester);
      await pumpRequestScreen(tester, auth);
      mine.add(null);
      await tester.pump();

      expect(find.text('Enviar pedido'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '12');
      await tester.tap(find.text('Enviar pedido'));
      await tester.pump();
      expect(
        find.text('O registro deve ter de 4 a 30 caracteres.'),
        findsOneWidget,
      );
      expect(find.text('Escolha a UF do CREF.'), findsOneWidget);
      verifyNever(
        () => firestoreService.createProfessionalRequest(
          uid: any(named: 'uid'),
          kind: any(named: 'kind'),
          registrationNumber: any(named: 'registrationNumber'),
          registrationRegion: any(named: 'registrationRegion'),
          name: any(named: 'name'),
          email: any(named: 'email'),
        ),
      );
    });

    testWidgets('pendente: mostra análise e permite cancelar', (tester) async {
      when(() => firestoreService.deleteProfessionalRequest('u1'))
          .thenAnswer((_) async {});
      final auth = await loggedIn(tester);
      await pumpRequestScreen(tester, auth);
      mine.add(request(ProfessionalRequestStatus.pending));
      await tester.pump();

      expect(find.text('Pedido em análise'), findsOneWidget);
      expect(find.textContaining('CREF 123456-G/SP'), findsOneWidget);
      await tester.tap(find.text('Cancelar pedido'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar pedido').last);
      await tester.pumpAndSettle();
      verify(() => firestoreService.deleteProfessionalRequest('u1')).called(1);
    });

    testWidgets('recusado: mostra o motivo e permite pedir de novo', (
      tester,
    ) async {
      when(() => firestoreService.deleteProfessionalRequest('u1'))
          .thenAnswer((_) async {});
      final auth = await loggedIn(tester);
      await pumpRequestScreen(tester, auth);
      mine.add(
        request(ProfessionalRequestStatus.rejected, reason: 'CREF inativo'),
      );
      await tester.pump();

      expect(find.text('Pedido recusado'), findsOneWidget);
      expect(find.text('Motivo: CREF inativo'), findsOneWidget);
      await tester.tap(find.text('Fazer novo pedido'));
      await tester.pump();
      verify(() => firestoreService.deleteProfessionalRequest('u1')).called(1);
    });

    testWidgets(
      'sem pedido e e-mail não verificado: avisa, envia a verificação e '
      'não libera o formulário',
      (tester) async {
        when(() => authService.sendEmailVerification())
            .thenAnswer((_) async {});
        final auth = await loggedIn(tester, emailVerified: false);
        when(() => authService.reloadCurrentUser())
            .thenAnswer((_) async => auth.user);
        await pumpRequestScreen(tester, auth);
        mine.add(null);
        await tester.pump();

        expect(
          find.byKey(const ValueKey('verify-email-warning')),
          findsOneWidget,
        );
        expect(find.text('Enviar pedido'), findsNothing);

        await tester.tap(find.text('Enviar e-mail de verificação'));
        await tester.pump();
        verify(() => authService.sendEmailVerification()).called(1);
        expect(
          find.text('E-mail de verificação enviado para ana@x.com.'),
          findsOneWidget,
        );

        // "Já verifiquei" sem ter verificado: continua bloqueado.
        await tester.tap(find.text('Já verifiquei'));
        await tester.pump();
        verify(() => authService.reloadCurrentUser()).called(1);
        expect(find.text('Enviar pedido'), findsNothing);
        expect(
          find.text(
            'Seu e-mail ainda não foi verificado. Abra o link que enviamos.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('"Já verifiquei" com e-mail verificado libera o formulário', (
      tester,
    ) async {
      final auth = await loggedIn(tester, emailVerified: false);
      final verified = MockUser();
      when(() => verified.uid).thenReturn('u1');
      when(() => verified.email).thenReturn('ana@x.com');
      when(() => verified.emailVerified).thenReturn(true);
      when(() => authService.reloadCurrentUser())
          .thenAnswer((_) async => verified);
      await pumpRequestScreen(tester, auth);
      mine.add(null);
      await tester.pump();
      expect(find.text('Enviar pedido'), findsNothing);

      await tester.tap(find.text('Já verifiquei'));
      await tester.pump();

      expect(auth.isEmailVerified, isTrue);
      expect(find.byKey(const ValueKey('verify-email-warning')), findsNothing);
      expect(find.text('Enviar pedido'), findsOneWidget);
    });

    testWidgets('já profissional: não mostra formulário', (tester) async {
      final auth = await loggedIn(tester, role: UserRole.instructor);
      await pumpRequestScreen(tester, auth);
      mine.add(null);
      await tester.pump();

      expect(find.text('Enviar pedido'), findsNothing);
      expect(find.textContaining('Você já é personal'), findsOneWidget);
    });
  });

  group('Admin: pedidos pendentes', () {
    Future<void> pumpAdmin(WidgetTester tester) async {
      when(() => firestoreService.watchPendingProfessionalRequests())
          .thenAnswer(
            (_) => Stream.value([request(ProfessionalRequestStatus.pending)]),
          );
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => ProfessionalRequestProvider(
            firestoreService: firestoreService,
            functionsClient: functionsClient,
          ),
          child: const MaterialApp(home: AdminProfessionalRequestsScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('lista o pedido e aprova com confirmação', (tester) async {
      await pumpAdmin(tester);
      expect(find.textContaining('CREF 123456-G/SP'), findsOneWidget);

      await tester.tap(find.text('Aprovar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aprovar').last);
      await tester.pumpAndSettle();

      verify(
        () => functionsClient.call('reviewProfessionalRequest', {
          'uid': 'u1',
          'decision': 'approve',
        }),
      ).called(1);
      expect(find.text('Ana aprovado(a).'), findsOneWidget);
    });

    testWidgets('recusar exige motivo; com motivo, chama a Function', (
      tester,
    ) async {
      await pumpAdmin(tester);
      await tester.tap(find.text('Recusar'));
      await tester.pumpAndSettle();

      // sem motivo: erro e nada é chamado
      await tester.tap(find.text('Recusar').last);
      await tester.pumpAndSettle();
      expect(find.text('Informe o motivo da recusa.'), findsOneWidget);
      verifyNever(() => functionsClient.call(any(), any()));

      await tester.enterText(find.byType(TextField), 'CREF não encontrado');
      await tester.tap(find.text('Recusar').last);
      await tester.pumpAndSettle();
      verify(
        () => functionsClient.call('reviewProfessionalRequest', {
          'uid': 'u1',
          'decision': 'reject',
          'reason': 'CREF não encontrado',
        }),
      ).called(1);
    });
  });
}
