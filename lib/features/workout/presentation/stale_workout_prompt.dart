import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/app/routes/app_routes.dart';
import 'package:newfitness/features/workout/logic/workout_provider.dart';
import 'package:newfitness/features/workout/presentation/workout_screen.dart';

/// O que o aluno escolheu no aviso de treino esquecido.
enum StaleWorkoutChoice { finish, resume, discard }

/// "hoje", "ontem" ou "quinta-feira, 12/11".
String staleDayLabel(DateTime start, DateTime now) {
  final day = DateTime(start.year, start.month, start.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'hoje';
  if (diff == 1) return 'ontem';
  return DateFormat("EEEE, d/MM", 'pt_BR').format(start);
}

/// Já perguntou nesta abertura do app? ("Continuar treinando" não pergunta
/// de novo até o app ser aberto outra vez.)
bool _askedThisRun = false;

/// Só para testes.
@visibleForTesting
void resetStaleWorkoutPrompt() => _askedThisRun = false;

/// Se o treino em andamento ficou mais de 3 horas sem nenhuma série marcada,
/// pergunta (uma vez por abertura do app) se o aluno esqueceu de finalizar.
/// Chamado pela tela inicial; não faz nada se não houver treino parado.
void scheduleStaleWorkoutCheck(BuildContext context) {
  if (_askedThisRun) return;
  final provider = context.read<WorkoutProvider>();
  if (!provider.hasStaleWorkout) return;
  _askedThisRun = true;
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    if (!context.mounted) return;
    await _ask(context, provider);
  });
}

Future<void> _ask(BuildContext context, WorkoutProvider provider) async {
  final start = provider.activeStartedAt;
  if (start == null) return;
  final hasSets = provider.activeHasCompletedSet;
  final day = staleDayLabel(start, DateTime.now());
  final choice = await showDialog<StaleWorkoutChoice>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.timer_off_outlined, size: 36),
      title: Text('Você esqueceu de finalizar o treino de $day?'),
      content: Text(
        hasSets
            ? 'Ele está aberto há mais de 3 horas sem nenhuma série marcada. '
                  'Se finalizar, o treino termina na hora da última série '
                  'feita, não agora.'
            : 'Ele está aberto há mais de 3 horas e nenhuma série foi '
                  'marcada como feita.',
      ),
      actionsAlignment: MainAxisAlignment.end,
      actionsOverflowDirection: VerticalDirection.up,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, StaleWorkoutChoice.discard),
          child: const Text('Descartar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, StaleWorkoutChoice.resume),
          child: const Text('Continuar treinando'),
        ),
        if (hasSets)
          FilledButton(
            onPressed: () => Navigator.pop(ctx, StaleWorkoutChoice.finish),
            child: const Text('Finalizar'),
          ),
      ],
    ),
  );
  if (!context.mounted || choice == null) return;
  switch (choice) {
    case StaleWorkoutChoice.finish:
      await finishActiveWorkout(context);
    case StaleWorkoutChoice.resume:
      context.go(AppRoutes.workout);
    case StaleWorkoutChoice.discard:
      provider.cancelWorkout();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Treino descartado.')));
  }
}
