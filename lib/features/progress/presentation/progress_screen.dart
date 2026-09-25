import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/app/widgets/drawer_menu_button.dart';
import 'package:newfitness/app/widgets/tab_switch_signal.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/workout/logic/workout_provider.dart';
import 'package:newfitness/shared/models/workout.dart';

import 'body_progress_screen.dart';
import 'exercise_progress_list.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 3, vsync: this);
    TabSwitchSignal.progress.addListener(_onSignal);
    _onSignal();
  }

  void _onSignal() {
    final index = TabSwitchSignal.progress.value;
    if (index != null) {
      _controller.animateTo(index);
      TabSwitchSignal.progress.value = null;
    }
  }

  @override
  void dispose() {
    TabSwitchSignal.progress.removeListener(_onSignal);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Progresso'),
        bottom: TabBar(
          controller: _controller,
          tabs: const [
            Tab(text: 'Gráficos'),
            Tab(text: 'Fotos'),
            Tab(text: 'Por exercício'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _controller,
        // "Fotos" fica no índice 1 de propósito — o menu lateral
        // (`app_drawer.dart`) navega direto pra esse índice; a aba nova vai
        // no fim pra não quebrar esse atalho.
        children: [
          const _WorkoutProgressTab(),
          const BodyProgressScreen(),
          _ExerciseProgressTab(uid: context.watch<AuthProvider>().user?.uid),
        ],
      ),
    );
  }
}

class _ExerciseProgressTab extends StatelessWidget {
  const _ExerciseProgressTab({required this.uid});

  final String? uid;

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return const Center(child: Text('Faça login para ver seu progresso'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [ExerciseProgressList(uid: uid!)],
    );
  }
}

class _WorkoutProgressTab extends StatelessWidget {
  const _WorkoutProgressTab();

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().user?.uid;
    final workoutProvider = context.read<WorkoutProvider>();

    return uid == null
        ? const Center(child: Text('Faça login para ver seu progresso'))
        : StreamBuilder<List<Workout>>(
            stream: workoutProvider.watchHistory(uid),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Não foi possível carregar seu histórico de treinos.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final workouts = (snapshot.data ?? [])
                ..sort((a, b) => a.date.compareTo(b.date));

              if (workouts.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Ainda não há treinos registrados.\nFinalize um treino para ver seu progresso aqui.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SummaryRow(workouts: workouts),
                  const SizedBox(height: 24),
                  const Text(
                    'Volume por treino (kg)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 220,
                    child: _VolumeChart(workouts: workouts),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Histórico',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  for (final w in workouts.reversed)
                    _WorkoutHistoryTile(workout: w),
                ],
              );
            },
          );
  }
}

class _SummaryRow extends StatelessWidget {
  final List<Workout> workouts;

  const _SummaryRow({required this.workouts});

  @override
  Widget build(BuildContext context) {
    final totalWorkouts = workouts.length;
    final totalVolume = workouts.fold<double>(
      0,
      (sum, w) => sum + w.totalVolume,
    );

    return Row(
      children: [
        Expanded(
          child: _StatCard(label: 'Treinos', value: '$totalWorkouts'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Volume total',
            value: '${totalVolume.toStringAsFixed(0)} kg',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

class _VolumeChart extends StatelessWidget {
  final List<Workout> workouts;

  const _VolumeChart({required this.workouts});

  @override
  Widget build(BuildContext context) {
    final points = workouts.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.totalVolume);
    }).toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= workouts.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat('dd/MM').format(workouts[i].date),
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: points,
            isCurved: true,
            barWidth: 3,
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }
}

class _WorkoutHistoryTile extends StatelessWidget {
  final Workout workout;

  const _WorkoutHistoryTile({required this.workout});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(workout.name),
        subtitle: Text(
          '${DateFormat('dd/MM/yyyy').format(workout.date)} · ${workout.totalSets} séries',
        ),
        trailing: Text('${workout.totalVolume.toStringAsFixed(0)} kg'),
      ),
    );
  }
}
