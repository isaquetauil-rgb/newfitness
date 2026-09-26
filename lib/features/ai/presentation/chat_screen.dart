import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/features/ai/logic/chat_provider.dart';
import 'package:newfitness/features/ai/presentation/ai_disclaimer.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/auth/presentation/email_verification_notice.dart';
import 'package:newfitness/shared/models/chat_message.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send(String uid) {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    context.read<ChatProvider>().sendMessage(uid, text);
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final uid = auth.user?.uid;
    final chatProvider = context.watch<ChatProvider>();

    if (uid == null) {
      return const Center(child: Text('Faça login para conversar com a IA'));
    }

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: chatProvider.watchMessages(uid),
            builder: (context, snapshot) {
              final messages = snapshot.data ?? [];

              if (messages.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Pergunte sobre treino, dieta, suplementação ou hábitos '
                      'saudáveis. A IA não substitui orientação médica ou de '
                      'um nutricionista.',
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
                itemBuilder: (context, i) => _ChatBubble(message: messages[i]),
              );
            },
          ),
        ),
        if (chatProvider.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              chatProvider.error!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        const AiDisclaimer(),
        if (!auth.isEmailVerified)
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
                      maxLength: maxAiMessageLength,
                      decoration: const InputDecoration(
                        hintText: 'Escreva sua pergunta...',
                        counterText: '',
                      ),
                      onSubmitted: (_) => _send(uid),
                      minLines: 1,
                      maxLines: 4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: chatProvider.isSending ? null : () => _send(uid),
                    icon: chatProvider.isSending
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

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).colorScheme.primary
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message.content,
          style: TextStyle(color: isUser ? Colors.white : Colors.black87),
        ),
      ),
    );
  }
}
