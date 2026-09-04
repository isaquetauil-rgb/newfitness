import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/sample_exercises.dart';
import '../../models/exercise.dart';
import '../../providers/exercise_provider.dart';
import 'exercise_detail_screen.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  String _query = '';
  String? _muscleFilter;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExerciseProvider>();
    // Usa a biblioteca do Firestore; se ainda estiver vazia (nenhum dado
    // cadastrado), cai para a lista de exemplo local.
    final all = provider.exercises.isNotEmpty
        ? provider.exercises
        : sampleExercises;

    final muscleGroups = [
      'Todos',
      ...{for (final e in all) e.muscleGroup},
    ];

    final filtered = all.where((e) {
      final matchesQuery = e.name.toLowerCase().contains(_query.toLowerCase());
      final matchesMuscle =
          _muscleFilter == null ||
          _muscleFilter == 'Todos' ||
          e.muscleGroup == _muscleFilter;
      return matchesQuery && matchesMuscle;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Exercícios')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar exercício...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: muscleGroups.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final group = muscleGroups[i];
                final selected = (_muscleFilter ?? 'Todos') == group;
                return ChoiceChip(
                  label: Text(group),
                  selected: selected,
                  onSelected: (_) => setState(() => _muscleFilter = group),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('Nenhum exercício encontrado'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) =>
                        _ExerciseTile(exercise: filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  final Exercise exercise;

  const _ExerciseTile({required this.exercise});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: Colors.grey.shade100,
          child: const Icon(Icons.play_circle_outline, color: Colors.black54),
        ),
        title: Text(
          exercise.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('${exercise.muscleGroup} · ${exercise.equipment}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ExerciseDetailScreen(exercise: exercise),
            ),
          );
        },
      ),
    );
  }
}
