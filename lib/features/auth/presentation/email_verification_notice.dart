import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/features/auth/logic/auth_provider.dart';

/// Aviso de e-mail não verificado, com "Enviar e-mail de verificação" e
/// "Já verifiquei" (recarrega a conta e o token). Usado no Perfil, na tela
/// "Sou profissional" e nas telas de IA — as regras e as Functions exigem
/// `email_verified` no token para o pedido de profissional e para a IA.
class EmailVerificationNotice extends StatefulWidget {
  const EmailVerificationNotice({super.key, required this.reason});

  /// Início da frase explicando por que verificar (ex: "Para usar a IA").
  final String reason;

  @override
  State<EmailVerificationNotice> createState() =>
      _EmailVerificationNoticeState();
}

class _EmailVerificationNoticeState extends State<EmailVerificationNotice> {
  bool _busy = false;

  Future<void> _send() async {
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final ok = await auth.sendEmailVerification();
    if (mounted) setState(() => _busy = false);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'E-mail de verificação enviado para ${auth.user?.email ?? ''}.'
                : auth.errorMessage ??
                      'Não foi possível enviar o e-mail. Tente de novo.',
          ),
        ),
      );
  }

  Future<void> _check() async {
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final ok = await auth.reloadUser();
    if (mounted) setState(() => _busy = false);
    if (!ok) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              auth.errorMessage ?? 'Não foi possível conferir. Tente de novo.',
            ),
          ),
        );
    } else if (!auth.isEmailVerified) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Seu e-mail ainda não foi verificado. Abra o link que enviamos.',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = context.watch<AuthProvider>().user?.email ?? '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.mark_email_unread_outlined, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Verifique seu e-mail',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${widget.reason}, confirme primeiro o e-mail da sua conta '
              '($email). Enviamos um link; depois de abrir, toque em '
              '"Já verifiquei".',
              key: const ValueKey('verify-email-warning'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _busy ? null : _send,
              child: const Text('Enviar e-mail de verificação'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : _check,
              child: const Text('Já verifiquei'),
            ),
          ],
        ),
      ),
    );
  }
}
