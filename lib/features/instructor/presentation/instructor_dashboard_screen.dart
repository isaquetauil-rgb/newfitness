import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/app/routes/app_router.dart';
import 'package:newfitness/app/routes/app_routes.dart';
import 'package:newfitness/app/widgets/drawer_menu_button.dart';
import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/instructor/presentation/ai_suggestion_sheet.dart';
import 'package:newfitness/features/professional/logic/student_activity.dart';
import 'package:newfitness/features/professional/presentation/professional_dashboard_widgets.dart';
import 'package:newfitness/shared/models/appointment.dart';
import 'package:newfitness/shared/services/firestore_service.dart';

/// Filtro da lista de alunos no painel.
enum StudentListFilter { all, attention, noPlan }

/// Painel do personal: resumo dos alunos (quem treinou, quem precisa de
/// atenção), agenda de hoje, atalhos, código de convite e a lista de alunos
/// com a situação de cada um.
class InstructorDashboardScreen extends StatefulWidget {
  const InstructorDashboardScreen({
    super.key,
    this.firestoreService,
    this.clock,
  });

  /// Para testes; no app vem do injetor.
  final FirestoreService? firestoreService;

  /// Para testes: "agora".
  final DateTime Function()? clock;

  @override
  State<InstructorDashboardScreen> createState() =>
      _InstructorDashboardScreenState();
}

class _InstructorDashboardScreenState extends State<InstructorDashboardScreen> {
  late final FirestoreService _db =
      widget.firestoreService ?? getIt<FirestoreService>();

  Stream<List<Map<String, dynamic>>>? _studentsStream;
  Stream<List<Appointment>>? _agendaStream;
  String? _streamsUid;

  // Situação de cada aluno, recalculada quando a lista de alunos muda ou ao
  // puxar para atualizar.
  Future<Map<String, StudentActivity?>>? _activity;
  String _activityKey = '';

  String _query = '';
  StudentListFilter _filter = StudentListFilter.all;

  DateTime get _now => widget.clock?.call() ?? DateTime.now();

  void _ensureStreams(String uid) {
    if (_streamsUid == uid) return;
    _streamsUid = uid;
    _studentsStream = _db.watchStudents(uid);
    _agendaStream = _db.watchAppointmentsForInstructor(uid);
  }

  Future<Map<String, StudentActivity?>> _loadActivity(List<String> uids) async {
    final now = _now;
    final entries = await Future.wait(
      uids.map((uid) async {
        try {
          final workouts = await _db.watchWorkouts(uid).first;
          final plans = await _db.watchTrainingPlans(uid).first;
          return MapEntry<String, StudentActivity?>(
            uid,
            summarizeActivity(
              dates: [for (final w in workouts) w.date],
              hasPlan: plans.isNotEmpty,
              now: now,
            ),
          );
        } catch (_) {
          // Sem permissão ou sem conexão: o aluno aparece sem situação.
          return MapEntry<String, StudentActivity?>(uid, null);
        }
      }),
    );
    return Map.fromEntries(entries);
  }

  Future<Map<String, StudentActivity?>> _activityFor(List<String> uids) {
    final key = (uids.toList()..sort()).join(',');
    if (_activity == null || key != _activityKey) {
      _activityKey = key;
      _activity = _loadActivity(uids);
    }
    return _activity!;
  }

  Future<void> _refresh(List<String> uids) async {
    final next = _loadActivity(uids);
    setState(() => _activity = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    _ensureStreams(profile.uid);

    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Painel do personal'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _studentsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _Message(
              'Não foi possível carregar seus alunos. Verifique a conexão e '
              'tente novamente.',
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final students = snapshot.data!;
          final uids = [for (final s in students) s['uid'] as String];
          return FutureBuilder<Map<String, StudentActivity?>>(
            future: _activityFor(uids),
            builder: (context, activitySnap) => RefreshIndicator(
              onRefresh: () => _refresh(uids),
              child: _body(
                context,
                name: profile.name,
                code: profile.inviteCode ?? '',
                students: students,
                activity: activitySnap.data,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context, {
    required String name,
    required String code,
    required List<Map<String, dynamic>> students,
    required Map<String, StudentActivity?>? activity,
  }) {
    final now = _now;
    StudentActivity? activityOf(Map<String, dynamic> s) =>
        activity?[s['uid'] as String];
    final trainedThisWeek = activity?.values
        .where((a) => (a?.countThisWeek ?? 0) > 0)
        .length;
    final attention = activity == null
        ? null
        : students
              .where((s) => activityOf(s)?.needsAttentionAt(now) ?? false)
              .length;

    final q = _query.trim().toLowerCase();
    final visible =
        [
          for (final s in students)
            if ((q.isEmpty ||
                    (s['name'] as String? ?? '').toLowerCase().contains(q) ||
                    (s['email'] as String? ?? '').toLowerCase().contains(q)) &&
                switch (_filter) {
                  StudentListFilter.all => true,
                  StudentListFilter.attention =>
                    activityOf(s)?.needsAttentionAt(now) ?? false,
                  StudentListFilter.noPlan =>
                    activityOf(s)?.statusAt(now) == StudentStatus.noPlan,
                })
              s,
        ]..sort(
          (a, b) => _sortKey(
            activityOf(a),
            now,
          ).compareTo(_sortKey(activityOf(b), now)),
        );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        DashboardGreeting(name: name, now: now),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DashboardStatTile(
                key: const ValueKey('stat-students'),
                value: '${students.length}',
                label: students.length == 1 ? 'aluno' : 'alunos',
                icon: Icons.groups_outlined,
                onTap: () => setState(() => _filter = StudentListFilter.all),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DashboardStatTile(
                key: const ValueKey('stat-week'),
                value: trainedThisWeek == null ? '–' : '$trainedThisWeek',
                label: 'treinaram na semana',
                icon: Icons.fitness_center,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DashboardStatTile(
                key: const ValueKey('stat-attention'),
                value: attention == null ? '–' : '$attention',
                label: 'precisam de atenção',
                icon: Icons.priority_high,
                highlight: (attention ?? 0) > 0,
                onTap: () =>
                    setState(() => _filter = StudentListFilter.attention),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _TodayAgendaCard(stream: _agendaStream!, now: now),
        const DashboardSectionTitle('Atalhos'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DashboardQuickAction(
                icon: Icons.copy_all_outlined,
                label: 'Modelos de treino',
                onTap: () => context.push(AppRoutes.instructorTemplates),
              ),
            ),
            Expanded(
              child: DashboardQuickAction(
                icon: Icons.video_library_outlined,
                label: 'Meus exercícios',
                onTap: () => context.push(AppRoutes.instructorExercises),
              ),
            ),
            Expanded(
              child: DashboardQuickAction(
                icon: Icons.smart_toy_outlined,
                label: 'Assistente de IA',
                onTap: () => showAiSuggestionSheet(context),
              ),
            ),
            Expanded(
              child: DashboardQuickAction(
                icon: Icons.event_outlined,
                label: 'Agenda',
                onTap: () => context.go(AppRoutes.agenda),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ProfessionalInviteCard(
          code: code,
          shareText:
              'Sou seu personal no NewFitness. Instale o app, entre na sua '
              'conta e, no Perfil, use o meu código de convite: $code',
        ),
        DashboardSectionTitle(
          'Alunos',
          trailing: Text(
            '${visible.length} de ${students.length}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final (f, label) in const [
                (StudentListFilter.all, 'Todos'),
                (StudentListFilter.attention, 'Precisam de atenção'),
                (StudentListFilter.noPlan, 'Sem plano'),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: _filter == f,
                  onSelected: (_) => setState(() => _filter = f),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (students.isEmpty)
          const _EmptyStudents()
        else if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Nenhum aluno com esse filtro.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final s in visible)
            _StudentTile(
              student: s,
              activity: activityOf(s),
              loading: activity == null,
              now: now,
            ),
      ],
    );
  }

  /// Quem precisa de atenção primeiro; depois quem treinou há mais tempo.
  static int _sortKey(StudentActivity? a, DateTime now) {
    if (a == null) return 1 << 20;
    return switch (a.statusAt(now)) {
      StudentStatus.noPlan => 0,
      StudentStatus.inactive => 1,
      StudentStatus.neverTrained => 2,
      StudentStatus.active =>
        1000 - daysSince(a.lastActivity!, now).clamp(0, 999),
    };
  }
}

class _StudentTile extends StatelessWidget {
  const _StudentTile({
    required this.student,
    required this.activity,
    required this.loading,
    required this.now,
  });

  final Map<String, dynamic> student;
  final StudentActivity? activity;
  final bool loading;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final name = student['name'] as String? ?? '';
    final a = activity;
    final subtitle = loading
        ? 'Carregando...'
        : a == null
        ? (student['email'] as String? ?? '')
        : studentStatusLine(a, now);
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
        onTap: () => context.push(
          AppRoutes.instructorStudent,
          extra: StudentDetailArgs(
            uid: student['uid'] as String,
            name: name,
            notes: student['notes'] as String?,
          ),
        ),
      ),
    );
  }
}

class _TodayAgendaCard extends StatelessWidget {
  const _TodayAgendaCard({required this.stream, required this.now});

  final Stream<List<Appointment>> stream;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<List<Appointment>>(
      stream: stream,
      builder: (context, snapshot) {
        final today = [
          for (final a in snapshot.data ?? const <Appointment>[])
            if (a.status == AppointmentStatus.scheduled &&
                daysSince(a.start, now) == 0)
              a,
        ]..sort((a, b) => a.start.compareTo(b.start));
        String hhmm(DateTime d) =>
            '${d.hour.toString().padLeft(2, '0')}:'
            '${d.minute.toString().padLeft(2, '0')}';
        final text = snapshot.hasError
            ? 'Agenda indisponível agora.'
            : today.isEmpty
            ? 'Nada marcado para hoje.'
            : today.length == 1
            ? '1 compromisso: ${hhmm(today.first.start)} · '
                  '${today.first.studentName}'
            : '${today.length} compromissos · o primeiro às '
                  '${hhmm(today.first.start)}';
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            key: const ValueKey('today-agenda'),
            leading: Icon(Icons.event_available, color: scheme.primary),
            title: const Text('Agenda de hoje'),
            subtitle: Text(text),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(AppRoutes.agenda),
          ),
        );
      },
    );
  }
}

class _EmptyStudents extends StatelessWidget {
  const _EmptyStudents();

  @override
  Widget build(BuildContext context) {
    return Padding(
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
            'Nenhum aluno vinculado ainda.\nCompartilhe seu código de convite '
            'acima: o aluno digita no Perfil dele e aparece aqui.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ),
  );
}
