import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/features/admin/logic/admin_provider.dart';
import 'package:newfitness/shared/models/user_profile.dart';

/// Lista de todos os usuários cadastrados, com busca e ação de
/// promover/rebaixar papel (aluno <-> instrutor).
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final adminProvider = context.watch<AdminProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Usuários')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar por nome ou e-mail...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<UserProfile>>(
              stream: adminProvider.watchAllUsers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final users = (snapshot.data ?? []).where((u) {
                  if (_query.isEmpty) return true;
                  return u.name.toLowerCase().contains(_query) ||
                      u.email.toLowerCase().contains(_query);
                }).toList();

                if (users.isEmpty) {
                  return const Center(child: Text('Nenhum usuário encontrado'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: users.length,
                  itemBuilder: (context, i) =>
                      _UserTile(user: users[i], adminProvider: adminProvider),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatefulWidget {
  const _UserTile({required this.user, required this.adminProvider});

  final UserProfile user;
  final AdminProvider adminProvider;

  @override
  State<_UserTile> createState() => _UserTileState();
}

class _UserTileState extends State<_UserTile> {
  bool _busy = false;

  Future<void> _toggleRole() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (widget.user.role == UserRole.instructor) {
        await widget.adminProvider.demoteToStudent(widget.user);
      } else {
        await widget.adminProvider.promoteToInstructor(widget.user);
      }
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Não foi possível alterar o papel.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isInstructor = widget.user.role == UserRole.instructor;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(
            widget.user.name.isNotEmpty
                ? widget.user.name[0].toUpperCase()
                : '?',
          ),
        ),
        title: Text(widget.user.name),
        subtitle: Text(
          '${widget.user.email} · ${isInstructor ? 'Instrutor' : 'Aluno'}',
        ),
        trailing: _busy
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: _toggleRole,
                child: Text(isInstructor ? 'Rebaixar' : 'Promover'),
              ),
      ),
    );
  }
}
