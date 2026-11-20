import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newfitness/core/error/app_exception.dart';
import 'package:newfitness/features/profile/presentation/privacy_screen.dart';

void main() {
  testWidgets('exporta e mostra os dois links', (tester) async {
    final opened = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: PrivacyScreen(
          exporter: () async => DataExport(
            jsonUrl: 'https://x.test/dados.json',
            csvUrl: 'https://x.test/treinos.csv',
            expiresAt: DateTime(2026, 11, 20, 15, 30),
            workouts: 12,
          ),
          openUrl: (u) async {
            opened.add(u);
            return true;
          },
        ),
      ),
    );
    await tester.tap(find.text('Exportar meus dados').last);
    await tester.pumpAndSettle();
    expect(find.text('Seus dados estão prontos'), findsOneWidget);
    expect(find.textContaining('12 treinos'), findsOneWidget);
    expect(find.textContaining('15:30'), findsOneWidget);

    await tester.tap(find.text('Baixar planilha de treinos (CSV)'));
    await tester.pump();
    expect(opened.single.toString(), 'https://x.test/treinos.csv');
  });

  testWidgets('limite do dia: mostra a mensagem da Function', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PrivacyScreen(
          exporter: () async => throw const ValidationException(
            'Você já exportou seus dados hoje. Tente de novo amanhã.',
          ),
        ),
      ),
    );
    await tester.tap(find.text('Exportar meus dados').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('já exportou seus dados hoje'), findsOneWidget);
    expect(find.text('Seus dados estão prontos'), findsNothing);
  });
}
