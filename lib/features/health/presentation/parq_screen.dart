import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/app/routes/app_routes.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/shared/models/parq.dart';

/// PAR-Q do onboarding do aluno: 7 perguntas de "sim" ou "não". Com algum
/// "sim", recomenda liberação médica antes de treinar, sem bloquear nada.
class ParqScreen extends StatefulWidget {
  const ParqScreen({super.key});

  @override
  State<ParqScreen> createState() => _ParqScreenState();
}

class _ParqScreenState extends State<ParqScreen> {
  late final List<bool?> _answers = List.filled(parqQuestions.length, null);
  bool _saving = false;

  bool get _complete => !_answers.contains(null);

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final answers = [for (final a in _answers) a!];
    final ok = await context.read<AuthProvider>().saveParq(answers);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível salvar. Tente de novo.'),
        ),
      );
      return;
    }
    if (answers.contains(true)) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.medical_services_outlined),
          title: const Text('Converse com um médico antes'),
          content: const Text(
            'Pelas suas respostas, o recomendado é ter a liberação de um '
            'médico antes de começar a treinar e, se possível, treinar com '
            'acompanhamento de um profissional de Educação Física. Você pode '
            'usar o app normalmente; seu personal, se tiver um, verá estas '
            'respostas.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendi'),
            ),
          ],
        ),
      );
    }
    if (mounted) _leave();
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: const Text('Antes de treinar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Responda com sinceridade estas 7 perguntas de saúde (PAR-Q). '
            'Elas ajudam a saber se é seguro começar a treinar sem uma '
            'avaliação médica.',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < parqQuestions.length; i++) ...[
            Text('${i + 1}. ${parqQuestions[i]}'),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              key: ValueKey('parq-q$i'),
              emptySelectionAllowed: true,
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('Não')),
                ButtonSegment(value: true, label: Text('Sim')),
              ],
              selected: {if (_answers[i] != null) _answers[i]!},
              onSelectionChanged: (v) =>
                  setState(() => _answers[i] = v.isEmpty ? null : v.first),
            ),
            const SizedBox(height: 16),
          ],
          FilledButton(
            key: const ValueKey('parq-submit'),
            onPressed: _complete && !_saving ? _submit : null,
            child: Text(_saving ? 'Salvando...' : 'Enviar respostas'),
          ),
          TextButton(onPressed: _leave, child: const Text('Responder depois')),
        ],
      ),
    );
  }
}
