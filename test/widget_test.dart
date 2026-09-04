import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:provider/provider.dart';

import 'package:newfitness/providers/auth_provider.dart';
import 'package:newfitness/screens/auth/login_screen.dart';
import 'package:newfitness/theme/app_theme.dart';

void main() {
  testWidgets('Tela de login mostra campos de e-mail e senha', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider.test(),
        child: MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Senha'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
