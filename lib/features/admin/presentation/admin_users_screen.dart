import 'package:flutter/material.dart';
import 'package:newfitness/core/error/app_exception.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/features/admin/logic/admin_provider.dart';
import 'package:newfitness/features/finance/logic/finance_provider.dart';
import 'package:newfitness/shared/models/subscription.dart';
import 'package:newfitness/shared/models/user_profile.dart';

/// Lista de todos os usuários cadastrados, com busca, ação de
/// promover/rebaixar papel (aluno <-> instrutor) e, para alunos, o plano de
/// IA (Básico/Premium — só o admin define).
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

  Future<void> _setRole(UserRole role) async {
    if (role == widget.user.role) return;
    final messenger = ScaffoldMessenger.of(context);
    final leavingInstructor =
        widget.user.role == UserRole.instructor && role != UserRole.instructor;
    if (leavingInstructor) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Mudar ${widget.user.name} para ${_roleLabel(role)}?'),
          content: const Text(
            'Todos os alunos vinculados a este instrutor serão desvinculados '
            'e ele perde o acesso aos dados deles. O histórico dos alunos '
            'é preservado. Voltar a ser instrutor não restaura os vínculos.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      final revoked = await widget.adminProvider.setRole(widget.user, role);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${widget.user.name} agora é ${_roleLabel(role)}'
            '${revoked > 0 ? ' · $revoked aluno(s) desvinculado(s)' : ''}.',
          ),
        ),
      );
    } catch (e) {
      // Mensagem real da Function (ex: "O papel NÃO foi alterado — tente
      // de novo"); a lista não muda, porque o papel não mudou.
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is AppException
                ? e.message
                : 'Não foi possível alterar o papel. Tente de novo.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setPlanTier(PlanTier tier) async {
    final messenger = ScaffoldMessenger.of(context);
    final label = tier == PlanTier.premium ? 'Premium' : 'Básico';
    setState(() => _busy = true);
    try {
      await context.read<FinanceProvider>().setStudentPlanTier(
        widget.user.uid,
        tier,
      );
      messenger.showSnackBar(
        SnackBar(content: Text('Plano de IA de ${widget.user.name}: $label.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is AppException
                ? e.message
                : 'Não foi possível alterar o plano. Tente de novo.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.instructor:
        return 'Instrutor';
      case UserRole.nutritionist:
        return 'Nutricionista';
      case UserRole.student:
        return 'Aluno';
    }
  }

  @override
  Widget build(BuildContext context) {
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
          '${widget.user.email} · ${_roleLabel(widget.user.role)}',
        ),
        trailing: _busy
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : PopupMenuButton<Object>(
                onSelected: (value) {
                  if (value is UserRole) _setRole(value);
                  if (value is PlanTier) _setPlanTier(value);
                },
                itemBuilder: (context) => [
                  for (final role in UserRole.values)
                    PopupMenuItem<Object>(
                      value: role,
                      child: Text(_roleLabel(role)),
                    ),
                  if (widget.user.role == UserRole.student) ...[
                    const PopupMenuDivider(),
                    for (final tier in PlanTier.values)
                      PopupMenuItem<Object>(
                        value: tier,
                        child: Text(
                          'Plano de IA: '
                          '${tier == PlanTier.premium ? 'Premium' : 'Básico'}',
                        ),
                      ),
                  ],
                ],
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.more_vert),
                ),
              ),
      ),
    );
  }
}
