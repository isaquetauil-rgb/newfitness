import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:newfitness/app/routes/app_routes.dart';
import 'package:newfitness/features/support/data/support_service.dart';
import 'package:newfitness/shared/models/support.dart';

/// Argumentos da conversa aberta pelo admin.
class SupportThreadArgs {
  const SupportThreadArgs({required this.uid, required this.name});

  final String uid;
  final String name;
}

/// Caixa de entrada do admin: conversas dos alunos, não lidas no topo.
class AdminSupportScreen extends StatefulWidget {
  const AdminSupportScreen({super.key, this.service});

  final SupportService? service;

  @override
  State<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends State<AdminSupportScreen> {
  late final Stream<List<SupportThread>> _threads =
      (widget.service ?? SupportService()).watchThreads();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mensagens dos alunos')),
      body: StreamBuilder<List<SupportThread>>(
        stream: _threads,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Não foi possível carregar as mensagens.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final threads = [...snapshot.data!]
            ..sort((a, b) {
              if (a.unreadByAdmin != b.unreadByAdmin) {
                return a.unreadByAdmin ? -1 : 1;
              }
              return b.lastMessageAt.compareTo(a.lastMessageAt);
            });
          if (threads.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Nenhum aluno escreveu ainda.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: threads.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final t = threads[i];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(t.name.isEmpty ? '?' : t.name[0].toUpperCase()),
                ),
                title: Text(
                  t.name,
                  style: TextStyle(
                    fontWeight: t.unreadByAdmin
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  '${t.lastFrom == SupportAuthor.admin ? 'Você: ' : ''}'
                  '${t.lastMessage}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      DateFormat('dd/MM').format(t.lastMessageAt),
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (t.unreadByAdmin)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Icon(
                          Icons.circle,
                          size: 10,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                  ],
                ),
                onTap: () => context.push(
                  AppRoutes.adminSupportThread,
                  extra: SupportThreadArgs(uid: t.uid, name: t.name),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
