import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/app/routes/app_router.dart';
import 'package:newfitness/app/routes/app_routes.dart';
import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/instructor/presentation/ai_suggestion_sheet.dart';
import 'package:newfitness/shared/services/firestore_service.dart';

class InstructorDashboardScreen extends StatelessWidget {
  const InstructorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    final firestoreService = getIt<FirestoreService>();

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus alunos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.smart_toy_outlined),
            tooltip: 'Assistente de IA',
            onPressed: () => showAiSuggestionSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _InviteCodeCard(code: profile.inviteCode ?? '—'),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: firestoreService.watchStudents(profile.uid),
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
                        'Nenhum aluno vinculado ainda.\nCompartilhe seu código '
                        'de convite para começar.',
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
                          AppRoutes.instructorStudent,
                          extra: StudentDetailArgs(
                            uid: student['uid'] as String,
                            name: student['name'] as String? ?? '',
                            notes: student['notes'] as String?,
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
  final String code;

  const _InviteCodeCard({required this.code});

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
