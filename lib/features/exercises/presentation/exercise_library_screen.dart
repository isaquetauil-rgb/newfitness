import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/app/routes/app_routes.dart';
import 'package:newfitness/app/widgets/drawer_menu_button.dart';
import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/instructor/logic/custom_exercise_provider.dart';
import 'package:newfitness/shared/models/user_profile.dart';
import 'package:newfitness/features/exercises/logic/exercise_filter.dart';
import 'package:newfitness/features/exercises/logic/exercise_search.dart';
import 'package:newfitness/features/exercises/logic/exercise_provider.dart';
import 'package:newfitness/features/exercises/logic/exercise_taxonomy_provider.dart';
import 'package:newfitness/features/exercises/presentation/exercise_filter_sheet.dart';
import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/models/sample_exercises.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  final _searchCtrl = TextEditingController();
  ExerciseFilter _filter = const ExerciseFilter();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _clearAll() {
    _searchCtrl.clear();
    setState(() => _filter = const ExerciseFilter());
  }

  // Biblioteca privada do instrutor (a própria, se instrutor; a do
  // instrutor vinculado, se aluno) — mesmo critério do seletor de
  // exercícios. Antes esses exercícios (e os vídeos próprios do instrutor)
  // não apareciam em nenhuma tela para o aluno.
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

  Future<void> _openFilters(List<String> equipmentOptions) async {
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
    final customLibraryUid = profile == null
        ? null
        : profile.role == UserRole.instructor
        ? profile.uid
        : profile.instructorId;
    if (customLibraryUid == null) return _buildScreen(context, const []);
    return StreamBuilder<List<Exercise>>(
      stream: _customFor(customLibraryUid),
      builder: (context, snapshot) => _buildScreen(
        context,
        snapshot.data ?? const [],
        isOwner: customLibraryUid == profile?.uid,
      ),
    );
  }

  Widget _buildScreen(
    BuildContext context,
    List<Exercise> custom, {
    bool isOwner = false,
  }) {
    final provider = context.watch<ExerciseProvider>();
    final equipmentOptions = [
      for (final e in context.watch<ExerciseTaxonomyProvider>().equipment)
        e.name,
    ];
    // Usa a biblioteca do Firestore; se ainda estiver vazia (nenhum dado
    // cadastrado), cai para a lista de exemplo local.
    final general = provider.exercises.isNotEmpty
        ? provider.exercises
        : sampleExercises;
    // O personal dono não vê a versão geral do que ele já tem como próprio.
    final all = [
      ...custom,
      ...(isOwner ? hideGeneralDuplicates(general, custom) : general),
    ];
    final customIds = {for (final e in custom) e.id};

    const muscleGroups = ['Todos', ...canonicalMuscleGroups];
    final quickGroup = _filter.muscleGroups.length == 1
        ? _filter.muscleGroups.first
        : (_filter.muscleGroups.isEmpty ? 'Todos' : null);

    final filtered = all.where(_filter.matches).toList();

    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Exercícios'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _filter.activeCount > 0,
              label: Text('${_filter.activeCount}'),
              child: const Icon(Icons.tune),
            ),
            tooltip: 'Filtros',
            onPressed: () => _openFilters(equipmentOptions),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Buscar por nome, apelido ou tag...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) =>
                  setState(() => _filter = _filter.copyWith(query: v)),
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
                return ChoiceChip(
                  label: Text(group),
                  selected: quickGroup == group,
                  onSelected: (_) => setState(
                    () => _filter = _filter.copyWith(
                      muscleGroups: group == 'Todos' ? {} : {group},
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          ExerciseResultsBar(
            count: filtered.length,
            canClear: !_filter.isEmpty,
            onClear: _clearAll,
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('Nenhum exercício encontrado'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => _ExerciseTile(
                      exercise: filtered[i],
                      isCustom: customIds.contains(filtered[i].id),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  final Exercise exercise;
  final bool isCustom;

  const _ExerciseTile({required this.exercise, this.isCustom = false});

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
        subtitle: Text(
          isCustom
              ? '${exercise.muscleGroup} · ${exercise.equipment} · do instrutor'
              : '${exercise.muscleGroup} · ${exercise.equipment}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(AppRoutes.exerciseDetail, extra: exercise),
      ),
    );
  }
}
