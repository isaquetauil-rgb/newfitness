import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/features/ai/logic/chat_provider.dart'
    show maxAiMessageLength;
import 'package:newfitness/features/ai/presentation/ai_disclaimer.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/auth/presentation/email_verification_notice.dart';
import 'package:newfitness/features/nutrition/logic/nutrition_chat_provider.dart';
import 'package:newfitness/shared/models/nutrition_message.dart';

/// Conversa de nutrição de um aluno — reaproveitada em dois lugares:
/// [isNutritionistView] = false (o próprio aluno, pode perguntar à IA) e
/// = true (a nutricionista vinculada, só pode corrigir/validar, não
/// pergunta como se fosse o aluno).
class NutritionChatView extends StatefulWidget {
  const NutritionChatView({
    super.key,
    required this.studentUid,
    required this.isNutritionistView,
  });

  final String studentUid;
  final bool isNutritionistView;

  @override
  State<NutritionChatView> createState() => _NutritionChatViewState();
}

class _NutritionChatViewState extends State<NutritionChatView> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _ask() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    context.read<NutritionChatProvider>().ask(widget.studentUid, text);
    _scrollToEnd();
  }

  void _correct() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    final profile = context.read<AuthProvider>().profile;
    _controller.clear();
    context.read<NutritionChatProvider>().addCorrection(
      widget.studentUid,
      text,
      profile?.name ?? 'Nutricionista',
    );
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NutritionChatProvider>();
    // A nutricionista não chama a IA (só corrige); o aluno precisa do
    // e-mail verificado para perguntar.
    final needsVerification =
        !widget.isNutritionistView &&
        !context.watch<AuthProvider>().isEmailVerified;

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<NutritionMessage>>(
            stream: provider.watchMessages(widget.studentUid),
            builder: (context, snapshot) {
              final messages = snapshot.data ?? [];
              if (messages.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      widget.isNutritionistView
                          ? 'O aluno ainda não fez nenhuma pergunta.'
                          : 'Pergunte sobre alimentação, hábitos ou '
                                'suplementação. Sua nutricionista pode ver e '
                                'corrigir as respostas da IA.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                );
              }
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, i) =>
                    _NutritionBubble(message: messages[i]),
              );
            },
          ),
        ),
        if (provider.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              provider.error!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        if (!widget.isNutritionistView) const AiDisclaimer(),
        if (needsVerification)
          const SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: EmailVerificationNotice(reason: 'Para usar a IA'),
            ),
          )
        else
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLength: widget.isNutritionistView
                          ? null
                          : maxAiMessageLength,
                      decoration: InputDecoration(
                        hintText: widget.isNutritionistView
                            ? 'Corrigir ou validar...'
                            : 'Escreva sua pergunta...',
                        counterText: '',
                      ),
                      minLines: 1,
                      maxLines: 4,
                      onSubmitted: (_) =>
                          widget.isNutritionistView ? _correct() : _ask(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: provider.isSending
                        ? null
                        : () => widget.isNutritionistView ? _correct() : _ask(),
                    icon: provider.isSending
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _NutritionBubble extends StatelessWidget {
  const _NutritionBubble({required this.message});

  final NutritionMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == NutritionRole.user;
    final isNutritionist = message.role == NutritionRole.nutritionist;

    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final color = isUser
        ? Theme.of(context).colorScheme.primary
        : isNutritionist
        ? Colors.amber.shade100
        : Colors.grey.shade100;
    final textColor = isUser ? Colors.white : Colors.black87;

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isNutritionist)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${message.authorName ?? 'Nutricionista'} corrigiu:',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Text(message.content, style: TextStyle(color: textColor)),
          ],
        ),
      ),
    );
  }
}
