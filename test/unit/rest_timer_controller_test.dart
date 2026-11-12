import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:newfitness/features/notifications/data/notification_service.dart';
import 'package:newfitness/features/workout/logic/rest_timer_controller.dart';
import 'package:newfitness/features/workout/logic/workout_provider.dart';
import 'package:newfitness/shared/models/training_plan.dart';

import '../helpers/mocks.dart';

/// Registra o que o controller pediu aos avisos.
class _Alerts implements RestAlerts {
  final scheduled = <DateTime>[];
  int cancels = 0;
  int vibrations = 0;
  RestTimerSettings? lastSettings;

  @override
  Future<void> scheduleEnd(DateTime at, RestTimerSettings settings) async {
    scheduled.add(at);
    lastSettings = settings;
  }

  @override
  Future<void> cancelEnd() async => cancels++;

  @override
  void vibrate() => vibrations++;
}

final _t0 = DateTime(2026, 1, 1, 10);

void main() {
  late _Alerts alerts;

  setUp(() => alerts = _Alerts());

  /// Controller com o relógio do [FakeAsync] (o tempo só anda com elapse).
  RestTimerController make(
    FakeAsync async, {
    RestTimerSettings settings = const RestTimerSettings(),
  }) {
    final clock = async.getClock(_t0);
    return RestTimerController(
      alerts: alerts,
      settings: settings,
      now: clock.now,
    );
  }

  test('guarda o horário de fim e conta pelo relógio', () {
    fakeAsync((async) {
      final c = make(async);
      c.start(90);
      expect(c.endsAt, _t0.add(const Duration(seconds: 90)));
      expect(c.remainingSeconds, 90);
      async.elapse(const Duration(seconds: 30));
      expect(c.remainingSeconds, 60);
      expect(c.progress, closeTo(60 / 90, 1e-9));
      c.dispose();
    });
  });

  test('agenda a notificação de fim ao começar', () {
    fakeAsync((async) {
      final c = make(async);
      c.start(60);
      async.flushMicrotasks();
      expect(alerts.scheduled, [_t0.add(const Duration(seconds: 60))]);
      c.dispose();
    });
  });

  test('no fim: vibra e encerra sozinho', () {
    fakeAsync((async) {
      final c = make(async);
      c.start(60);
      async.elapse(const Duration(seconds: 60));
      expect(c.isActive, isFalse);
      expect(alerts.vibrations, 1);
      c.dispose();
    });
  });

  test('vibração desligada nas configurações: não vibra', () {
    fakeAsync((async) {
      final c = make(
        async,
        settings: const RestTimerSettings(vibration: false),
      );
      c.start(30);
      async.elapse(const Duration(seconds: 31));
      expect(c.isActive, isFalse);
      expect(alerts.vibrations, 0);
      c.dispose();
    });
  });

  test('app volta do segundo plano bem depois do fim: encerra sem vibrar', () {
    var now = _t0;
    final c = RestTimerController(alerts: alerts, now: () => now);
    c.start(60);
    // O Timer do Dart não rodou (app suspenso); o relógio andou.
    now = _t0.add(const Duration(minutes: 5));
    expect(c.remainingSeconds, 0);
    expect(c.checkFinished(), isTrue);
    expect(c.isActive, isFalse);
    expect(alerts.vibrations, 0);
    c.dispose();
  });

  test('+15 e -15 reagendam a notificação', () {
    fakeAsync((async) {
      final c = make(async);
      c.start(60);
      c.adjust(15);
      expect(c.remainingSeconds, 75);
      expect(c.totalSeconds, 75);
      c.adjust(-15);
      expect(c.remainingSeconds, 60);
      async.flushMicrotasks();
      expect(alerts.scheduled.last, _t0.add(const Duration(seconds: 60)));
      expect(alerts.scheduled, hasLength(3));
      c.dispose();
    });
  });

  test('-15 que zera o tempo encerra sem alarme e cancela a notificação', () {
    fakeAsync((async) {
      final c = make(async);
      c.start(10);
      c.adjust(-15);
      async.flushMicrotasks();
      expect(c.isActive, isFalse);
      expect(alerts.cancels, 1);
      expect(alerts.vibrations, 0);
      async.elapse(const Duration(seconds: 20));
      expect(alerts.vibrations, 0);
      c.dispose();
    });
  });

  test('pular cancela a notificação e o alarme', () {
    fakeAsync((async) {
      final c = make(async);
      c.start(60);
      c.skip();
      async.elapse(const Duration(seconds: 61));
      expect(c.isActive, isFalse);
      expect(alerts.cancels, 1);
      expect(alerts.vibrations, 0);
      c.dispose();
    });
  });

  test('pausar guarda o que falta; retomar reagenda', () {
    fakeAsync((async) {
      final c = make(async);
      c.start(60);
      async.elapse(const Duration(seconds: 20));
      c.pause();
      expect(c.isPaused, isTrue);
      async.elapse(const Duration(seconds: 100));
      expect(c.remainingSeconds, 40);
      expect(alerts.vibrations, 0);
      c.resume();
      async.flushMicrotasks();
      expect(alerts.scheduled.last, _t0.add(const Duration(seconds: 160)));
      async.elapse(const Duration(seconds: 40));
      expect(alerts.vibrations, 1);
      c.dispose();
    });
  });

  test('início automático desligado: marcar série não começa', () {
    fakeAsync((async) {
      final c = make(
        async,
        settings: const RestTimerSettings(autoStart: false),
      );
      c.onSetCompleted(90);
      expect(c.isActive, isFalse);
      c.updateSettings(const RestTimerSettings());
      c.onSetCompleted(90);
      expect(c.remainingSeconds, 90);
      c.dispose();
    });
  });

  test('som e vibração vão para a notificação', () {
    fakeAsync((async) {
      final c = make(async, settings: const RestTimerSettings(sound: false));
      c.start(30);
      async.flushMicrotasks();
      expect(alerts.lastSettings!.sound, isFalse);
      expect(alerts.lastSettings!.vibration, isTrue);
      c.dispose();
    });
  });

  test('canal do Android para cada combinação de som e vibração', () {
    final ids = {
      for (final s in [true, false])
        for (final v in [true, false])
          restChannelFor(sound: s, vibration: v).$1,
    };
    expect(ids, hasLength(4));
  });

  group('WorkoutProvider', () {
    late List<bool> screen;
    late RestTimerController timer;
    late WorkoutProvider provider;

    setUp(() {
      screen = [];
      timer = RestTimerController(alerts: alerts);
      provider = WorkoutProvider(
        firestoreService: MockFirestoreService(),
        restTimer: timer,
        keepScreenOn: (on) async => screen.add(on),
      );
      provider.startFromPlan(
        'u1',
        TrainingPlan(
          id: 'p',
          studentUid: 'u1',
          instructorUid: 'i',
          title: 'P',
          createdAt: DateTime(2026),
          workouts: [
            const TrainingSubWorkout(
              label: 'A',
              exercises: [
                PlanExercise(
                  exerciseId: 'x',
                  exerciseName: 'X',
                  targetSets: 2,
                  targetReps: '10',
                  restSeconds: 75,
                ),
              ],
            ),
          ],
        ),
        0,
      );
    });

    tearDown(() => timer.skip());

    test('marcar série começa o descanso com o restSeconds do exercício', () {
      provider.updateSet(0, 0, completed: true);
      expect(timer.remainingSeconds, inInclusiveRange(74, 75));
    });

    test('tela acesa durante o treino e liberada ao cancelar', () {
      expect(screen, [true]);
      provider.updateSet(0, 0, completed: true);
      provider.cancelWorkout();
      expect(screen, [true, false]);
      expect(timer.isActive, isFalse);
    });
  });
}
