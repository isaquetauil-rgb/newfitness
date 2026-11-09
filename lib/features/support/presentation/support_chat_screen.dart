import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/support/data/support_service.dart';
import 'package:newfitness/shared/models/support.dart';

/// Conversa do canal de apoio. Sem [studentUid], é o aluno logado falando
/// com a equipe; com ele, é o admin respondendo esse aluno.
class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({
    super.key,
    this.studentUid,
    this.studentName,
    this.service,
  });

  final String? studentUid;
  final String? studentName;
  final SupportService? service;

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  late final SupportService _service = widget.service ?? SupportService();
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  Stream<List<SupportMessage>>? _messages;
  StreamSubscription<SupportThread?>? _threadSub;
  bool _sending = false;

  bool get _asAdmin => widget.studentUid != null;

  String? get _uid =>
      widget.studentUid ?? context.read<AuthProvider>().user?.uid;

  SupportAuthor get _me =>
      _asAdmin ? SupportAuthor.admin : SupportAuthor.student;

  @override
  void initState() {
    super.initState();
    final uid = _uid;
    if (uid == null) return;
    _messages = _service.watchMessages(uid);
    // Abriu a conversa: o que chegou para quem está lendo passa a ser lido.
    _threadSub = _service.watchThread(uid).listen((thread) {
      if (thread == null) return;
      final unread = _asAdmin ? thread.unreadByAdmin : thread.unreadByStudent;
      if (unread) _service.markRead(uid, _me).ignore();
    });
  }

  @override
  void dispose() {
    _threadSub?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final uid = _uid;
    final text = _controller.text.trim();
    if (uid == null || text.isEmpty || _sending) return;
    final messenger = ScaffoldMessenger.of(context);
    final profileName = context.read<AuthProvider>().profile?.name;
    setState(() => _sending = true);
    try {
      await _service.send(
        studentUid: uid,
        studentName: _asAdmin
            ? (widget.studentName ?? 'Aluno')
            : (profileName?.trim().isNotEmpty == true ? profileName! : 'Aluno'),
        from: _me,
        text: text,
      );
      _controller.clear();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Não foi possível enviar. Verifique a conexão.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _asAdmin ? (widget.studentName ?? 'Aluno') : 'Fale com a equipe',
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<SupportMessage>>(
              stream: _messages,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Não foi possível carregar a conversa agora.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                final messages = snapshot.data ?? const <SupportMessage>[];
                if (messages.isEmpty) {
                  return _EmptyState(asAdmin: _asAdmin);
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scroll.hasClients) {
                    _scroll.jumpTo(_scroll.position.maxScrollExtent);
                  }
                });
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, i) => _Bubble(
                    message: messages[i],
                    mine: messages[i].from == _me,
                    colors: colors,
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: supportMessageMaxLength,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: _asAdmin
                            ? 'Escreva uma resposta'
                            : 'Conte como está indo',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                    tooltip: 'Enviar',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.asAdmin});

  final bool asAdmin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.volunteer_activism_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              asAdmin
                  ? 'Nenhuma mensagem ainda.'
                  : 'Conte como estão seus treinos, o que está difícil ou o '
                        'que você conquistou. A equipe do NewFitness responde '
                        'por aqui.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.colors,
  });

  final SupportMessage message;
  final bool mine;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: mine ? colors.primary : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine && message.from == SupportAuthor.admin)
              const Text(
                'Equipe NewFitness',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            Text(
              message.text,
              style: TextStyle(color: mine ? const Color(0xFF14171A) : null),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat('dd/MM HH:mm').format(message.createdAt),
              style: TextStyle(
                fontSize: 11,
                color: mine ? Colors.black54 : colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
