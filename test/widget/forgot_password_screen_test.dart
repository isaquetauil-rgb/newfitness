import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/auth/presentation/forgot_password_screen.dart';

import '../helpers/mocks.dart';

void main() {
  testWidgets('envia link de recuperação e mostra confirmação', (tester) async {
    final authService = MockAuthService();
    final firestoreService = MockFirestoreService();
    when(() => authService.authStateChanges)
        .thenAnswer((_) => const Stream.empty());
    when(() => authService.sendPasswordResetEmail(any()))
        .thenAnswer((_) async {});

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(
          authService: authService,
          firestoreService: firestoreService,
        ),
        child: MaterialApp(home: const ForgotPasswordScreen()),
      ),
    );

    await tester.enterText(find.byType(TextFormField), 'ana@example.com');
    await tester.tap(find.text('Enviar link de recuperação'));
    await tester.pumpAndSettle();

    expect(find.text('E-mail enviado!'), findsOneWidget);
    verify(() => authService.sendPasswordResetEmail('ana@example.com'))
        .called(1);
  });
}
