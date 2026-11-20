import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/integrations/logic/health_sync.dart';
import 'package:newfitness/shared/utils/format.dart';

/// "Health Connect" no Android, "Apple Saúde" no iPhone.
String healthAppName() => defaultTargetPlatform == TargetPlatform.iOS
    ? 'Apple Saúde'
    : 'Health Connect';

/// Perfil > Integrações: ligar/desligar o Health Connect / Apple Saúde e
/// sincronizar o peso.
class IntegrationsScreen extends StatefulWidget {
  const IntegrationsScreen({super.key, this.sync});

  /// Para testes; por padrão, o do injetor.
  final HealthSync? sync;

  @override
  State<IntegrationsScreen> createState() => _IntegrationsScreenState();
}

class _IntegrationsScreenState extends State<IntegrationsScreen> {
  HealthSync? get _sync => widget.sync ?? healthSyncOrNull;
  bool _busy = false;
  WeightSample? _healthWeight;
  bool _weightRead = false;

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _toggle(bool on) async {
    final sync = _sync;
    if (sync == null) return;
    setState(() => _busy = true);
    try {
      if (!on) {
        await sync.disable();
        _healthWeight = null;
        _weightRead = false;
        return;
      }
      switch (await sync.enable()) {
        case HealthEnableResult.enabled:
          _snack('${healthAppName()} ligado.');
        case HealthEnableResult.denied:
          _snack(
            'Sem permissão. Libere o acesso do NewFitness no '
            '${healthAppName()} e tente de novo.',
          );
        case HealthEnableResult.unsupported:
          _snack('Este aparelho não tem suporte ao ${healthAppName()}.');
        case HealthEnableResult.needsInstall:
          if (!mounted) return;
          final install = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Instalar o Health Connect'),
              content: const Text(
                'Para enviar treinos e sincronizar o peso, este celular '
                'precisa do app Health Connect, do Google. Quer abrir a loja '
                'para instalar?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Agora não'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Abrir a loja'),
                ),
              ],
            ),
          );
          if (install == true) await sync.gateway.installProvider();
      }
    } catch (_) {
      _snack('Não foi possível ligar a integração.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _readWeight() async {
    setState(() => _busy = true);
    final sample = await _sync?.readLatestWeight();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _weightRead = true;
      _healthWeight = sample;
    });
  }

  Future<void> _useHealthWeight(double kg) async {
    final ok = await context.read<AuthProvider>().saveWeight(kg);
    _snack(ok ? 'Peso do perfil atualizado.' : 'Não foi possível salvar.');
  }

  Future<void> _sendProfileWeight(double kg) async {
    setState(() => _busy = true);
    final ok = await _sync?.pushWeight(kg) ?? false;
    if (!mounted) return;
    setState(() => _busy = false);
    _snack(
      ok
          ? 'Peso enviado para o ${healthAppName()}.'
          : 'Não foi possível enviar o peso.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final sync = _sync;
    final enabled = sync?.enabled ?? false;
    final profileKg = context.watch<AuthProvider>().profile?.weightKg;
    final scheme = Theme.of(context).colorScheme;
    final name = healthAppName();
    final health = _healthWeight;

    return Scaffold(
      appBar: AppBar(title: const Text('Integrações')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.favorite_outline),
              title: Text(name),
              subtitle: Text(
                'Envia os treinos que você finaliza e sincroniza o peso '
                'corporal. Vale só para este aparelho.',
              ),
              value: enabled,
              onChanged: sync == null || _busy ? null : _toggle,
            ),
          ),
          if (sync == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Integração indisponível neste aparelho.',
                style: TextStyle(color: scheme.outline),
              ),
            ),
          if (enabled) ...[
            const SizedBox(height: 20),
            const Text(
              'Peso corporal',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              profileKg == null
                  ? 'Seu perfil ainda não tem peso.'
                  : 'No seu perfil: ${formatKg(profileKg)}',
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _readWeight,
              icon: const Icon(Icons.download_outlined),
              label: Text('Ver peso no $name'),
            ),
            if (_weightRead && health == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Nenhum peso nos últimos 90 dias no $name.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            if (health != null) ...[
              const SizedBox(height: 8),
              Text(
                'No $name: ${formatKg(health.kg)} em '
                '${DateFormat('dd/MM/yyyy').format(health.at)}',
              ),
              if (weightDiffers(profileKg, health.kg))
                TextButton(
                  onPressed: () => _useHealthWeight(health.kg),
                  child: const Text('Usar este peso no meu perfil'),
                ),
            ],
            if (profileKg != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _sendProfileWeight(profileKg),
                icon: const Icon(Icons.upload_outlined),
                label: Text('Enviar ${formatKg(profileKg)} para o $name'),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Quando você muda o peso no perfil, ele também é enviado. '
              'Treinos importados de outros apps não são enviados.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
