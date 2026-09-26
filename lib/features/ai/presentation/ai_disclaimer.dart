import 'package:flutter/material.dart';

/// Aviso fixo das telas de conversa com a IA (chat geral e nutrição).
class AiDisclaimer extends StatelessWidget {
  const AiDisclaimer({super.key});

  static const text = 'Orientação geral por IA. Não substitui um profissional.';

  @override
  Widget build(BuildContext context) {
    final color = Colors.grey.shade600;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12, color: color)),
          ),
        ],
      ),
    );
  }
}
