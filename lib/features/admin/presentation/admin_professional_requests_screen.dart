import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/core/error/app_exception.dart';
import 'package:newfitness/features/professional/logic/professional_request_provider.dart';
import 'package:newfitness/features/professional/logic/professional_request_validation.dart';
import 'package:newfitness/shared/models/professional_request.dart';
import 'package:newfitness/shared/models/user_profile.dart';

/// Painel admin: pedidos pendentes de personal (CREF) e nutricionista
/// (CRN). O admin confere o registro no site do conselho e aprova (o papel
/// muda na hora, pela Cloud Function) ou recusa com motivo obrigatório.
class AdminProfessionalRequestsScreen extends StatefulWidget {
  const AdminProfessionalRequestsScreen({super.key});

  @override
  State<AdminProfessionalRequestsScreen> createState() =>
      _AdminProfessionalRequestsScreenState();
}

class _AdminProfessionalRequestsScreenState
    extends State<AdminProfessionalRequestsScreen> {
  late final Stream<List<ProfessionalRequest>> _stream = context
      .read<ProfessionalRequestProvider>()
      .watchPending();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pedidos de profissional')),
      body: StreamBuilder<List<ProfessionalRequest>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Não foi possível carregar os pedidos.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final requests = snapshot.data ?? const [];
          if (requests.isEmpty) {
            return const Center(child: Text('Nenhum pedido pendente.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final r in requests)
                _RequestTile(key: ValueKey(r.uid), request: r),
            ],
          );
        },
      ),
    );
  }
}

class _RequestTile extends StatefulWidget {
  const _RequestTile({super.key, required this.request});

  final ProfessionalRequest request;

  @override
  State<_RequestTile> createState() => _RequestTileState();
}

class _RequestTileState extends State<_RequestTile> {
  bool _busy = false;

  String _errorText(Object e) => e is AppException
      ? e.message
      : 'Não foi possível concluir. Tente de novo.';

  Future<void> _approve() async {
    final r = widget.request;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Aprovar ${r.name}?'),
        content: Text(
          '${r.registrationLabel}\n\nConfira o registro no site do conselho '
          'antes de aprovar. A conta passa a ser de '
          '${r.kind == UserRole.nutritionist ? 'nutricionista' : 'personal'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Aprovar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(
      () => context.read<ProfessionalRequestProvider>().approve(r.uid),
      success: '${r.name} aprovado(a).',
    );
  }

  Future<void> _reject() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _RejectDialog(),
    );
    if (reason == null || !mounted) return;
    await _run(
      () => context.read<ProfessionalRequestProvider>().reject(
        widget.request.uid,
        reason,
      ),
      success: 'Pedido de ${widget.request.name} recusado.',
    );
  }

  Future<void> _run(
    Future<void> Function() action, {
    required String success,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(success)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_errorText(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final date = r.createdAt == null
        ? ''
        : DateFormat('dd/MM/yyyy HH:mm').format(r.createdAt!);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              r.name.isEmpty ? '(sem nome)' : r.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(r.email),
            const SizedBox(height: 4),
            Text(
              '${r.kind == UserRole.nutritionist ? 'Nutricionista' : 'Personal'}'
              ' · ${r.registrationLabel}',
            ),
            if (date.isNotEmpty)
              Text(
                'Pedido em $date',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            const SizedBox(height: 8),
            if (_busy)
              const LinearProgressIndicator()
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: _reject, child: const Text('Recusar')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _approve,
                    child: const Text('Aprovar'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Pede o motivo da recusa (obrigatório, 1 a 500 caracteres).
class _RejectDialog extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final error = validateRejectionReason(_ctrl.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, _ctrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Recusar pedido'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        maxLines: 3,
        maxLength: 500,
        decoration: InputDecoration(
          labelText: 'Motivo (o solicitante verá)',
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(onPressed: _confirm, child: const Text('Recusar')),
      ],
    );
  }
}
