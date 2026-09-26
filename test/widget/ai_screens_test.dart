import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:newfitness/app/theme/theme_provider.dart';
import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/core/error/app_exception.dart';
import 'package:newfitness/core/storage/local_prefs.dart';
import 'package:newfitness/features/admin/logic/admin_provider.dart';
import 'package:newfitness/features/admin/presentation/admin_users_screen.dart';
import 'package:newfitness/features/ai/logic/chat_provider.dart';
import 'package:newfitness/features/ai/presentation/ai_disclaimer.dart';
import 'package:newfitness/features/ai/presentation/chat_screen.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/finance/logic/finance_provider.dart';
import 'package:newfitness/features/nutrition/logic/nutrition_chat_provider.dart';
import 'package:newfitness/features/nutrition/presentation/nutrition_chat_view.dart';
import 'package:newfitness/features/profile/presentation/profile_screen.dart';
import 'package:newfitness/features/workout/logic/workout_provider.dart';
import 'package:newfitness/shared/models/chat_message.dart';
import 'package:newfitness/shared/models/nutrition_message.dart';
import 'package:newfitness/shared/models/user_profile.dart';
import 'package:newfitness/shared/services/firestore_service.dart';

import '../helpers/mocks.dart';

/// Rodada 4 — telas de IA: aviso legal fixo, aviso de e-mail não
/// verificado (também no Perfil), mensagem real da cota e plano de IA
/// definido pelo admin.
void main() {
  late MockFirestoreService firestoreService;
  late MockAuthService authService;
  late MockAiService aiService;
  late StreamController<User?> authState;

  setUpAll(() {
    registerTestFallbackValues();
    registerFallbackValue(
      ChatMessage(
        id: '',
        role: ChatRole.user,
        content: '',
        createdAt: DateTime(2024),
      ),
    );
    registerFallbackValue(
      NutritionMessage(
        id: '',
        role: NutritionRole.user,
        content: '',
        createdAt: DateTime(2024),
      ),
    );
  });

  setUp(() {
    firestoreService = MockFirestoreService();
    authService = MockAuthService();
    aiService = MockAiService();
    authState = StreamController<User?>.broadcast();
    when(() => authService.authStateChanges)
        .thenAnswer((_) => authState.stream);
    when(() => firestoreService.watchChatMessages(any()))
        .thenAnswer((_) => Stream.value(const []));
    when(() => firestoreService.watchNutritionChat(any()))
        .thenAnswer((_) => Stream.value(const []));
  });

  tearDown(() => authState.close());

  Future<AuthProvider> loggedIn(
    WidgetTester tester, {
    required bool emailVerified,
  }) async {
    final user = MockUser();
    when(() => user.uid).thenReturn('u1');
    when(() => user.email).thenReturn('ana@x.com');
    when(() => user.emailVerified).thenReturn(emailVerified);
    when(() => firestoreService.getUserProfile('u1')).thenAnswer(
      (_) async =>
          const UserProfile(uid: 'u1', name: 'Ana', email: 'ana@x.com'),
    );
    final auth = AuthProvider(
      authService: authService,
      firestoreService: firestoreService,
    );
    authState.add(user);
    await tester.pump();
    return auth;
  }

  group('Chat geral', () {
    Future<void> pumpChat(WidgetTester tester, AuthProvider auth) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider(
              create: (_) => ChatProvider(
                aiService: aiService,
                firestoreService: firestoreService,
              ),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: ChatScreen())),
        ),
      );
      await tester.pump();
    }

    testWidgets('mostra o aviso legal fixo e o campo de pergunta', (
      tester,
    ) async {
      final auth = await loggedIn(tester, emailVerified: true);
      await pumpChat(tester, auth);

      expect(find.text(AiDisclaimer.text), findsOneWidget);
      expect(
        find.text('Orientação geral por IA. Não substitui um profissional.'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byKey(const ValueKey('verify-email-warning')), findsNothing);
    });

    testWidgets('e-mail não verificado: avisa e não deixa perguntar', (
      tester,
    ) async {
      final auth = await loggedIn(tester, emailVerified: false);
      await pumpChat(tester, auth);

      expect(
        find.byKey(const ValueKey('verify-email-warning')),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
      expect(find.text(AiDisclaimer.text), findsOneWidget);
    });

    testWidgets('cota esgotada: mostra a mensagem real do servidor', (
      tester,
    ) async {
      const message =
          'Você atingiu o limite de 5 mensagens no chat com IA de hoje do '
          'plano Básico. O limite renova à meia-noite.';
      when(() => firestoreService.addChatMessage(any(), any()))
          .thenAnswer((_) async {});
      when(() => aiService.chat(message: any(named: 'message')))
          .thenThrow(const ValidationException(message));
      final auth = await loggedIn(tester, emailVerified: true);
      await pumpChat(tester, auth);

      await tester.enterText(find.byType(TextField), 'Oi');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      await tester.pump();

      expect(find.text(message), findsOneWidget);
      verify(() => aiService.chat(message: 'Oi')).called(1);
    });
  });

  group('Nutrição', () {
    Future<void> pumpNutrition(
      WidgetTester tester,
      AuthProvider auth, {
      required bool nutritionistView,
    }) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider(
              create: (_) => NutritionChatProvider(
                aiService: aiService,
                firestoreService: firestoreService,
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: NutritionChatView(
                studentUid: 'u1',
                isNutritionistView: nutritionistView,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('aluno: aviso legal; sem e-mail verificado não pergunta', (
      tester,
    ) async {
      final auth = await loggedIn(tester, emailVerified: false);
      await pumpNutrition(tester, auth, nutritionistView: false);

      expect(find.text(AiDisclaimer.text), findsOneWidget);
      expect(
        find.byKey(const ValueKey('verify-email-warning')),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('aluno: cota esgotada mostra a mensagem do servidor', (
      tester,
    ) async {
      const message =
          'Você atingiu o limite de 10 perguntas ao assistente de nutrição '
          'deste mês do plano Básico. O limite renova no dia 1º.';
      when(() => firestoreService.addNutritionMessage(any(), any()))
          .thenAnswer((_) async {});
      when(() => aiService.askNutrition(message: any(named: 'message')))
          .thenThrow(const ValidationException(message));
      final auth = await loggedIn(tester, emailVerified: true);
      await pumpNutrition(tester, auth, nutritionistView: false);

      await tester.enterText(find.byType(TextField), 'Posso comer ovo?');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      await tester.pump();

      expect(find.text(message), findsOneWidget);
    });

    testWidgets('nutricionista: sem aviso da IA e pode corrigir', (
      tester,
    ) async {
      final auth = await loggedIn(tester, emailVerified: false);
      await pumpNutrition(tester, auth, nutritionistView: true);

      expect(find.text(AiDisclaimer.text), findsNothing);
      expect(find.byKey(const ValueKey('verify-email-warning')), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('Perfil: verificação de e-mail', () {
    late ThemeProvider theme;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      theme = ThemeProvider(
        localPrefs: LocalPrefs(await SharedPreferences.getInstance()),
      );
      getIt.registerSingleton<FirestoreService>(firestoreService);
      when(() => firestoreService.watchWorkouts(any()))
          .thenAnswer((_) => Stream.value(const []));
    });

    tearDown(() => getIt.unregister<FirestoreService>());

    Future<void> pumpProfile(WidgetTester tester, AuthProvider auth) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<ThemeProvider>.value(value: theme),
            ChangeNotifierProvider(
              create: (_) =>
                  WorkoutProvider(firestoreService: firestoreService),
            ),
          ],
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pump();
    }

    testWidgets('e-mail não verificado: aviso e envio da verificação', (
      tester,
    ) async {
      when(() => authService.sendEmailVerification()).thenAnswer((_) async {});
      final auth = await loggedIn(tester, emailVerified: false);
      await pumpProfile(tester, auth);

      expect(
        find.byKey(const ValueKey('verify-email-warning')),
        findsOneWidget,
      );
      final send = find.text('Enviar e-mail de verificação');
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pump();
      verify(() => authService.sendEmailVerification()).called(1);
      expect(
        find.text('E-mail de verificação enviado para ana@x.com.'),
        findsOneWidget,
      );
    });

    testWidgets('e-mail verificado: sem aviso', (tester) async {
      final auth = await loggedIn(tester, emailVerified: true);
      await pumpProfile(tester, auth);

      expect(find.byKey(const ValueKey('verify-email-warning')), findsNothing);
    });
  });

  testWidgets('admin define o plano de IA de um aluno pelo painel', (
    tester,
  ) async {
    final functionsClient = MockFunctionsClient();
    when(() => functionsClient.call(any(), any())).thenAnswer((_) async => {});
    when(() => firestoreService.watchAllUsers()).thenAnswer(
      (_) => Stream.value(const [
        UserProfile(uid: 's1', name: 'Bia', email: 'bia@x.com'),
      ]),
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => AdminProvider(
              firestoreService: firestoreService,
              functionsClient: functionsClient,
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => FinanceProvider(
              firestoreService: firestoreService,
              client: functionsClient,
            ),
          ),
        ],
        child: const MaterialApp(home: AdminUsersScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plano de IA: Premium'));
    await tester.pump();
    await tester.pump();

    verify(
      () => functionsClient.call('setStudentPlanTier', {
        'studentUid': 's1',
        'planTier': 'premium',
      }),
    ).called(1);
    expect(find.text('Plano de IA de Bia: Premium.'), findsOneWidget);
  });
}
