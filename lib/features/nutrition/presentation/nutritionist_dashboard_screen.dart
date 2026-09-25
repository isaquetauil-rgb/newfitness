import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/app/routes/app_routes.dart';
import 'package:newfitness/app/widgets/drawer_menu_button.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/nutrition/logic/nutrition_plan_provider.dart';
import 'package:newfitness/features/nutrition/presentation/nutrition_student_detail_screen.dart';

/// Painel da nutricionista — lista os alunos vinculados a ela (coleção
/// isolada de `students`, ver `FirestorePaths.nutritionStudents`). Mesmo
/// papel que `InstructorDashboardScreen` cumpre pro instrutor.
class NutritionistDashboardScreen extends StatelessWidget {
  const NutritionistDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    final provider = context.watch<NutritionPlanProvider>();

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Meus alunos'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _InviteCodeCard(code: profile.inviteCode ?? '—'),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: provider.watchStudents(profile.uid),
              builder: (context, snapshot) {
                final students = snapshot.data ?? [];
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (students.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Nenhum aluno vinculado ainda.\nCompartilhe seu '
                        'código de convite para começar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: students.length,
                  itemBuilder: (context, i) {
                    final student = students[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            (student['name'] as String? ?? '?').isNotEmpty
                                ? (student['name'] as String)[0].toUpperCase()
                                : '?',
                          ),
                        ),
                        title: Text(student['name'] as String? ?? ''),
                        subtitle: Text(student['email'] as String? ?? ''),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(
                          AppRoutes.nutritionistStudent,
                          extra: NutritionStudentDetailArgs(
                            uid: student['uid'] as String,
                            name: student['name'] as String? ?? '',
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteCodeCard extends StatelessWidget {
  const _InviteCodeCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.qr_code, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seu código de convite',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  Text(
                    code,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy_outlined),
              tooltip: 'Copiar',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Código copiado')));
              },
            ),
          ],
        ),
      ),
    );
  }
}
