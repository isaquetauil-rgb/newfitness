import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/features/auth/logic/auth_provider.dart';

/// Com quem é o vínculo gerenciado em [showManageLinkSheet].
enum LinkedProfessional { instructor, nutritionist }

/// Folha para o ALUNO trocar ou desfazer o próprio vínculo com o instrutor
/// ou a nutricionista. As duas ações passam pelas Cloud Functions
/// (`linkToProfessional`/`unlinkFromProfessional`) — o app nunca escreve
/// `instructorId`/`nutritionistId`. Nenhum dado do aluno é apagado; só o
/// acesso do profissional anterior deixa de existir.
Future<void> showManageLinkSheet(
  BuildContext context,
  LinkedProfessional kind,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ManageLinkSheet(kind: kind),
  );
}

class _ManageLinkSheet extends StatefulWidget {
  const _ManageLinkSheet({required this.kind});

  final LinkedProfessional kind;

  @override
  State<_ManageLinkSheet> createState() => _ManageLinkSheetState();
}

class _ManageLinkSheetState extends State<_ManageLinkSheet> {
  final _codeCtrl = TextEditingController();
  bool _busy = false;

  bool get _isInstructor => widget.kind == LinkedProfessional.instructor;
  String get _label => _isInstructor ? 'instrutor' : 'nutricionista';
  String get _theLabel => _isInstructor ? 'o instrutor' : 'a nutricionista';

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<bool> _confirm(String title, String message, String action) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _switch() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Informe o código do novo $_label.')),
      );
      return;
    }
    final ok = await _confirm(
      'Trocar de $_label?',
      'Ao confirmar, $_theLabel atual deixa de ter acesso aos seus dados e '
          'o novo passa a ter. Seu histórico (treinos, avaliações, fotos e '
          'conversas) continua salvo.',
      'Trocar',
    );
    if (!ok || !mounted) return;

    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    final name = _isInstructor
        ? await auth.linkToInstructor(code)
        : await auth.linkToNutritionist(code);
    if (!mounted) return;
    setState(() => _busy = false);
    if (name == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Código de $_label inválido.'),
        ),
      );
      return;
    }
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          name.isEmpty ? 'Vínculo atualizado.' : 'Agora vinculado a $name.',
        ),
      ),
    );
  }

  Future<void> _unlink() async {
    final ok = await _confirm(
      'Desvincular $_label?',
      '$_theLabel deixa de ter acesso aos seus dados. Seu histórico '
          '(treinos, avaliações, fotos e conversas) continua salvo, e você '
          'pode se vincular de novo depois com um código.',
      'Desvincular',
    );
    if (!ok || !mounted) return;

    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    final done = _isInstructor
        ? await auth.unlinkFromInstructor()
        : await auth.unlinkFromNutritionist();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!done) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            auth.errorMessage ?? 'Não foi possível desvincular. Tente de novo.',
          ),
        ),
      );
      return;
    }
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(content: Text('Você não está mais vinculado a $_theLabel.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isInstructor ? 'Seu instrutor' : 'Sua nutricionista',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Text(
              'Trocar de $_label',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeCtrl,
                    enabled: !_busy,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Código do novo $_label',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _busy ? null : _switch,
                  child: _busy
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Trocar'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _busy ? null : _unlink,
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              icon: const Icon(Icons.link_off),
              label: Text('Desvincular $_label'),
            ),
          ],
        ),
      ),
    );
  }
}
