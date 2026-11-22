import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newfitness/core/error/app_exception.dart';
import 'package:newfitness/features/profile/presentation/privacy_screen.dart';

void main() {
  testWidgets('exporta e mostra o link do ZIP', (tester) async {
    final opened = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: PrivacyScreen(
          exporter: () async => DataExport(
            zipUrl: 'https://x.test/meus-dados.zip',
            expiresAt: DateTime(2026, 11, 20, 15, 30),
            workouts: 12,
            photos: 3,
            sizeBytes: 5 * 1024 * 1024,
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
    expect(find.textContaining('3 fotos · 5,0 MB'), findsOneWidget);
    expect(find.textContaining('ficaram de fora'), findsNothing);

    await tester.tap(find.text('Baixar meus dados (ZIP)'));
    await tester.pump();
    expect(opened.single.toString(), 'https://x.test/meus-dados.zip');
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

  testWidgets('fotos acima do limite: avisa', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PrivacyScreen(
          exporter: () async => DataExport(
            zipUrl: 'https://x.test/z.zip',
            expiresAt: DateTime(2026, 11, 20, 15, 30),
            workouts: 1,
            photos: 40,
            photosOmitted: 7,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Exportar meus dados').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('7 fotos ficaram de fora'), findsOneWidget);
  });
}
