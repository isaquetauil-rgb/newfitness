import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:newfitness/core/storage/local_prefs.dart';
import 'package:newfitness/features/workout/logic/rest_timer_controller.dart';
import 'package:newfitness/features/workout/logic/workout_provider.dart';
import 'package:newfitness/features/workout/presentation/rest_timer_sheet.dart';

import '../helpers/mocks.dart';

void main() {
  late RestTimerController timer;
  late WorkoutProvider provider;
  // Relógio do controller, avançado à mão (o pump não mexe em DateTime.now).
  late DateTime now;

  setUp(() {
    now = DateTime(2026, 1, 1, 10);
    timer = RestTimerController(now: () => now);
    provider = WorkoutProvider(
      firestoreService: MockFirestoreService(),
      restTimer: timer,
      keepScreenOn: (_) async {},
    );
  });

  tearDown(() => timer.skip());

  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    ChangeNotifierProvider<WorkoutProvider>.value(
      value: provider,
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );

  final bar = find.byKey(const ValueKey('rest-bar'));

  testWidgets('barra some sem descanso e mostra o tempo quando começa', (
    tester,
  ) async {
    await pump(tester, Column(children: [RestTimerBar(controller: timer)]));
    expect(bar, findsNothing);

    timer.start(90);
    await tester.pump();
    expect(bar, findsOneWidget);
    expect(find.text('Descanso 1:30'), findsOneWidget);

    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Descanso 1:28'), findsOneWidget);

    timer.skip();
    await tester.pump();
  });

  testWidgets('-15s, +15s e Pular', (tester) async {
    await pump(tester, Column(children: [RestTimerBar(controller: timer)]));
    timer.start(60);
    await tester.pump();

    await tester.tap(find.text('+15s'));
    await tester.pump();
    expect(find.text('Descanso 1:15'), findsOneWidget);

    await tester.tap(find.text('-15s'));
    await tester.pump();
    expect(find.text('Descanso 1:00'), findsOneWidget);

    await tester.tap(find.text('Pular'));
    await tester.pump();
    expect(bar, findsNothing);
    expect(timer.isActive, isFalse);
  });

  testWidgets('tocar na barra abre o cronômetro com o mesmo tempo', (
    tester,
  ) async {
    await pump(tester, Column(children: [RestTimerBar(controller: timer)]));
    timer.start(45);
    await tester.pump();

    await tester.tap(find.text('Descanso 0:45'));
    await tester.pumpAndSettle();
    expect(find.byType(RestTimerSheet), findsOneWidget);
    expect(find.text('00:45'), findsOneWidget);

    await tester.tap(find.byTooltip('Pausar'));
    await tester.pump();
    expect(timer.isPaused, isTrue);
    expect(find.text('Pausado 0:45'), findsOneWidget);
  });

  testWidgets('configurações ligam/desligam e ficam salvas', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = LocalPrefs(await SharedPreferences.getInstance());
    await pump(tester, RestTimerSettingsTiles(prefs: prefs));

    await tester.tap(find.byKey(const ValueKey('rest-auto-start')));
    await tester.tap(find.byKey(const ValueKey('rest-sound')));
    await tester.pump();

    expect(timer.settings.autoStart, isFalse);
    expect(timer.settings.sound, isFalse);
    expect(timer.settings.vibration, isTrue);
    expect(prefs.restAutoStart, isFalse);
    expect(prefs.restSound, isFalse);
    expect(prefs.restVibration, isTrue);
  });
}
