import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/app/routes/app_routes.dart';
import 'package:newfitness/app/widgets/drawer_menu_button.dart';
import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/nutrition/presentation/nutrition_student_detail_screen.dart';
import 'package:newfitness/features/professional/logic/student_activity.dart';
import 'package:newfitness/features/professional/presentation/professional_dashboard_widgets.dart';
import 'package:newfitness/features/professional/presentation/professional_student_list.dart';
import 'package:newfitness/shared/services/firestore_service.dart';
import 'package:newfitness/app/widgets/effects.dart';

/// Painel da nutricionista: resumo dos alunos (quem registrou refeição na
/// semana, quem precisa de atenção), código de convite e a lista de alunos
/// com a situação de cada um. Alunos ficam na coleção isolada da
/// nutricionista (ver `FirestorePaths.nutritionStudents`).
class NutritionistDashboardScreen extends StatefulWidget {
  const NutritionistDashboardScreen({
    super.key,
    this.firestoreService,
    this.clock,
  });

  /// Para testes; no app vem do injetor.
  final FirestoreService? firestoreService;

  /// Para testes: "agora".
  final DateTime Function()? clock;

  @override
  State<NutritionistDashboardScreen> createState() =>
      _NutritionistDashboardScreenState();
}

class _NutritionistDashboardScreenState
    extends State<NutritionistDashboardScreen> {
  late final FirestoreService _db =
      widget.firestoreService ?? getIt<FirestoreService>();

  Stream<List<Map<String, dynamic>>>? _studentsStream;
  String? _streamUid;
  Future<Map<String, StudentActivity?>>? _activity;
  String _activityKey = '';
  String _query = '';
  StudentListFilter _filter = StudentListFilter.all;

  DateTime get _now => widget.clock?.call() ?? DateTime.now();

  Future<Map<String, StudentActivity?>> _loadActivity(List<String> uids) =>
      loadStudentsActivity(uids, (uid) async {
        final meals = await _db.watchMealPhotos(uid).first;
        final plans = await _db.watchNutritionPlans(uid).first;
        return ([for (final m in meals) m.date], plans.isNotEmpty);
      }, _now);

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

  static String _statusLine(StudentActivity a, DateTime now) =>
      studentStatusLine(
        a,
        now,
        verb: 'Registrou refeição',
        one: 'refeição',
        many: 'refeições',
        never: 'Ainda não registrou refeição',
      ).replaceFirst('sem plano', 'sem plano alimentar');

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_streamUid != profile.uid) {
      _streamUid = profile.uid;
      _studentsStream = _db.watchNutritionStudents(profile.uid);
    }

    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Painel da nutrição'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _studentsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Não foi possível carregar seus alunos. Verifique a '
                  'conexão e tente novamente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final students = snapshot.data!;
          final uids = [for (final s in students) s['uid'] as String];
          return FutureBuilder<Map<String, StudentActivity?>>(
            future: _activityFor(uids),
            builder: (context, activitySnap) {
              final activity = activitySnap.data;
              final now = _now;
              final week = activity?.values
                  .where((a) => (a?.countThisWeek ?? 0) > 0)
                  .length;
              final attention = activity == null
                  ? null
                  : students
                        .where(
                          (s) =>
                              activity[s['uid']]?.needsAttentionAt(now) ??
                              false,
                        )
                        .length;
              final noPlan = activity == null
                  ? null
                  : students
                        .where(
                          (s) =>
                              activity[s['uid']]?.statusAt(now) ==
                              StudentStatus.noPlan,
                        )
                        .length;
              final code = profile.inviteCode ?? '';
              return RefreshIndicator(
                onRefresh: () => _refresh(uids),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: staggered([
                    DashboardGreeting(name: profile.name, now: now),
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
                            onTap: () =>
                                setState(() => _filter = StudentListFilter.all),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DashboardStatTile(
                            key: const ValueKey('stat-week'),
                            value: week == null ? '–' : '$week',
                            label: 'registraram refeição na semana',
                            icon: Icons.restaurant_outlined,
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
                            onTap: () => setState(
                              () => _filter = StudentListFilter.attention,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if ((noPlan ?? 0) > 0) ...[
                      const SizedBox(height: 12),
                      Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          key: const ValueKey('no-plan-hint'),
                          leading: Icon(
                            Icons.assignment_late_outlined,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          title: Text(
                            noPlan == 1
                                ? '1 aluno sem plano alimentar'
                                : '$noPlan alunos sem plano alimentar',
                          ),
                          subtitle: const Text('Toque para ver quem são.'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => setState(
                            () => _filter = StudentListFilter.noPlan,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    ProfessionalInviteCard(
                      code: code,
                      shareText:
                          'Sou sua nutricionista no NewFitness. Instale o app, '
                          'entre na sua conta e, no Perfil, use o meu código '
                          'de convite: $code',
                    ),
                    ProfessionalStudentList(
                      students: students,
                      activity: activity,
                      now: now,
                      query: _query,
                      filter: _filter,
                      noPlanLabel: 'Sem plano alimentar',
                      onQueryChanged: (v) => setState(() => _query = v),
                      onFilterChanged: (f) => setState(() => _filter = f),
                      statusLine: _statusLine,
                      onOpen: (s) => context.push(
                        AppRoutes.nutritionistStudent,
                        extra: NutritionStudentDetailArgs(
                          uid: s['uid'] as String,
                          name: s['name'] as String? ?? '',
                        ),
                      ),
                    ),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
