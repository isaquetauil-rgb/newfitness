import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/sample_exercises.dart';
import '../../models/exercise.dart';
import '../../providers/exercise_provider.dart';

/// Tela simples de seleção: retorna o [Exercise] escolhido via
/// Navigator.pop, para ser adicionado ao treino em andamento.
class ExercisePickerScreen extends StatefulWidget {
  const ExercisePickerScreen({super.key});

  @override
  State<ExercisePickerScreen> createState() => _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends State<ExercisePickerScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExerciseProvider>();
    final all = provider.exercises.isNotEmpty ? provider.exercises : sampleExercises;
    final filtered = all
        .where((e) => e.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Escolher exercício')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Buscar exercício...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final e = filtered[i];
                return ListTile(
                  title: Text(e.name),
                  subtitle: Text('${e.muscleGroup} · ${e.equipment}'),
                  onTap: () => Navigator.of(context).pop<Exercise>(e),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
