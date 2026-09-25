import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/instructor/logic/plan_template_provider.dart';
import 'package:newfitness/shared/models/plan_template.dart';

/// Lista dos modelos de plano salvos pelo instrutor — só gerenciamento
/// (renomear/apagar). Escolher um modelo pra usar num plano novo acontece
/// direto em [PlanEditorScreen], via o botão "Usar modelo".
class PlanTemplatesScreen extends StatelessWidget {
  const PlanTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final instructorUid = context.watch<AuthProvider>().profile?.uid;
    final provider = context.watch<PlanTemplateProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Modelos de treino')),
      body: instructorUid == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<PlanTemplate>>(
              stream: provider.watchTemplates(instructorUid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final templates = snapshot.data ?? [];
                if (templates.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Nenhum modelo salvo ainda.\nAo montar um plano, use '
                        '"Salvar como modelo" para reaproveitá-lo depois.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  itemCount: templates.length,
                  itemBuilder: (context, i) {
                    final template = templates[i];
                    final exerciseCount = template.workouts.fold<int>(
                      0,
                      (sum, w) => sum + w.exercises.length,
                    );
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.fitness_center),
                        title: Text(template.title),
                        subtitle: Text(
                          '${template.workouts.length} treino(s) · '
                          '$exerciseCount exercício(s)',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Apagar modelo',
                          onPressed: () => _confirmDelete(
                            context,
                            provider,
                            instructorUid,
                            template,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    PlanTemplateProvider provider,
    String instructorUid,
    PlanTemplate template,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar modelo?'),
        content: Text('"${template.title}" será removido definitivamente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              provider.deleteTemplate(instructorUid, template.id);
              Navigator.pop(ctx);
            },
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
  }
}
