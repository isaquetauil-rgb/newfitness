import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/shared/models/parq.dart';

/// Pode começar um treino livre? Confere, nesta ordem:
/// 1. se o personal vinculado desativou o treino livre (avisa e não deixa);
/// 2. se o aviso de responsabilidade já foi aceito; senão mostra uma vez e
///    grava o aceite com a data.
Future<bool> ensureFreeWorkoutAllowed(BuildContext context) async {
  final auth = context.read<AuthProvider>();
  final profile = auth.profile;
  if (profile == null) return true;

  if (profile.freeWorkoutBlocked) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.lock_outline),
        title: const Text('Treino livre desativado'),
        content: const Text(
          'Seu personal desativou o treino livre para você. Siga o plano '
          'dele ou os treinos prontos, ou fale com ele para liberar.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
    return false;
  }

  if (profile.freeWorkoutTermsAcceptedAt != null) return true;
  if (!context.mounted) return false;

  final accepted = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.info_outline),
      title: const Text('Antes do treino livre'),
      content: const SingleChildScrollView(child: Text(freeWorkoutTerms)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Agora não'),
        ),
        FilledButton(
          key: const ValueKey('accept-free-workout-terms'),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Li e aceito'),
        ),
      ],
    ),
  );
  if (accepted != true) return false;
  final saved = await auth.acceptFreeWorkoutTerms();
  if (!saved && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não foi possível salvar. Tente de novo.')),
    );
  }
  return saved;
}
