/// Situação de um aluno para o painel do profissional (personal ou
/// nutricionista). Lógica pura: sem Flutter e sem Firebase.
library;

/// Depois de quantos dias sem treinar o aluno conta como parado.
const int inactiveAfterDays = 7;

enum StudentStatus {
  /// Treinou nos últimos [inactiveAfterDays] dias e tem plano.
  active,

  /// Tem plano, mas não treina há mais de [inactiveAfterDays] dias.
  inactive,

  /// Tem plano e ainda não registrou nenhum treino.
  neverTrained,

  /// Ainda não tem plano.
  noPlan,
}

class StudentActivity {
  const StudentActivity({
    required this.lastActivity,
    required this.countThisWeek,
    required this.hasPlan,
  });

  /// Último registro (treino, ou refeição para a nutricionista).
  final DateTime? lastActivity;

  /// Registros desde a segunda-feira desta semana.
  final int countThisWeek;
  final bool hasPlan;

  StudentStatus statusAt(DateTime now) {
    if (!hasPlan) return StudentStatus.noPlan;
    final last = lastActivity;
    if (last == null) return StudentStatus.neverTrained;
    return daysSince(last, now) > inactiveAfterDays
        ? StudentStatus.inactive
        : StudentStatus.active;
  }

  /// Sem plano, parado ou sem nenhum registro: o profissional deve olhar.
  bool needsAttentionAt(DateTime now) => statusAt(now) != StudentStatus.active;
}

/// Dias de calendário entre [then] e [now] (hoje = 0, ontem = 1).
int daysSince(DateTime then, DateTime now) {
  final a = DateTime(then.year, then.month, then.day);
  final b = DateTime(now.year, now.month, now.day);
  return b.difference(a).inDays;
}

/// Segunda-feira 00:00 da semana de [now].
DateTime startOfWeek(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return today.subtract(Duration(days: today.weekday - DateTime.monday));
}

/// Junta as datas dos registros do aluno numa [StudentActivity].
StudentActivity summarizeActivity({
  required Iterable<DateTime> dates,
  required bool hasPlan,
  required DateTime now,
}) {
  DateTime? last;
  var week = 0;
  final monday = startOfWeek(now);
  for (final d in dates) {
    if (d.isAfter(now)) continue;
    if (last == null || d.isAfter(last)) last = d;
    if (!d.isBefore(monday)) week++;
  }
  return StudentActivity(
    lastActivity: last,
    countThisWeek: week,
    hasPlan: hasPlan,
  );
}

/// "hoje", "ontem", "há 3 dias", "há 2 semanas", "há 3 meses".
String relativeDayLabel(DateTime then, DateTime now) {
  final days = daysSince(then, now);
  if (days <= 0) return 'hoje';
  if (days == 1) return 'ontem';
  if (days < 14) return 'há $days dias';
  if (days < 60) return 'há ${days ~/ 7} semanas';
  return 'há ${days ~/ 30} meses';
}

/// Linha de situação do aluno no painel. [verb] é o registro no passado
/// ("Treinou", "Registrou refeição"); [one]/[many] nomeiam os registros da
/// semana ("treino"/"treinos", "refeição"/"refeições").
String studentStatusLine(
  StudentActivity a,
  DateTime now, {
  String verb = 'Treinou',
  String one = 'treino',
  String many = 'treinos',
  String never = 'Ainda não treinou',
}) {
  final parts = <String>[];
  final last = a.lastActivity;
  parts.add(last == null ? never : '$verb ${relativeDayLabel(last, now)}');
  final n = a.countThisWeek;
  if (n > 0) parts.add('$n ${n == 1 ? one : many} na semana');
  if (!a.hasPlan) parts.add('sem plano');
  return parts.join(' · ');
}
