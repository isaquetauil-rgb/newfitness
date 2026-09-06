import 'package:flutter/material.dart';

/// Fallback usado por [ErrorWidget.builder] quando um widget quebra durante
/// o build. Usa [Material] em vez de depender de um [Theme] ancestral,
/// porque o erro pode acontecer antes da árvore de tema estar disponível.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.red.shade50,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 32),
              const SizedBox(height: 8),
              Text(
                message ?? 'Algo deu errado.',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
