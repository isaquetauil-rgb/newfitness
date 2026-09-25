import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/core/error/app_exception.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/professional/logic/professional_request_provider.dart';
import 'package:newfitness/features/professional/logic/professional_request_validation.dart';
import 'package:newfitness/shared/models/professional_request.dart';
import 'package:newfitness/shared/models/user_profile.dart';

String _kindLabel(UserRole kind) =>
    kind == UserRole.nutritionist ? 'nutricionista' : 'personal';

/// "Sou profissional": o aluno pede a aprovação para virar personal (CREF)
/// ou nutricionista (CRN) e acompanha o status (pendente, aprovado,
/// recusado com o motivo). O admin decide no painel. Sem notificação: o
/// status é lido ao abrir a tela.
class ProfessionalRequestScreen extends StatefulWidget {
  const ProfessionalRequestScreen({super.key});

  @override
  State<ProfessionalRequestScreen> createState() =>
      _ProfessionalRequestScreenState();
}

class _ProfessionalRequestScreenState extends State<ProfessionalRequestScreen> {
  Stream<ProfessionalRequest?>? _stream;
  String? _streamUid;
  bool _refreshedAfterApproval = false;

  Stream<ProfessionalRequest?> _streamFor(String uid) {
    if (_stream == null || _streamUid != uid) {
      _streamUid = uid;
      _stream = context.read<ProfessionalRequestProvider>().watchMine(uid);
    }
    return _stream!;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Sou profissional')),
      body: profile == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<ProfessionalRequest?>(
              stream: _streamFor(profile.uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const _Message(
                    'Não foi possível carregar o seu pedido. Tente de novo.',
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final request = snapshot.data;

                // Aprovado agora: recarrega o perfil (uma vez) para o papel
                // novo aparecer sem precisar sair da conta.
                if (request?.status == ProfessionalRequestStatus.approved &&
                    profile.role == UserRole.student &&
                    !_refreshedAfterApproval) {
                  _refreshedAfterApproval = true;
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => context.read<AuthProvider>().refreshProfile(),
                  );
                }

                if (profile.role != UserRole.student) {
                  return _Message(
                    'Você já é ${_kindLabel(profile.role)} aprovado(a) no '
                    'NewFitness.',
                    icon: Icons.verified_outlined,
                  );
                }
                if (request == null) {
                  return _RequestForm(profile: profile);
                }
                return _RequestStatus(request: request, profile: profile);
              },
            ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text, {this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 48, color: Colors.green),
              const SizedBox(height: 12),
            ],
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _RequestForm extends StatefulWidget {
  const _RequestForm({required this.profile});

  final UserProfile profile;

  @override
  State<_RequestForm> createState() => _RequestFormState();
}

class _RequestFormState extends State<_RequestForm> {
  UserRole _kind = UserRole.instructor;
  final _numberCtrl = TextEditingController();
  String? _region;
  String? _numberError;
  String? _regionError;
  bool _sending = false;

  @override
  void dispose() {
    _numberCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final numberError = validateRegistrationNumber(_numberCtrl.text);
    final regionError = validateRegistrationRegion(_kind, _region);
    setState(() {
      _numberError = numberError;
      _regionError = regionError;
    });
    if (numberError != null || regionError != null) return;

    final email = context.read<AuthProvider>().user?.email ?? '';
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      await context.read<ProfessionalRequestProvider>().submit(
        profile: widget.profile,
        accountEmail: email,
        kind: _kind,
        registrationNumber: _numberCtrl.text,
        registrationRegion: _region,
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Pedido enviado para análise.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is AppException
                ? e.message
                : 'Não foi possível enviar o pedido. Tente de novo.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNutritionist = _kind == UserRole.nutritionist;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Personal ou nutricionista? Envie seu registro profissional. O '
          'administrador confere no site do conselho e aprova ou recusa.',
        ),
        const SizedBox(height: 20),
        SegmentedButton<UserRole>(
          segments: const [
            ButtonSegment(
              value: UserRole.instructor,
              label: Text('Personal (CREF)'),
              icon: Icon(Icons.sports_gymnastics),
            ),
            ButtonSegment(
              value: UserRole.nutritionist,
              label: Text('Nutricionista (CRN)'),
              icon: Icon(Icons.restaurant_outlined),
            ),
          ],
          selected: {_kind},
          onSelectionChanged: _sending
              ? null
              : (s) => setState(() {
                  _kind = s.first;
                  _region = null;
                  _regionError = null;
                }),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _numberCtrl,
          enabled: !_sending,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: isNutritionist ? 'Número do CRN' : 'Número do CREF',
            hintText: isNutritionist ? 'ex: 12345' : 'ex: 123456-G',
            errorText: _numberError,
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey('region-$_kind'),
          initialValue: _region,
          decoration: InputDecoration(
            labelText: isNutritionist ? 'Região do CRN' : 'UF do CREF',
            errorText: _regionError,
          ),
          items: [
            for (final r in regionsFor(_kind))
              DropdownMenuItem(
                value: r,
                child: Text(isNutritionist ? 'CRN-$r' : r),
              ),
          ],
          onChanged: _sending ? null : (v) => setState(() => _region = v),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _sending ? null : _submit,
          child: _sending
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enviar pedido'),
        ),
      ],
    );
  }
}

class _RequestStatus extends StatefulWidget {
  const _RequestStatus({required this.request, required this.profile});

  final ProfessionalRequest request;
  final UserProfile profile;

  @override
  State<_RequestStatus> createState() => _RequestStatusState();
}

class _RequestStatusState extends State<_RequestStatus> {
  bool _busy = false;

  Future<void> _withdraw({required bool confirm}) async {
    if (confirm) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cancelar pedido?'),
          content: const Text('Você pode enviar um novo pedido depois.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Voltar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancelar pedido'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await context.read<ProfessionalRequestProvider>().withdraw(
        widget.profile.uid,
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Não foi possível. Tente de novo.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final date = r.createdAt == null
        ? ''
        : ' em ${DateFormat('dd/MM/yyyy').format(r.createdAt!)}';
    final (title, icon, color) = switch (r.status) {
      ProfessionalRequestStatus.pending => (
        'Pedido em análise',
        Icons.hourglass_top,
        Colors.orange,
      ),
      ProfessionalRequestStatus.rejected => (
        'Pedido recusado',
        Icons.cancel_outlined,
        Colors.red,
      ),
      ProfessionalRequestStatus.approved => (
        'Pedido aprovado',
        Icons.verified_outlined,
        Colors.green,
      ),
    };

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('${_kindLabel(r.kind)} · ${r.registrationLabel}$date'),
        if (r.status == ProfessionalRequestStatus.pending) ...[
          const SizedBox(height: 8),
          const Text('O administrador vai conferir seu registro.'),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: _busy ? null : () => _withdraw(confirm: true),
            child: const Text('Cancelar pedido'),
          ),
        ],
        if (r.status == ProfessionalRequestStatus.rejected) ...[
          const SizedBox(height: 12),
          Text(
            'Motivo: ${r.rejectionReason ?? '—'}',
            key: const ValueKey('rejection-reason'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _busy ? null : () => _withdraw(confirm: false),
            child: const Text('Fazer novo pedido'),
          ),
        ],
        // Aprovado, mas hoje é aluno (ex-profissional rebaixado): pode pedir
        // de novo. (Logo depois da aprovação o perfil é recarregado.)
        if (r.status == ProfessionalRequestStatus.approved) ...[
          const SizedBox(height: 12),
          const Text(
            'Seu pedido anterior foi aprovado, mas hoje sua conta é de '
            'aluno. Se precisar, faça um novo pedido.',
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _busy ? null : () => _withdraw(confirm: false),
            child: const Text('Fazer novo pedido'),
          ),
        ],
      ],
    );
  }
}
