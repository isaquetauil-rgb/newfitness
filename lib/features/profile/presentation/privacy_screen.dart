import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:newfitness/core/error/app_exception.dart';
import 'package:newfitness/core/network/functions_client.dart';

/// Resultado da Cloud Function `exportMyData`.
class DataExport {
  const DataExport({
    required this.jsonUrl,
    required this.csvUrl,
    required this.expiresAt,
    required this.workouts,
  });

  factory DataExport.fromMap(Map<String, dynamic> map) => DataExport(
    jsonUrl: map['jsonUrl'] as String? ?? '',
    csvUrl: map['csvUrl'] as String? ?? '',
    expiresAt: DateTime.fromMillisecondsSinceEpoch(
      (map['expiresAt'] as num?)?.toInt() ?? 0,
    ),
    workouts: (map['workouts'] as num?)?.toInt() ?? 0,
  );

  final String jsonUrl;
  final String csvUrl;
  final DateTime expiresAt;
  final int workouts;
}

typedef DataExporter = Future<DataExport> Function();

Future<DataExport> _callExportFunction() async => DataExport.fromMap(
  await FunctionsClient().call(
    'exportMyData',
    const {},
    timeout: const Duration(minutes: 5),
  ),
);

/// Perfil > Privacidade: "Exportar meus dados" (uma vez por dia; links
/// valem 1 hora).
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key, this.exporter, this.openUrl});

  /// Para testes: troca a chamada da Cloud Function.
  final DataExporter? exporter;

  /// Para testes: troca a abertura do link.
  final Future<bool> Function(Uri)? openUrl;

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool _loading = false;
  DataExport? _result;
  String? _error;

  Future<void> _export() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await (widget.exporter ?? _callExportFunction)();
      if (!mounted) return;
      setState(() => _result = result);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível exportar. Tente de novo.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    final ok =
        uri != null &&
        await (widget.openUrl ??
            (u) => launchUrl(u, mode: LaunchMode.externalApplication))(uri);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Privacidade')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Exportar meus dados',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Gera uma cópia dos seus dados: perfil (com o questionário de '
            'saúde e os aceites), treinos e recordes, avaliações físicas, '
            'refeições, planos de treino e de nutrição e os links das suas '
            'fotos.',
          ),
          const SizedBox(height: 8),
          Text(
            'Você recebe dois arquivos: um completo (JSON) e uma planilha dos '
            'treinos (CSV, uma linha por série). Os links valem 1 hora. Dá '
            'para exportar uma vez por dia.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          if (result == null)
            FilledButton.icon(
              onPressed: _loading ? null : _export,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              label: Text(_loading ? 'Preparando...' : 'Exportar meus dados'),
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: scheme.error)),
          ],
          if (result != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Seus dados estão prontos',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${result.workouts} '
                      '${result.workouts == 1 ? 'treino' : 'treinos'} · '
                      'links válidos até '
                      '${DateFormat('HH:mm').format(result.expiresAt)}',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _open(result.jsonUrl),
                      icon: const Icon(Icons.data_object),
                      label: const Text('Baixar todos os dados (JSON)'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _open(result.csvUrl),
                      icon: const Icon(Icons.table_chart_outlined),
                      label: const Text('Baixar planilha de treinos (CSV)'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
