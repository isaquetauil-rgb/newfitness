import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:newfitness/app/widgets/effects.dart';

/// Efeitos: abertura, entrada em cascata, troca de aba e confete — e todos
/// desligados quando o celular pede "remover animações".
void main() {
  double opacityOf(WidgetTester tester, Finder f) => tester
      .widget<Opacity>(
        find.ancestor(of: f, matching: find.byType(Opacity)).first,
      )
      .opacity;

  testWidgets('cascata: começa invisível e termina no lugar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: staggered([const Text('um'), const Text('dois')]),
        ),
      ),
    );
    expect(opacityOf(tester, find.text('dois')), 0);
    await tester.pumpAndSettle();
    expect(opacityOf(tester, find.text('um')), 1);
    expect(opacityOf(tester, find.text('dois')), 1);
  });

  testWidgets('com "remover animações" tudo aparece na hora', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Column(children: staggered([const Text('um')])),
        ),
      ),
    );
    expect(opacityOf(tester, find.text('um')), 1);
  });

  testWidgets('abertura: cobre o app, some sozinha e só na 1ª vez', (
    tester,
  ) async {
    AppIntroOverlay.shown = false;
    await tester.pumpWidget(
      const MaterialApp(home: AppIntroOverlay(child: Text('conteúdo'))),
    );
    expect(find.text('NewFitness'), findsOneWidget);
    expect(find.text('conteúdo'), findsOneWidget); // monta por baixo
    await tester.pumpAndSettle();
    expect(find.text('NewFitness'), findsNothing);
    expect(find.text('conteúdo'), findsOneWidget);

    // Abrir de novo na mesma execução não repete a abertura.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      const MaterialApp(home: AppIntroOverlay(child: Text('conteúdo'))),
    );
    expect(find.text('NewFitness'), findsNothing);
  });

  testWidgets('confete aparece e some sozinho', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showConfetti(context),
            child: const Text('salvar'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('salvar'));
    await tester.pump();
    expect(find.byType(ConfettiBurst), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(ConfettiBurst), findsNothing);
  });

  testWidgets('troca de aba esmaece a aba nova', (tester) async {
    Widget app(int i) => MaterialApp(
      home: TabFade(index: i, child: Text('aba $i')),
    );
    await tester.pumpWidget(app(0));
    double fade() => tester
        .widget<FadeTransition>(find.byType(FadeTransition).last)
        .opacity
        .value;
    expect(fade(), 1);
    await tester.pumpWidget(app(1));
    await tester.pump(const Duration(milliseconds: 16));
    expect(fade(), lessThan(1));
    await tester.pumpAndSettle();
    expect(fade(), 1);
  });
}
