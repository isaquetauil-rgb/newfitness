import 'package:flutter_test/flutter_test.dart';

import 'package:newfitness/features/workout/logic/progression/progression_rule.dart';
import 'package:newfitness/features/workout/logic/progression/suggest_next.dart';
import 'package:newfitness/shared/models/workout_set.dart';

/// Sessão no dia [day] com séries concluídas de [reps] a [kg].
ExerciseSession _s(int day, double kg, List<int> reps, {List<bool>? done}) =>
    ExerciseSession(
      date: DateTime(2026, 1, day),
      sets: [
        for (int i = 0; i < reps.length; i++)
          WorkoutSet(reps: reps[i], weightKg: kg, completed: done?[i] ?? true),
      ],
    );

ProgressionRule _linear({int reps = 5, int? sets}) =>
    ProgressionRule.fromTargetReps('$reps', targetSets: sets)!;

ProgressionRule _dupla({int? sets}) =>
    ProgressionRule.fromTargetReps('8-12', targetSets: sets)!;

void main() {
  group('parseRepRange / fromTargetReps', () {
    test('faixa vira dupla, número único vira linear', () {
      expect(parseRepRange('8-12'), (8, 12));
      expect(parseRepRange('8–12'), (8, 12));
      expect(parseRepRange('8 a 12'), (8, 12));
      expect(parseRepRange('12-8'), (8, 12));
      expect(parseRepRange('10'), (10, 10));
      expect(parseRepRange('12 cada lado'), (12, 12));
      expect(
        ProgressionRule.fromTargetReps('8-12')!.type,
        ProgressionType.doubleProgression,
      );
      expect(ProgressionRule.fromTargetReps('5')!.type, ProgressionType.linear);
    });

    test('texto que não é contagem de reps não vira regra', () {
      for (final t in ['', 'até a falha', '30 s', '20-30 s', '1 km', '2 min']) {
        expect(ProgressionRule.fromTargetReps(t), isNull, reason: t);
      }
    });

    test('padrões: 2,5 kg, 3 travadas, 10% e passo de 0,5 kg', () {
      final r = ProgressionRule.fromTargetReps('8-12')!;
      expect(r.incrementKg, 2.5);
      expect(r.stallLimit, 3);
      expect(r.deloadPercent, 10);
      expect(r.roundingStepKg, 0.5);
    });

    test('tipo forçado pelo personal', () {
      final linear = ProgressionRule.fromTargetReps(
        '8-12',
        type: ProgressionType.linear,
      )!;
      expect((linear.minReps, linear.maxReps), (12, 12));
      final dupla = ProgressionRule.fromTargetReps(
        '10',
        type: ProgressionType.doubleProgression,
      )!;
      expect((dupla.minReps, dupla.maxReps), (10, 10));
    });

    test('nome do tipo vai e volta como texto', () {
      for (final t in ProgressionType.values) {
        expect(progressionTypeFromString(progressionTypeToString(t)), t);
      }
      expect(progressionTypeFromString('outra'), isNull);
    });
  });

  group('sem sugestão', () {
    test('sem histórico', () {
      expect(suggestNext(_linear(), []), isNull);
    });

    test('peso corporal, tempo ou distância', () {
      final h = [
        _s(1, 40, [5, 5, 5]),
      ];
      expect(suggestNext(_linear(), h, bodyweight: true), isNull);
      expect(suggestNext(_linear(), h, tracksDuration: true), isNull);
      expect(suggestNext(_linear(), h, tracksDistance: true), isNull);
    });

    test('séries sem carga contam como peso corporal', () {
      expect(
        suggestNext(_dupla(), [
          _s(1, 0, [12, 12]),
        ]),
        isNull,
      );
    });

    test('nenhuma série concluída', () {
      final h = [
        _s(1, 40, [5, 5], done: [false, false]),
      ];
      expect(suggestNext(_linear(), h), isNull);
    });
  });

  group('linear', () {
    test('bateu as reps em todas as séries: sobe o incremento', () {
      final s = suggestNext(_linear(), [
        _s(1, 60, [5, 5, 5]),
      ])!;
      expect(s.weightKg, 62.5);
      expect(s.targetReps, 5);
      expect(s.reason, contains('62,5 kg'));
    });

    test('falhou: mantém o peso', () {
      final s = suggestNext(_linear(), [
        _s(1, 60, [5, 5, 4]),
      ])!;
      expect(s.weightKg, 60);
      expect(s.reason, contains('Mantenha 60 kg'));
    });

    test('usa a sessão mais recente, em qualquer ordem', () {
      final s = suggestNext(_linear(), [
        _s(5, 62.5, [5, 5, 5]),
        _s(1, 60, [5, 5, 3]),
      ])!;
      expect(s.weightKg, 65);
    });

    test('falhou stallLimit vezes seguidas: deload arredondado', () {
      final s = suggestNext(_linear(), [
        _s(1, 62.5, [5, 5, 4]),
        _s(2, 62.5, [5, 4, 4]),
        _s(3, 62.5, [5, 5, 3]),
      ])!;
      // 62,5 × 0,9 = 56,25 → 56,5 (passo de 0,5 kg).
      expect(s.weightKg, 56.5);
      expect(s.reason, contains('3 treinos seguidos'));
      expect(s.reason, contains('10%'));
    });

    test('falhas em outra carga não contam para o deload', () {
      final s = suggestNext(_linear(), [
        _s(1, 60, [5, 4, 4]),
        _s(2, 62.5, [5, 5, 4]),
        _s(3, 62.5, [5, 5, 3]),
      ])!;
      expect(s.weightKg, 62.5);
    });

    test('uma sessão boa no meio zera a contagem', () {
      final s = suggestNext(_linear(), [
        _s(1, 60, [5, 4, 4]),
        _s(2, 60, [5, 5, 5]),
        _s(3, 60, [5, 4, 4]),
        _s(4, 60, [5, 5, 3]),
      ])!;
      expect(s.weightKg, 60);
    });

    test('deload em carga pequena ainda reduz', () {
      final s = suggestNext(_linear(), [
        _s(1, 3, [5, 4]),
        _s(2, 3, [5, 4]),
        _s(3, 3, [5, 4]),
      ])!;
      // 3 × 0,9 = 2,7 → 2,5.
      expect(s.weightKg, 2.5);
    });

    test('faltou uma série prescrita: não sobe', () {
      final s = suggestNext(_linear(sets: 3), [
        _s(1, 60, [5, 5]),
      ])!;
      expect(s.weightKg, 60);
    });

    test('série não concluída é ignorada', () {
      final s = suggestNext(_linear(), [
        _s(1, 60, [5, 5, 2], done: [true, true, false]),
      ])!;
      expect(s.weightKg, 62.5);
    });

    test('respeita incremento e passo do personal', () {
      final rule = ProgressionRule.fromTargetReps(
        '10',
        incrementKg: 1,
        roundingStepKg: 1,
      )!;
      final s = suggestNext(rule, [
        _s(1, 20, [10, 10]),
      ])!;
      expect(s.weightKg, 21);
    });
  });

  group('dupla', () {
    test('todas no máximo da faixa: sobe a carga e volta ao mínimo', () {
      final s = suggestNext(_dupla(), [
        _s(1, 30, [12, 12, 12]),
      ])!;
      expect(s.weightKg, 32.5);
      expect(s.targetReps, 8);
      expect(s.reason, contains('volte para 8 reps'));
    });

    test('ainda não chegou ao máximo: mesmo peso, +1 rep', () {
      final s = suggestNext(_dupla(), [
        _s(1, 30, [10, 9, 9]),
      ])!;
      expect(s.weightKg, 30);
      expect(s.targetReps, 10);
    });

    test('quase lá (uma série abaixo do máximo): não sobe', () {
      final s = suggestNext(_dupla(), [
        _s(1, 30, [12, 12, 11]),
      ])!;
      expect(s.weightKg, 30);
      expect(s.targetReps, 12);
    });

    test('abaixo do mínimo da faixa: mantém e mira o mínimo', () {
      final s = suggestNext(_dupla(), [
        _s(1, 30, [6, 5, 5]),
      ])!;
      expect(s.weightKg, 30);
      expect(s.targetReps, 8);
    });

    test('faltou série prescrita: não sobe', () {
      final s = suggestNext(_dupla(sets: 3), [
        _s(1, 30, [12, 12]),
      ])!;
      expect(s.weightKg, 30);
    });

    test('carga de trabalho é a maior entre as séries', () {
      final session = ExerciseSession(
        date: DateTime(2026, 1, 1),
        sets: [
          WorkoutSet(reps: 12, weightKg: 20, completed: true),
          WorkoutSet(reps: 12, weightKg: 25, completed: true),
        ],
      );
      expect(suggestNext(_dupla(), [session])!.weightKg, 27.5);
    });
  });

  group('dupla: deload por estagnação', () {
    test('reps sem subir em stallLimit sessões seguidas: deload e mínimo', () {
      final s = suggestNext(_dupla(), [
        _s(1, 40, [10, 10, 9]), // base: 29
        _s(2, 40, [10, 9, 9]), // 28
        _s(3, 40, [10, 10, 8]), // 28
        _s(4, 40, [9, 9, 9]), // 27
      ])!;
      // 40 × 0,9 = 36.
      expect(s.weightKg, 36);
      expect(s.targetReps, 8);
      expect(s.reason, contains('3 treinos seguidos'));
      expect(s.reason, contains('10%'));
    });

    test('total igual também conta como não ter aumentado', () {
      final s = suggestNext(_dupla(), [
        _s(1, 40, [10, 10, 10]),
        _s(2, 40, [11, 10, 9]),
        _s(3, 40, [10, 11, 9]),
        _s(4, 40, [9, 10, 11]),
      ])!;
      expect(s.weightKg, 36);
    });

    test('uma sessão com mais reps no meio zera a contagem', () {
      final s = suggestNext(_dupla(), [
        _s(1, 40, [10, 10, 9]),
        _s(2, 40, [10, 10, 10]), // subiu
        _s(3, 40, [10, 10, 9]),
        _s(4, 40, [10, 9, 9]),
      ])!;
      expect(s.weightKg, 40);
    });

    test('ainda abaixo do limite: mantém a carga', () {
      final s = suggestNext(_dupla(), [
        _s(1, 40, [10, 10, 9]),
        _s(2, 40, [10, 9, 9]),
        _s(3, 40, [10, 9, 9]),
      ])!;
      expect(s.weightKg, 40);
    });

    test('sessões em outra carga não contam', () {
      final s = suggestNext(_dupla(), [
        _s(1, 37.5, [12, 12, 12]),
        _s(2, 40, [10, 10, 9]),
        _s(3, 40, [10, 9, 9]),
        _s(4, 40, [9, 9, 9]),
      ])!;
      expect(s.weightKg, 40);
    });

    test('respeita stallLimit e deloadPercent do personal', () {
      final rule = ProgressionRule.fromTargetReps(
        '8-12',
        stallLimit: 1,
        deloadPercent: 20,
      )!;
      final s = suggestNext(rule, [
        _s(1, 50, [10, 10]),
        _s(2, 50, [10, 9]),
      ])!;
      expect(s.weightKg, 40);
      expect(s.targetReps, 8);
    });

    test('deload arredondado pelo passo', () {
      final s = suggestNext(_dupla(), [
        _s(1, 22.5, [9, 9]),
        _s(2, 22.5, [9, 9]),
        _s(3, 22.5, [9, 9]),
        _s(4, 22.5, [9, 9]),
      ])!;
      // 22,5 × 0,9 = 20,25 → 20,5.
      expect(s.weightKg, 20.5);
    });
  });

  test('nunca sobe a carga quando faltou rep', () {
    final cases = <(ProgressionRule, List<int>)>[
      (_linear(), [5, 5, 4]),
      (_linear(reps: 10), [9, 10]),
      (_dupla(), [12, 11, 12]),
      (_dupla(), [8, 8, 8]),
    ];
    for (final (rule, reps) in cases) {
      for (final kg in [5.0, 40.0, 100.0]) {
        final s = suggestNext(rule, [_s(1, kg, reps)])!;
        expect(s.weightKg, lessThanOrEqualTo(kg), reason: '$reps @ $kg');
      }
    }
  });
}
