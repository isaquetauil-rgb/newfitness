import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'package:newfitness/features/professional/logic/student_activity.dart';

/// Peças do painel do profissional, usadas pelo personal e pela
/// nutricionista.

/// "Olá, Ana" + data de hoje.
class DashboardGreeting extends StatelessWidget {
  const DashboardGreeting({super.key, required this.name, required this.now});

  final String name;
  final DateTime now;

  static const _weekdays = [
    'segunda-feira',
    'terça-feira',
    'quarta-feira',
    'quinta-feira',
    'sexta-feira',
    'sábado',
    'domingo',
  ];
  static const _months = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];

  @override
  Widget build(BuildContext context) {
    final first = name.trim().split(RegExp(r'\s+')).first;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          first.isEmpty ? 'Olá!' : 'Olá, $first',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${_weekdays[now.weekday - 1]}, ${now.day} de ${_months[now.month - 1]}',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Número grande com rótulo (ex.: "12 alunos"). Tocável quando [onTap].
class DashboardStatTile extends StatelessWidget {
  const DashboardStatTile({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    this.highlight = false,
    this.onTap,
  });

  final String value;
  final String label;
  final IconData icon;

  /// Destaca (cor de atenção) quando o número pede ação.
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = highlight ? scheme.error : scheme.primary;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: highlight ? scheme.error : null,
                ),
              ),
              Text(
                label,
                maxLines: 2,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Atalho quadrado com ícone e texto curto.
class DashboardQuickAction extends StatelessWidget {
  const DashboardQuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Código de convite com "Copiar" e "Compartilhar" (WhatsApp etc.).
class ProfessionalInviteCard extends StatelessWidget {
  const ProfessionalInviteCard({
    super.key,
    required this.code,
    required this.shareText,
  });

  final String code;

  /// Mensagem enviada ao compartilhar (já com o código).
  final String shareText;

  bool get _hasCode => code.trim().isNotEmpty && code != '—';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Icon(Icons.qr_code_2, size: 32, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seu código de convite',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  SelectableText(
                    _hasCode ? code : 'Gerando...',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy_outlined),
              tooltip: 'Copiar',
              onPressed: _hasCode
                  ? () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Código copiado')),
                      );
                    }
                  : null,
            ),
            IconButton(
              key: const ValueKey('share-invite'),
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Compartilhar convite',
              onPressed: _hasCode
                  ? () => SharePlus.instance.share(ShareParams(text: shareText))
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Bolinha + texto da situação do aluno.
class StudentStatusDot extends StatelessWidget {
  const StudentStatusDot({super.key, required this.status});

  final StudentStatus? status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      StudentStatus.active => Colors.green,
      StudentStatus.inactive => scheme.error,
      StudentStatus.neverTrained || StudentStatus.noPlan => Colors.orange,
      null => scheme.outlineVariant,
    };
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Título de seção ("Alunos", "Atalhos").
class DashboardSectionTitle extends StatelessWidget {
  const DashboardSectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
