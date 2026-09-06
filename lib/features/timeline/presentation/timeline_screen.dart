import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/timeline/logic/timeline_provider.dart';
import 'package:newfitness/shared/models/announcement.dart';

/// Mural de avisos — qualquer usuário lê e curte; só o admin posta.
class TimelineScreen extends StatelessWidget {
  const TimelineScreen({super.key});

  void _openComposeSheet(BuildContext context, String authorName) {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Novo aviso',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bodyCtrl,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'Mensagem'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty ||
                    bodyCtrl.text.trim().isEmpty) {
                  return;
                }
                ctx.read<TimelineProvider>().createAnnouncement(
                  authorName: authorName,
                  title: titleCtrl.text.trim(),
                  body: bodyCtrl.text.trim(),
                );
                Navigator.pop(ctx);
              },
              child: const Text('Publicar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final timeline = context.watch<TimelineProvider>();
    final uid = auth.user?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Timeline')),
      body: StreamBuilder<List<Announcement>>(
        stream: timeline.watchAnnouncements(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final posts = snapshot.data ?? [];
          if (posts.isEmpty) {
            return const Center(child: Text('Nenhum aviso publicado ainda.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            itemBuilder: (context, i) {
              final post = posts[i];
              final liked = uid != null && post.likeUids.contains(uid);
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            child: Text(
                              post.authorName.isNotEmpty
                                  ? post.authorName[0].toUpperCase()
                                  : '?',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  post.authorName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  DateFormat('dd/MM/yyyy HH:mm')
                                      .format(post.createdAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        post.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(post.body),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              liked ? Icons.thumb_up : Icons.thumb_up_outlined,
                              color: liked
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                              size: 20,
                            ),
                            onPressed: uid == null
                                ? null
                                : () => timeline.toggleLike(post, uid),
                          ),
                          Text('${post.likeUids.length} curtida(s)'),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: auth.isAdmin
          ? FloatingActionButton.extended(
              onPressed: () =>
                  _openComposeSheet(context, auth.profile?.name ?? 'Admin'),
              icon: const Icon(Icons.add),
              label: const Text('Novo aviso'),
            )
          : null,
    );
  }
}
