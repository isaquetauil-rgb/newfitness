import 'package:flutter/material.dart';

/// Caixa "Renomear": devolve o nome novo (sem espaços nas pontas) ou `null`
/// se a pessoa cancelar, deixar vazio ou não mudar nada.
Future<String?> showRenameDialog(
  BuildContext context, {
  required String title,
  required String initial,
  String label = 'Nome',
}) async {
  final result = await showDialog<String>(
    context: context,
    builder: (_) => _RenameDialog(title: title, initial: initial, label: label),
  );
  final clean = result?.trim() ?? '';
  if (clean.isEmpty || clean == initial.trim()) return null;
  return clean;
}

/// O campo de texto vive no estado do diálogo: assim o controlador só é
/// descartado quando o diálogo some de vez (depois da animação de fechar).
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({
    required this.title,
    required this.initial,
    required this.label,
  });

  final String title;
  final String initial;
  final String label;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _ctrl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const ValueKey('rename-field'),
        controller: _ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: widget.label),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          key: const ValueKey('rename-save'),
          onPressed: () => Navigator.pop(context, _ctrl.text),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
