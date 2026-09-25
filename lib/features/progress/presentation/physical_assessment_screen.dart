import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/progress/logic/evolution_summary.dart';
import 'package:newfitness/features/progress/logic/physical_assessment_provider.dart';
import 'package:newfitness/shared/models/physical_assessment.dart';

import 'assessment_form_sheet.dart';
import 'body_progress_screen.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

/// Evolução física: resumo, gráficos, histórico de avaliações, fotos e
/// comparação entre duas avaliações. Sem [studentUid], mostra os dados do
/// próprio usuário logado; com [studentUid] (aberto pelo instrutor a partir
/// de [StudentDetailScreen]), mostra os daquele aluno — o instrutor pode
/// lançar avaliações, mas só visualiza as fotos.
///
/// Só apresenta valores registrados e suas variações — nenhuma
/// interpretação ou recomendação.
class PhysicalAssessmentScreen extends StatefulWidget {
  const PhysicalAssessmentScreen({
    super.key,
    this.studentUid,
    this.studentName,
  });

  final String? studentUid;
  final String? studentName;

  @override
  State<PhysicalAssessmentScreen> createState() =>
      _PhysicalAssessmentScreenState();
}

class _PhysicalAssessmentScreenState extends State<PhysicalAssessmentScreen> {
  Stream<List<PhysicalAssessment>>? _stream;
  String? _streamUid;

  Stream<List<PhysicalAssessment>> _streamFor(String uid) {
    if (_stream == null || _streamUid != uid) {
      _streamUid = uid;
      _stream = context.read<PhysicalAssessmentProvider>().watchAssessments(
        uid,
      );
    }
    return _stream!;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final viewerUid = auth.user?.uid;
    final uid = widget.studentUid ?? viewerUid;
    final isOwner = uid != null && uid == viewerUid;
    final profileHeight = isOwner ? auth.profile?.heightCm : null;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.studentName != null
                ? 'Evolução · ${widget.studentName}'
                : 'Evolução física',
          ),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Resumo'),
              Tab(text: 'Gráficos'),
              Tab(text: 'Histórico'),
              Tab(text: 'Fotos'),
              Tab(text: 'Comparar'),
            ],
          ),
        ),
        body: uid == null || viewerUid == null
            ? const Center(child: CircularProgressIndicator())
            : StreamBuilder<List<PhysicalAssessment>>(
                stream: _streamFor(uid),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const _Empty(
                      'Não foi possível carregar as avaliações.',
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final summary = EvolutionSummary(
                    snapshot.data ?? const [],
                    profileHeightCm: profileHeight,
                  );
                  void openForm([PhysicalAssessment? existing]) =>
                      showAssessmentForm(
                        context,
                        userId: uid,
                        recordedBy: isOwner
                            ? AssessmentSource.self
                            : AssessmentSource.instructor,
                        existing: existing,
                        suggestedHeightCm: summary.currentHeightCm,
                      );

                  return TabBarView(
                    children: [
                      _SummaryTab(summary: summary, onAdd: openForm),
                      _ChartsTab(summary: summary),
                      _HistoryTab(
                        summary: summary,
                        viewerUid: viewerUid,
                        viewerIsOwner: isOwner,
                        onAdd: openForm,
                        onEdit: openForm,
                      ),
                      BodyPhotoGallery(uid: uid, canAdd: isOwner),
                      _CompareTab(summary: summary),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text, {this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ---------- Resumo ----------

class _SummaryTab extends StatelessWidget {
  const _SummaryTab({required this.summary, required this.onAdd});

  final EvolutionSummary summary;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final addButton = FilledButton.icon(
      onPressed: onAdd,
      icon: const Icon(Icons.add),
      label: const Text('Nova avaliação'),
    );
    if (summary.isEmpty) {
      return _Empty('Nenhuma avaliação registrada ainda.', action: addButton);
    }

    final weight = summary.currentWeightKg;
    final change = summary.weightChangeKg;
    final bmi = summary.currentBmi;
    final fat = summary.currentBodyFatPercent;
    final muscle = summary.currentMuscleMassKg;
    final measurements = summary.currentMeasurements;
    final highlighted = [
      for (final k in BodyMeasurement.highlights)
        if (measurements.containsKey(k)) k,
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Última avaliação: ${_dateFmt.format(summary.latest!.date)} · '
          '${summary.chronological.length} avaliação(ões) no histórico',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.9,
          children: [
            _StatTile(
              label: 'Peso atual',
              value: weight == null ? '—' : '${formatMetric(weight)} kg',
            ),
            _StatTile(
              label: 'Variação de peso',
              value: change == null ? '—' : '${formatDifference(change)} kg',
              caption: change == null ? null : 'desde a 1ª avaliação',
            ),
            if (bmi != null) _StatTile(label: 'IMC', value: formatMetric(bmi)),
            if (fat != null)
              _StatTile(label: '% de gordura', value: '${formatMetric(fat)}%'),
            if (muscle != null)
              _StatTile(
                label: 'Massa muscular',
                value: '${formatMetric(muscle)} kg',
              ),
          ],
        ),
        if (highlighted.isNotEmpty) ...[
          const _SectionTitle('Principais medidas (último registro)'),
          Card(
            child: Column(
              children: [
                for (final key in highlighted)
                  ListTile(
                    dense: true,
                    title: Text(BodyMeasurement.labelOf(key)),
                    trailing: Text(
                      '${formatMetric(measurements[key]!)} cm',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        addButton,
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, this.caption});

  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (caption != null)
              Text(
                caption!,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------- Gráficos ----------

class _ChartsTab extends StatefulWidget {
  const _ChartsTab({required this.summary});

  final EvolutionSummary summary;

  @override
  State<_ChartsTab> createState() => _ChartsTabState();
}

class _ChartsTabState extends State<_ChartsTab> {
  String? _measurementKey;

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    final weight = s.series((a) => a.weightKg);
    final fat = s.series((a) => a.bodyFatPercent);
    final muscle = s.series((a) => a.muscleMassKg);
    final measurementKeys = [
      for (final k in BodyMeasurement.keysIn(s.chronological))
        if (s.series((a) => a.measurementsCm[k]).length >= 2) k,
    ];
    final selectedKey = measurementKeys.contains(_measurementKey)
        ? _measurementKey!
        : (measurementKeys.isEmpty ? null : measurementKeys.first);

    final charts = <Widget>[
      if (weight.length >= 2) ...[
        const _SectionTitle('Peso (kg)'),
        _LineChart(points: weight),
      ],
      if (fat.length >= 2) ...[
        const _SectionTitle('% de gordura'),
        _LineChart(points: fat),
      ],
      if (muscle.length >= 2) ...[
        const _SectionTitle('Massa muscular (kg)'),
        _LineChart(points: muscle),
      ],
      if (selectedKey != null) ...[
        const _SectionTitle('Medidas (cm)'),
        DropdownButton<String>(
          value: selectedKey,
          isExpanded: true,
          items: [
            for (final k in measurementKeys)
              DropdownMenuItem(
                value: k,
                child: Text(BodyMeasurement.labelOf(k)),
              ),
          ],
          onChanged: (v) => setState(() => _measurementKey = v),
        ),
        const SizedBox(height: 8),
        _LineChart(points: s.series((a) => a.measurementsCm[selectedKey])),
      ],
    ];

    if (charts.isEmpty) {
      return const _Empty(
        'Os gráficos aparecem quando houver pelo menos duas avaliações com o '
        'mesmo dado registrado.',
      );
    }
    return ListView(padding: const EdgeInsets.all(16), children: charts);
  }
}

class _LineChart extends StatelessWidget {
  const _LineChart({required this.points});

  final List<(DateTime, double)> points;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 40),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                // No máximo ~6 datas no eixo: com muitas avaliações os
                // rótulos se sobrepunham.
                interval: (points.length / 6).ceilToDouble().clamp(1, 1000),
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i != value || i < 0 || i >= points.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      DateFormat('dd/MM').format(points[i].$1),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => [
                for (final spot in spots)
                  LineTooltipItem(
                    '${formatMetric(spot.y)}\n'
                    '${_dateFmt.format(points[spot.x.toInt()].$1)}',
                    const TextStyle(color: Colors.white, fontSize: 12),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < points.length; i++)
                  FlSpot(i.toDouble(), points[i].$2),
              ],
              color: color,
              barWidth: 3,
              dotData: const FlDotData(show: true),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Histórico ----------

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({
    required this.summary,
    required this.viewerUid,
    required this.viewerIsOwner,
    required this.onAdd,
    required this.onEdit,
  });

  final EvolutionSummary summary;
  final String viewerUid;
  final bool viewerIsOwner;
  final VoidCallback onAdd;
  final void Function(PhysicalAssessment) onEdit;

  Future<void> _confirmDelete(
    BuildContext context,
    PhysicalAssessment a,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar avaliação?'),
        content: Text(
          'A avaliação de ${_dateFmt.format(a.date)} será removida do '
          'histórico.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<PhysicalAssessmentProvider>().deleteAssessment(
      a.userId,
      a.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final newestFirst = summary.chronological.reversed.toList();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: newestFirst.isEmpty
          ? const _Empty('Nenhuma avaliação registrada ainda.')
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: newestFirst.length,
              itemBuilder: (context, i) {
                final a = newestFirst[i];
                final canModify = PhysicalAssessmentProvider.canModify(
                  a,
                  viewerUid: viewerUid,
                  viewerIsOwner: viewerIsOwner,
                );
                return _AssessmentCard(
                  assessment: a,
                  previous: i + 1 < newestFirst.length
                      ? newestFirst[i + 1]
                      : null,
                  profileHeightCm: summary.profileHeightCm,
                  onEdit: canModify ? () => onEdit(a) : null,
                  onDelete: canModify ? () => _confirmDelete(context, a) : null,
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_assessment',
        onPressed: onAdd,
        icon: const Icon(Icons.add),
        label: const Text('Nova avaliação'),
      ),
    );
  }
}

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard({
    required this.assessment,
    required this.previous,
    required this.profileHeightCm,
    this.onEdit,
    this.onDelete,
  });

  final PhysicalAssessment assessment;
  final PhysicalAssessment? previous;
  final double? profileHeightCm;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  String _withDelta(double value, double? prev, String unit) {
    final base = '${formatMetric(value)}$unit';
    if (prev == null) return base;
    final diff = value - prev;
    if (diff.abs() < 0.05) return base;
    return '$base (${formatDifference(diff)})';
  }

  @override
  Widget build(BuildContext context) {
    final a = assessment;
    final p = previous;
    final bmi = a.bmi(fallbackHeightCm: profileHeightCm);
    final lines = <(String, String)>[
      if (a.weightKg != null)
        ('Peso', _withDelta(a.weightKg!, p?.weightKg, ' kg')),
      if (a.heightCm != null) ('Altura', '${formatMetric(a.heightCm!)} cm'),
      if (bmi != null) ('IMC', formatMetric(bmi)),
      if (a.bodyFatPercent != null)
        (
          '% de gordura',
          _withDelta(a.bodyFatPercent!, p?.bodyFatPercent, '%') +
              (a.bodyFatMethod == null
                  ? ''
                  : ' · ${BodyFatMethod.labelOf(a.bodyFatMethod!)}'),
        ),
      if (a.muscleMassKg != null)
        ('Massa muscular', _withDelta(a.muscleMassKg!, p?.muscleMassKg, ' kg')),
      for (final key in BodyMeasurement.keysIn([a]))
        (
          BodyMeasurement.labelOf(key),
          _withDelta(a.measurementsCm[key]!, p?.measurementsCm[key], ' cm'),
        ),
    ];
    final author = a.recordedBy == AssessmentSource.instructor
        ? (a.createdByName != null
              ? 'Instrutor: ${a.createdByName}'
              : AssessmentSource.labelOf(a.recordedBy))
        : AssessmentSource.labelOf(a.recordedBy);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _dateFmt.format(a.date),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        author,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onEdit != null)
                  IconButton(
                    tooltip: 'Editar',
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: onEdit,
                  ),
                if (onDelete != null)
                  IconButton(
                    tooltip: 'Apagar',
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: onDelete,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            for (final (label, value) in lines)
              Padding(
                padding: const EdgeInsets.only(right: 12, bottom: 2),
                child: Row(
                  children: [
                    Expanded(child: Text(label)),
                    Text(value),
                  ],
                ),
              ),
            if (lines.isEmpty) const Text('Sem valores registrados'),
            if (a.notes != null) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  a.notes!,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------- Comparar ----------

class _CompareTab extends StatefulWidget {
  const _CompareTab({required this.summary});

  final EvolutionSummary summary;

  @override
  State<_CompareTab> createState() => _CompareTabState();
}

class _CompareTabState extends State<_CompareTab> {
  String? _beforeId;
  String? _afterId;

  @override
  Widget build(BuildContext context) {
    final list = widget.summary.chronological;
    if (list.length < 2) {
      return const _Empty(
        'A comparação fica disponível a partir de duas avaliações.',
      );
    }
    PhysicalAssessment find(String? id, PhysicalAssessment fallback) =>
        list.firstWhere((a) => a.id == id, orElse: () => fallback);
    final before = find(_beforeId, list.first);
    final after = find(_afterId, list.last);
    final rows = widget.summary.compare(before, after);

    DropdownButton<String> picker(
      PhysicalAssessment selected,
      ValueChanged<String?> onChanged,
    ) {
      return DropdownButton<String>(
        value: selected.id,
        isExpanded: true,
        items: [
          for (final a in list.reversed)
            DropdownMenuItem(value: a.id, child: Text(_dateFmt.format(a.date))),
        ],
        onChanged: onChanged,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Avaliação inicial',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  picker(before, (v) => setState(() => _beforeId = v)),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Text('VS', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Avaliação atual',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  picker(after, (v) => setState(() => _afterId = v)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty) const _Empty('Nenhum valor registrado.'),
        for (final r in rows) _ComparisonRow(row: r),
        const SizedBox(height: 12),
        Text(
          'Os valores acima são apenas os registrados em cada avaliação e a '
          'diferença entre eles. "—" indica que o dado não foi medido naquela '
          'data.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({required this.row});

  final MetricComparison row;

  String _fmt(double? v) => v == null ? '—' : '${formatMetric(v)} ${row.unit}';

  @override
  Widget build(BuildContext context) {
    final diff = row.difference;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              row.label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text('${_fmt(row.before)} → ${_fmt(row.after)}'),
            Text(
              diff == null
                  ? 'Diferença: —'
                  : 'Diferença: ${formatDifference(diff)} ${row.unit}',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card compacto com o resumo da evolução de um aluno — usado no
/// [StudentDetailScreen] do instrutor, com atalho para a tela completa.
class EvolutionOverviewCard extends StatefulWidget {
  const EvolutionOverviewCard({
    super.key,
    required this.studentUid,
    required this.onOpen,
  });

  final String studentUid;
  final VoidCallback onOpen;

  @override
  State<EvolutionOverviewCard> createState() => _EvolutionOverviewCardState();
}

class _EvolutionOverviewCardState extends State<EvolutionOverviewCard> {
  late final Stream<List<PhysicalAssessment>> _stream = context
      .read<PhysicalAssessmentProvider>()
      .watchAssessments(widget.studentUid);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PhysicalAssessment>>(
      stream: _stream,
      builder: (context, snapshot) {
        final summary = EvolutionSummary(snapshot.data ?? const []);
        final weight = summary.currentWeightKg;
        final change = summary.weightChangeKg;
        final String subtitle;
        if (snapshot.hasError) {
          subtitle = 'Não foi possível carregar as avaliações.';
        } else if (summary.isEmpty) {
          subtitle = snapshot.connectionState == ConnectionState.waiting
              ? 'Carregando…'
              : 'Nenhuma avaliação registrada.';
        } else {
          subtitle = [
            'Última: ${_dateFmt.format(summary.latest!.date)}',
            if (weight != null) 'Peso ${formatMetric(weight)} kg',
            if (change != null) 'Variação ${formatDifference(change)} kg',
          ].join(' · ');
        }
        return Card(
          child: ListTile(
            leading: const Icon(Icons.monitor_weight_outlined),
            title: const Text('Evolução física'),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: widget.onOpen,
          ),
        );
      },
    );
  }
}
