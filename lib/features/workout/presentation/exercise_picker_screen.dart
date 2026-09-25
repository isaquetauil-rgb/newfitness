import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/exercises/logic/exercise_filter.dart';
import 'package:newfitness/features/exercises/logic/exercise_provider.dart';
import 'package:newfitness/features/exercises/logic/exercise_taxonomy_provider.dart';
import 'package:newfitness/features/exercises/presentation/exercise_filter_sheet.dart';
import 'package:newfitness/features/instructor/logic/custom_exercise_provider.dart';
import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/models/sample_exercises.dart';
import 'package:newfitness/shared/models/user_profile.dart';

/// Tela simples de seleção: retorna o [Exercise] escolhido via
/// Navigator.pop, para ser adicionado ao treino em andamento (ou, quando
/// aberta a partir do editor de plano, ao plano que o instrutor está
/// montando — ver `PlanEditorScreen._addExercise`).
class ExercisePickerScreen extends StatefulWidget {
  const ExercisePickerScreen({super.key});

  @override
  State<ExercisePickerScreen> createState() => _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends State<ExercisePickerScreen> {
  String _query = '';
  ExerciseFilter _filter = const ExerciseFilter();

  // Guardado entre builds: cada tecla na busca chama setState, e recriar o
  // stream a cada build fazia "Meus exercícios" sumir e voltar (piscar)
  // enquanto o usuário digitava.
  Stream<List<Exercise>>? _customStream;
  String? _customStreamUid;

  Stream<List<Exercise>> _customFor(String uid) {
    if (_customStream == null || _customStreamUid != uid) {
      _customStreamUid = uid;
      _customStream = context.read<CustomExerciseProvider>().watchExercises(
        uid,
      );
    }
    return _customStream!;
  }

  Future<void> _openFilters() async {
    final equipmentOptions = [
      for (final e in context.read<ExerciseTaxonomyProvider>().equipment)
        e.name,
    ];
    final result = await showExerciseFilterSheet(
      context,
      current: _filter,
      equipmentOptions: equipmentOptions,
    );
    if (result != null) setState(() => _filter = result);
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    final provider = context.watch<ExerciseProvider>();
    final globalExercises = provider.exercises.isNotEmpty
        ? provider.exercises
        : sampleExercises;

    // Biblioteca privada de exercícios: a própria (se instrutor) ou a do
    // instrutor vinculado (se aluno) — null quando não há nenhuma pra
    // mostrar (aluno sem instrutor).
    final customLibraryUid = profile == null
        ? null
        : profile.role == UserRole.instructor
        ? profile.uid
        : profile.instructorId;

    if (customLibraryUid == null) {
      return _buildScaffold(context, custom: const [], global: globalExercises);
    }

    return StreamBuilder<List<Exercise>>(
      stream: _customFor(customLibraryUid),
      builder: (context, snapshot) {
        return _buildScaffold(
          context,
          custom: snapshot.data ?? const [],
          global: globalExercises,
        );
      },
    );
  }

  Widget _buildScaffold(
    BuildContext context, {
    required List<Exercise> custom,
    required List<Exercise> global,
  }) {
    bool matches(Exercise e) =>
        e.name.toLowerCase().contains(_query.toLowerCase()) &&
        _filter.matches(e);
    final filteredCustom = custom.where(matches).toList();
    final filteredGlobal = global.where(matches).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Escolher exercício'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _filter.activeCount > 0,
              label: Text('${_filter.activeCount}'),
              child: const Icon(Icons.tune),
            ),
            tooltip: 'Filtros',
            onPressed: _openFilters,
          ),
        ],
      ),
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
            child: ListView(
              children: [
                if (filteredCustom.isEmpty && filteredGlobal.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Nenhum exercício encontrado com essa busca/filtros.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                if (filteredCustom.isNotEmpty) ...[
                  const _SectionHeader('Meus exercícios'),
                  for (final e in filteredCustom) _ExerciseTile(exercise: e),
                ],
                if (filteredGlobal.isNotEmpty) ...[
                  const _SectionHeader('Biblioteca padrão'),
                  for (final e in filteredGlobal) _ExerciseTile(exercise: e),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(exercise.name),
      subtitle: Text('${exercise.muscleGroup} · ${exercise.equipment}'),
      onTap: () => Navigator.of(context).pop<Exercise>(exercise),
    );
  }
}
