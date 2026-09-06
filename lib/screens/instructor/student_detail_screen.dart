import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/workout.dart';
import '../../services/firestore_service.dart';

/// Visão somente-leitura do progresso de um aluno, usada pelo instrutor.
///
/// Importante: para isso funcionar, as regras do Firestore precisam
/// permitir que o instrutor leia a subcoleção `workouts` do aluno vinculado
/// (veja README.md, seção de regras de segurança).
class StudentDetailScreen extends StatelessWidget {
  final String studentUid;
  final String studentName;

  const StudentDetailScreen({
    super.key,
    required this.studentUid,
    required this.studentName,
  });

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return Scaffold(
      appBar: AppBar(title: Text(studentName)),
      body: StreamBuilder<List<Workout>>(
        stream: firestoreService.watchWorkouts(studentUid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Não foi possível carregar os treinos deste aluno. '
                'Verifique as regras de segurança do Firestore.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            );
          }

          final workouts = snapshot.data ?? [];
          if (workouts.isEmpty) {
            return const Center(child: Text('Este aluno ainda não registrou treinos.'));
          }

          final totalVolume = workouts.fold<double>(0, (sum, w) => sum + w.totalVolume);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(child: _StatCard(label: 'Treinos', value: '${workouts.length}')),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'Volume total',
                      value: '${totalVolume.toStringAsFixed(0)} kg',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Histórico', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              for (final w in workouts)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(w.name),
                    subtitle: Text(
                      '${DateFormat('dd/MM/yyyy').format(w.date)} · ${w.totalSets} séries',
                    ),
                    trailing: Text('${w.totalVolume.toStringAsFixed(0)} kg'),
                  ),
                ),
            ],
          );
        },
      ),
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
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
