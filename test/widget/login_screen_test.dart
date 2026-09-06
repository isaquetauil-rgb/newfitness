import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/app/theme/app_theme.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/auth/presentation/login_screen.dart';

import '../helpers/mocks.dart';

void main() {
  testWidgets('Tela de login mostra campos de e-mail e senha', (tester) async {
    final authService = MockAuthService();
    final firestoreService = MockFirestoreService();
    when(() => authService.authStateChanges)
        .thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(
          authService: authService,
          firestoreService: firestoreService,
        ),
        child: MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Senha'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Esqueci minha senha'), findsOneWidget);
  });
}
