import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/features/instructor/logic/instructor_ai_provider.dart';

/// Bottom sheet do assistente de IA para instrutores — reutilizado em dois
/// contextos:
///  - Geral (a partir do dashboard): [studentName] é null, cobre pedidos
///    tipo "me dê mais ideias de treino de braço".
///  - Por aluno (a partir do detalhe do aluno): [studentName] e
///    [initialContext] (a nota salva sobre o aluno, se houver) vêm
///    preenchidos, cobrindo o caso "Dona Maria está com dor nas costas".
///
/// Quando aberto com [studentName], mostra um botão extra para levar a
/// sugestão direto para o editor de plano daquele aluno.
Future<void> showAiSuggestionSheet(
  BuildContext context, {
  String? studentName,
  String? initialContext,
  void Function(String suggestion)? onCreatePlan,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => AiSuggestionSheet(
      studentName: studentName,
      initialContext: initialContext,
      onCreatePlan: onCreatePlan,
    ),
  );
}

class AiSuggestionSheet extends StatefulWidget {
  const AiSuggestionSheet({
    super.key,
    this.studentName,
    this.initialContext,
    this.onCreatePlan,
  });

  final String? studentName;
  final String? initialContext;
  final void Function(String suggestion)? onCreatePlan;

  @override
  State<AiSuggestionSheet> createState() => _AiSuggestionSheetState();
}

class _AiSuggestionSheetState extends State<AiSuggestionSheet> {
  late final _controller = TextEditingController(
    text: widget.initialContext ?? '',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InstructorAiProvider>().reset();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    await context.read<InstructorAiProvider>().ask(
      prompt: _controller.text,
      studentName: widget.studentName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<InstructorAiProvider>();
    final isForStudent = widget.studentName != null;

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
            Row(
              children: [
                const Icon(Icons.smart_toy_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isForStudent
                        ? 'Sugestão de IA para ${widget.studentName}'
                        : 'Assistente de IA',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: isForStudent
                    ? 'Ex: dor nas costas, quer focar em pernas, iniciante...'
                    : 'Ex: me dê mais ideias de treino de braço',
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: ai.isLoading ? null : _ask,
              icon: ai.isLoading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send),
              label: const Text('Perguntar à IA'),
            ),
            if (ai.error != null) ...[
              const SizedBox(height: 12),
              Text(ai.error!, style: const TextStyle(color: Colors.red)),
            ],
            if (ai.suggestion != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(ai.suggestion!),
              ),
              if (isForStudent && widget.onCreatePlan != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onCreatePlan!(ai.suggestion!);
                  },
                  icon: const Icon(Icons.assignment_add),
                  label: const Text('Criar plano com esta sugestão'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
