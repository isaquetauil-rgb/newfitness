import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:newfitness/app/routes/app_routes.dart';
import 'package:newfitness/features/workout/data/health_screening_service.dart';
import 'package:newfitness/shared/models/health_screening.dart';

enum _BlockedChoice { redo, personal, support }

/// Libera (true) ou não (false) o aluno a começar sozinho um treino da área
/// de saúde. Usa a resposta mais recente se ainda valer; senão, mostra o
/// questionário e grava a resposta. Com algum "sim", mostra o aviso de
/// acompanhamento e oferece vincular personal ou falar com a equipe.
Future<bool> ensureHealthClearance(
  BuildContext context,
  String uid, {
  HealthScreeningService? service,
  DateTime Function() now = DateTime.now,
}) async {
  final svc = service ?? HealthScreeningService();
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.maybeOf(context);

  HealthScreening? current;
  try {
    current = await svc.latest(uid);
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Não foi possível verificar o questionário de saúde.'),
      ),
    );
    return false;
  }
  if (current != null && !current.isValidAt(now())) current = null;

  while (true) {
    if (!context.mounted) return false;
    if (current == null) {
      final answers = await showModalBottomSheet<List<bool>>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const HealthScreeningForm(),
      );
      if (answers == null) return false;
      final screening = HealthScreening(
        answers: answers,
        createdAt: now().millisecondsSinceEpoch,
      );
      try {
        await svc.save(uid, screening);
      } catch (_) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Não foi possível salvar suas respostas.'),
          ),
        );
        return false;
      }
      current = screening;
    }

    if (current.cleared) return true;
    if (!context.mounted) return false;

    final choice = await showModalBottomSheet<_BlockedChoice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => HealthBlockedView(screening: current!),
    );
    switch (choice) {
      case _BlockedChoice.redo:
        current = null;
      case _BlockedChoice.personal:
        router?.go(AppRoutes.profile);
        return false;
      case _BlockedChoice.support:
        router?.push(AppRoutes.support);
        return false;
      case null:
        return false;
    }
  }
}

/// As perguntas, com "Sim"/"Não" em cada uma. Devolve as respostas pelo
/// `Navigator.pop`.
class HealthScreeningForm extends StatefulWidget {
  const HealthScreeningForm({super.key});

  @override
  State<HealthScreeningForm> createState() => _HealthScreeningFormState();
}

class _HealthScreeningFormState extends State<HealthScreeningForm> {
  final List<bool?> _answers = List.filled(
    healthScreeningQuestions.length,
    null,
  );
  bool _declared = false;

  bool get _complete => !_answers.contains(null) && _declared;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          const Text(
            'Antes de começar',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Este treino é para quem precisa de mais cuidado. Responda com '
            'sinceridade: se algo aqui for verdade para você, o mais seguro é '
            'treinar com acompanhamento.',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < healthScreeningQuestions.length; i++) ...[
            Text('${i + 1}. ${healthScreeningQuestions[i]}'),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              key: ValueKey('health-q$i'),
              emptySelectionAllowed: true,
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('Não')),
                ButtonSegment(value: true, label: Text('Sim')),
              ],
              selected: {if (_answers[i] != null) _answers[i]!},
              onSelectionChanged: (value) => setState(
                () => _answers[i] = value.isEmpty ? null : value.first,
              ),
            ),
            const SizedBox(height: 16),
          ],
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _declared,
            onChanged: (v) => setState(() => _declared = v ?? false),
            title: const Text(
              'Declaro que as respostas são verdadeiras e que entendo que '
              'estes treinos são sugestões gerais, sem avaliação individual.',
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _complete
                ? () => Navigator.pop(context, [for (final a in _answers) a!])
                : null,
            child: const Text('Enviar respostas'),
          ),
        ],
      ),
    );
  }
}

/// Aviso mostrado quando o aluno respondeu "sim" a alguma pergunta.
class HealthBlockedView extends StatelessWidget {
  const HealthBlockedView({super.key, required this.screening});

  final HealthScreening screening;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Este treino precisa de acompanhamento',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Pelas suas respostas, não é seguro começar este treino sozinho. '
              'Um personal pode montar um treino para o seu caso. Se você '
              'ainda não tem um, fale com a nossa equipe.',
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 12),
            const Text(
              'Você respondeu "sim" para:',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            for (final q in screening.flaggedQuestions)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('• $q'),
              ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, _BlockedChoice.personal),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Vincular personal'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, _BlockedChoice.support),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Falar com a equipe'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context, _BlockedChoice.redo),
              child: const Text('Respondi errado, quero responder de novo'),
            ),
          ],
        ),
      ),
    );
  }
}
