import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/features/progress/logic/progress_record_provider.dart';
import 'package:newfitness/shared/models/exercise_progress_record.dart';

/// Lista de evolução por exercício (`progress_records`) — 1 leitura por
/// usuário, já ordenada pelo mais recente. Usado tanto pelo próprio aluno
/// (`ProgressScreen`) quanto pelo instrutor olhando um aluno vinculado
/// (`StudentDetailScreen`), por isso recebe [uid] em vez de sempre usar o
/// usuário logado.
class ExerciseProgressList extends StatefulWidget {
  const ExerciseProgressList({super.key, required this.uid});

  final String uid;

  @override
  State<ExerciseProgressList> createState() => _ExerciseProgressListState();
}

class _ExerciseProgressListState extends State<ExerciseProgressList> {
  // Criado uma vez (e refeito só se o uid mudar) — recriar a cada build
  // do pai reabria a consulta e fazia a lista piscar.
  late Stream<List<ExerciseProgressRecord>> _stream = _watch();

  Stream<List<ExerciseProgressRecord>> _watch() =>
      context.read<ProgressRecordProvider>().watchRecords(widget.uid);

  @override
  void didUpdateWidget(ExerciseProgressList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) _stream = _watch();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ExerciseProgressRecord>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Não foi possível carregar a evolução por exercício.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final records = snapshot.data ?? const [];
        if (records.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Nenhuma evolução de carga registrada ainda — finalize um '
              'treino com peso preenchido para começar a acompanhar aqui.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          );
        }
        return Column(
          children: [
            for (final record in records) _ProgressRecordTile(record: record),
          ],
        );
      },
    );
  }
}

class _ProgressRecordTile extends StatelessWidget {
  const _ProgressRecordTile({required this.record});

  final ExerciseProgressRecord record;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    record.exerciseName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '${record.totalSessions} treino(s)',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _MiniStat(
                  label: 'Melhor carga',
                  value: '${record.bestLoadKg.toStringAsFixed(1)} kg',
                ),
                const SizedBox(width: 20),
                _MiniStat(
                  label: 'Última',
                  value: '${record.lastLoadKg.toStringAsFixed(1)} kg',
                ),
              ],
            ),
            if (record.history.length > 1) ...[
              const SizedBox(height: 12),
              SizedBox(height: 50, child: _Sparkline(history: record.history)),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.history});

  final List<ProgressPoint> history;

  @override
  Widget build(BuildContext context) {
    final spots = history
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.topSetLoadKg))
        .toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}
