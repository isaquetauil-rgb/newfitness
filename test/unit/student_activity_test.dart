import 'package:flutter_test/flutter_test.dart';
import 'package:newfitness/features/professional/logic/student_activity.dart';

void main() {
  // Quarta-feira, 25/11/2026, 15h.
  final now = DateTime(2026, 11, 25, 15);

  test('semana começa na segunda e conta só os registros dela', () {
    expect(startOfWeek(now), DateTime(2026, 11, 23));
    final a = summarizeActivity(
      dates: [
        DateTime(2026, 11, 22, 20), // domingo: semana passada
        DateTime(2026, 11, 23, 7),
        DateTime(2026, 11, 25, 6),
        DateTime(2026, 11, 26, 6), // futuro: ignora
      ],
      hasPlan: true,
      now: now,
    );
    expect(a.countThisWeek, 2);
    expect(a.lastActivity, DateTime(2026, 11, 25, 6));
    expect(a.statusAt(now), StudentStatus.active);
  });

  test('situações: sem plano, nunca treinou, parado, ativo', () {
    StudentActivity act(DateTime? last, {bool plan = true}) =>
        summarizeActivity(dates: [?last], hasPlan: plan, now: now);
    expect(act(now, plan: false).statusAt(now), StudentStatus.noPlan);
    expect(act(null).statusAt(now), StudentStatus.neverTrained);
    expect(
      act(now.subtract(const Duration(days: 7))).statusAt(now),
      StudentStatus.active,
    );
    expect(
      act(now.subtract(const Duration(days: 8))).statusAt(now),
      StudentStatus.inactive,
    );
    expect(act(now).needsAttentionAt(now), isFalse);
    expect(act(null).needsAttentionAt(now), isTrue);
  });

  test('textos', () {
    expect(relativeDayLabel(DateTime(2026, 11, 25, 1), now), 'hoje');
    expect(relativeDayLabel(DateTime(2026, 11, 24, 23), now), 'ontem');
    expect(relativeDayLabel(DateTime(2026, 11, 20), now), 'há 5 dias');
    expect(relativeDayLabel(DateTime(2026, 11, 4), now), 'há 3 semanas');
    expect(relativeDayLabel(DateTime(2026, 8, 1), now), 'há 3 meses');

    final a = summarizeActivity(
      dates: [DateTime(2026, 11, 24), DateTime(2026, 11, 23)],
      hasPlan: true,
      now: now,
    );
    expect(studentStatusLine(a, now), 'Treinou ontem · 2 treinos na semana');
    final one = summarizeActivity(
      dates: [DateTime(2026, 11, 25)],
      hasPlan: false,
      now: now,
    );
    expect(
      studentStatusLine(one, now),
      'Treinou hoje · 1 treino na semana · sem plano',
    );
    final none = summarizeActivity(dates: const [], hasPlan: true, now: now);
    expect(studentStatusLine(none, now), 'Ainda não treinou');
    expect(
      studentStatusLine(
        one,
        now,
        verb: 'Registrou refeição',
        one: 'refeição',
        many: 'refeições',
      ),
      'Registrou refeição hoje · 1 refeição na semana · sem plano',
    );
  });
}
