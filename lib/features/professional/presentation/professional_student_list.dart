import 'package:flutter/material.dart';

import 'package:newfitness/features/professional/logic/student_activity.dart';
import 'package:newfitness/features/professional/presentation/professional_dashboard_widgets.dart';

/// Filtro da lista de alunos no painel.
enum StudentListFilter { all, attention, noPlan }

/// Lista de alunos do painel do profissional: busca por nome/e-mail,
/// filtros (todos, precisam de atenção, sem plano), quem precisa de atenção
/// primeiro e a situação de cada um. Usada pelo personal e pela
/// nutricionista.
class ProfessionalStudentList extends StatelessWidget {
  const ProfessionalStudentList({
    super.key,
    required this.students,
    required this.activity,
    required this.now,
    required this.query,
    required this.filter,
    required this.onQueryChanged,
    required this.onFilterChanged,
    required this.onOpen,
    required this.statusLine,
    this.noPlanLabel = 'Sem plano',
    this.emptyText =
        'Nenhum aluno vinculado ainda.\nCompartilhe seu código de convite '
        'acima: o aluno digita no Perfil dele e aparece aqui.',
  });

  final List<Map<String, dynamic>> students;

  /// Situação por uid; `null` enquanto carrega.
  final Map<String, StudentActivity?>? activity;
  final DateTime now;
  final String query;
  final StudentListFilter filter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<StudentListFilter> onFilterChanged;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final String Function(StudentActivity a, DateTime now) statusLine;
  final String noPlanLabel;
  final String emptyText;

  StudentActivity? _activityOf(Map<String, dynamic> s) =>
      activity?[s['uid'] as String];

  /// Alunos que passam na busca e no filtro, na ordem de exibição.
  List<Map<String, dynamic>> visibleStudents() {
    final q = query.trim().toLowerCase();
    return [
      for (final s in students)
        if ((q.isEmpty ||
                (s['name'] as String? ?? '').toLowerCase().contains(q) ||
                (s['email'] as String? ?? '').toLowerCase().contains(q)) &&
            switch (filter) {
              StudentListFilter.all => true,
              StudentListFilter.attention =>
                _activityOf(s)?.needsAttentionAt(now) ?? false,
              StudentListFilter.noPlan =>
                _activityOf(s)?.statusAt(now) == StudentStatus.noPlan,
            })
          s,
    ]..sort(
      (a, b) => _sortKey(_activityOf(a)).compareTo(_sortKey(_activityOf(b))),
    );
  }

  /// Quem precisa de atenção primeiro; depois quem registrou há mais tempo.
  int _sortKey(StudentActivity? a) {
    if (a == null) return 1 << 20;
    return switch (a.statusAt(now)) {
      StudentStatus.noPlan => 0,
      StudentStatus.inactive => 1,
      StudentStatus.neverTrained => 2,
      StudentStatus.active =>
        1000 - daysSince(a.lastActivity!, now).clamp(0, 999),
    };
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final visible = visibleStudents();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DashboardSectionTitle(
          'Alunos',
          trailing: Text(
            '${visible.length} de ${students.length}',
            style: TextStyle(color: muted),
          ),
        ),
        if (students.isNotEmpty) ...[
          TextField(
            key: const ValueKey('student-search'),
            decoration: const InputDecoration(
              hintText: 'Buscar aluno por nome ou e-mail',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: onQueryChanged,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final (f, label) in [
                (StudentListFilter.all, 'Todos'),
                (StudentListFilter.attention, 'Precisam de atenção'),
                (StudentListFilter.noPlan, noPlanLabel),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: filter == f,
                  onSelected: (_) => onFilterChanged(f),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (students.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Icon(
                  Icons.person_add_alt_1_outlined,
                  size: 40,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  emptyText,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted),
                ),
              ],
            ),
          )
        else if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Nenhum aluno com esse filtro.',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted),
            ),
          )
        else
          for (final s in visible) _tile(s),
      ],
    );
  }

  Widget _tile(Map<String, dynamic> student) {
    final name = student['name'] as String? ?? '';
    final a = _activityOf(student);
    final subtitle = activity == null
        ? 'Carregando...'
        : a == null
        ? (student['email'] as String? ?? '')
        : statusLine(a, now);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
        ),
        title: Text(name),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StudentStatusDot(status: a?.statusAt(now)),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => onOpen(student),
      ),
    );
  }
}

/// Junta a situação de cada aluno. [load] devolve, para um aluno, as datas
/// dos registros e se ele tem plano. Erro num aluno (sem permissão, sem
/// conexão) deixa só ele sem situação.
Future<Map<String, StudentActivity?>> loadStudentsActivity(
  List<String> uids,
  Future<(Iterable<DateTime>, bool)> Function(String uid) load,
  DateTime now,
) async {
  final entries = await Future.wait(
    uids.map((uid) async {
      try {
        final (dates, hasPlan) = await load(uid);
        return MapEntry<String, StudentActivity?>(
          uid,
          summarizeActivity(dates: dates, hasPlan: hasPlan, now: now),
        );
      } catch (_) {
        return MapEntry<String, StudentActivity?>(uid, null);
      }
    }),
  );
  return Map.fromEntries(entries);
}
