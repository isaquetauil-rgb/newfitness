/// Histórico da meta semanal de treinos: cada mudança vale a partir da
/// semana em que foi feita, e cada semana do passado é avaliada pela meta
/// que valia nela (baixar ou subir a meta não reescreve o passado).
library;

/// Segunda-feira (meia-noite) da semana de [date] — mesma regra do
/// `WeekSummary`.
DateTime goalWeekStart(DateTime date) =>
    DateTime(date.year, date.month, date.day - (date.weekday - 1));

/// A meta passou a ser [goal] a partir da semana que começa em [since].
class WeeklyGoalChange {
  const WeeklyGoalChange({required this.goal, required this.since});

  final int goal;

  /// Segunda-feira da semana em que a meta passou a valer.
  final DateTime since;

  static WeeklyGoalChange? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final goal = (raw['goal'] as num?)?.toInt();
    final since = (raw['since'] as num?)?.toInt();
    if (goal == null || since == null || goal < 1 || goal > 7) return null;
    return WeeklyGoalChange(
      goal: goal,
      since: DateTime.fromMillisecondsSinceEpoch(since),
    );
  }

  Map<String, dynamic> toMap() => {
    'goal': goal,
    'since': since.millisecondsSinceEpoch,
  };

  @override
  bool operator ==(Object other) =>
      other is WeeklyGoalChange && other.goal == goal && other.since == since;

  @override
  int get hashCode => Object.hash(goal, since);
}

/// Qual meta valia em cada semana.
class WeeklyGoalSchedule {
  WeeklyGoalSchedule(List<WeeklyGoalChange> changes, {required this.fallback})
    : changes = [...changes]..sort((a, b) => a.since.compareTo(b.since));

  /// Do mais antigo para o mais recente.
  final List<WeeklyGoalChange> changes;

  /// Meta quando não há histórico (perfil antigo): vale para todas as
  /// semanas.
  final int fallback;

  /// Meta da semana que começa em [weekStart]. Antes da primeira mudança
  /// registrada, vale a primeira.
  int goalFor(DateTime weekStart) {
    if (changes.isEmpty) return fallback;
    final week = goalWeekStart(weekStart);
    var goal = changes.first.goal;
    for (final c in changes) {
      if (c.since.isAfter(week)) break;
      goal = c.goal;
    }
    return goal;
  }

  /// Novo histórico depois de mudar a meta para [goal] em [now]: vale a
  /// partir desta semana. Na primeira mudança, a meta anterior fica
  /// registrada para todo o passado; mudar duas vezes na mesma semana
  /// substitui a anterior.
  WeeklyGoalSchedule withChange(int goal, DateTime now) {
    final week = goalWeekStart(now);
    final list = changes.isEmpty
        ? [WeeklyGoalChange(goal: fallback, since: DateTime(1970))]
        : [...changes];
    list.removeWhere((c) => c.since == week);
    list.add(WeeklyGoalChange(goal: goal, since: week));
    return WeeklyGoalSchedule(list, fallback: fallback);
  }
}
