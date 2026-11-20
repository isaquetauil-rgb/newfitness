import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/exercises/logic/exercise_pool.dart';
import 'package:newfitness/features/exercises/logic/exercise_similarity.dart';
import 'package:newfitness/features/import/logic/workout_csv_parser.dart';
import 'package:newfitness/features/import/logic/workout_import.dart';
import 'package:newfitness/features/workout/logic/workout_provider.dart';
import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/models/sample_exercises.dart';
import 'package:newfitness/shared/models/sample_functional_exercises.dart';
import 'package:newfitness/shared/models/workout.dart';

/// Lê o arquivo escolhido pelo aluno (texto) ou `null` se ele desistir.
typedef CsvPicker = Future<String?> Function();

Future<String?> _pickCsvFile() async {
  // Tipo "qualquer": no Android o filtro por .csv às vezes esconde o
  // arquivo (cada app grava o CSV com um tipo diferente).
  final file = await FilePicker.pickFile(type: FileType.any);
  if (file == null) return null;
  final bytes = await file.xFile.readAsBytes();
  return utf8.decode(bytes, allowMalformed: true);
}

/// Importar treinos do Hevy ou do Strong (CSV): escolher o arquivo, conferir
/// a prévia (e os exercícios que não casaram) e gravar.
class ImportWorkoutsScreen extends StatefulWidget {
  const ImportWorkoutsScreen({
    super.key,
    this.pickCsv,
    this.pool,
    this.history,
  });

  /// Para testes: troca a escolha do arquivo.
  final CsvPicker? pickCsv;

  /// Para testes: biblioteca e histórico já prontos.
  final List<Exercise>? pool;
  final List<Workout>? history;

  @override
  State<ImportWorkoutsScreen> createState() => _ImportWorkoutsScreenState();
}

class _ImportWorkoutsScreenState extends State<ImportWorkoutsScreen> {
  String? _text;
  CsvImportResult? _parsed;
  WeightUnit _unit = WeightUnit.kg;
  Map<String, ImportChoice> _choices = {};
  List<Exercise> _pool = const [];
  List<Workout> _history = const [];
  String? _error;
  bool _loading = false;
  bool _saving = false;
  int? _savedCount;

  Future<void> _pick() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final text = await (widget.pickCsv ?? _pickCsvFile)();
      if (text == null) return;
      if (_pool.isEmpty) _pool = await _loadPool();
      _history = await _loadHistory();
      _text = text;
      _parse();
    } catch (_) {
      _error = 'Não foi possível ler o arquivo.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<Exercise>> _loadPool() async {
    if (widget.pool != null) return widget.pool!;
    final loaded = await loadExercisePool(context);
    final byId = {
      for (final e in [
        ...sampleExercises,
        ...sampleFunctionalExercises,
        ...loaded,
      ])
        e.id: e,
    };
    return byId.values.toList();
  }

  Future<List<Workout>> _loadHistory() async {
    if (widget.history != null) return widget.history!;
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) return const [];
    return context.read<WorkoutProvider>().watchHistory(uid).first;
  }

  void _parse() {
    try {
      final parsed = parseWorkoutCsv(_text!, strongUnit: _unit);
      setState(() {
        _parsed = parsed;
        _error = parsed.workouts.isEmpty
            ? 'Nenhum treino encontrado no arquivo.'
            : null;
        // Mantém o que o aluno já escolheu; completa com o automático.
        _choices = {
          ...suggestChoices(parsed.exerciseNames, _pool),
          for (final e in _choices.entries)
            if (parsed.exerciseNames.contains(e.key)) e.key: e.value,
        };
      });
    } on FormatException catch (e) {
      setState(() {
        _parsed = null;
        _error = e.message;
      });
    }
  }

  ImportPlan? get _plan {
    final parsed = _parsed;
    final uid = context.read<AuthProvider>().user?.uid ?? '';
    if (parsed == null) return null;
    if (parsed.exerciseNames.any((n) => !_choices.containsKey(n))) return null;
    return buildImport(parsed, _choices, userId: uid, history: _history);
  }

  Future<void> _save(ImportPlan plan) async {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      await context.read<WorkoutProvider>().importWorkouts(uid, plan.toSave);
      if (mounted) setState(() => _savedCount = plan.toSave.length);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível salvar. Verifique a conexão e tente de novo.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _chooseFor(String name) async {
    final choice = await showModalBottomSheet<ImportChoice>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ExerciseChoiceSheet(name: name, pool: _pool),
    );
    if (choice != null) setState(() => _choices[name] = choice);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final parsed = _parsed;
    return Scaffold(
      appBar: AppBar(title: const Text('Importar treinos')),
      body: _savedCount != null
          ? _done(scheme)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Traga seu histórico do Hevy ou do Strong. No app de '
                  'origem, exporte os treinos em CSV e escolha o arquivo '
                  'aqui. Você confere tudo antes de salvar; importar o mesmo '
                  'arquivo de novo não duplica treinos.',
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _loading || _saving ? null : _pick,
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file),
                  label: Text(
                    parsed == null ? 'Escolher arquivo CSV' : 'Escolher outro',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: scheme.error)),
                ],
                if (parsed != null && parsed.workouts.isNotEmpty)
                  ..._preview(parsed, scheme),
              ],
            ),
    );
  }

  List<Widget> _preview(CsvImportResult parsed, ColorScheme scheme) {
    final date = DateFormat('dd/MM/yyyy', 'pt_BR');
    final first = parsed.workouts.first.start;
    final last = parsed.workouts.last.start;
    final sets = parsed.workouts.fold<int>(0, (n, w) => n + w.setCount);
    final pending = parsed.exerciseNames
        .where((n) => !_choices.containsKey(n))
        .length;
    final plan = _plan;
    return [
      const SizedBox(height: 20),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Arquivo do ${parsed.source.label}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                '${parsed.workouts.length} '
                '${parsed.workouts.length == 1 ? 'treino' : 'treinos'} · '
                '$sets séries · de ${date.format(first)} a ${date.format(last)}',
              ),
              if (plan != null && plan.duplicates > 0)
                Text(
                  '${plan.duplicates} já '
                  '${plan.duplicates == 1 ? 'estava' : 'estavam'} no seu '
                  'histórico e não ${plan.duplicates == 1 ? 'será' : 'serão'} '
                  'importado${plan.duplicates == 1 ? '' : 's'} de novo.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              if (parsed.skippedRows > 0)
                Text(
                  '${parsed.skippedRows} linha(s) sem série foram ignoradas '
                  '(descanso, série vazia).',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ),
      if (parsed.source == ImportSource.strong && !parsed.unitFromFile) ...[
        const SizedBox(height: 12),
        const Text('Os pesos no Strong estavam em:'),
        const SizedBox(height: 6),
        SegmentedButton<WeightUnit>(
          segments: const [
            ButtonSegment(value: WeightUnit.kg, label: Text('Quilos (kg)')),
            ButtonSegment(value: WeightUnit.lb, label: Text('Libras (lb)')),
          ],
          selected: {_unit},
          onSelectionChanged: (s) {
            _unit = s.first;
            _parse();
          },
        ),
      ],
      const SizedBox(height: 20),
      Text(
        pending == 0 ? 'Exercícios' : 'Exercícios · falta escolher $pending',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 4),
      for (final name in parsed.exerciseNames)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            _choices[name] == null
                ? Icons.help_outline
                : _choices[name]!.own
                ? Icons.person_outline
                : Icons.check_circle_outline,
            color: _choices[name] == null ? scheme.error : scheme.primary,
          ),
          title: Text(name),
          subtitle: Text(
            _choices[name] == null
                ? 'Toque para escolher o exercício'
                : _choices[name]!.own
                ? 'Exercício próprio: ${_choices[name]!.exerciseName} '
                      '(${_choices[name]!.muscleGroup})'
                : '→ ${_choices[name]!.exerciseName}',
          ),
          trailing: const Icon(Icons.edit_outlined, size: 18),
          onTap: () => _chooseFor(name),
        ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: plan == null || plan.toSave.isEmpty || _saving
            ? null
            : () => _save(plan),
        icon: _saving
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.download_done),
        label: Text(
          plan == null
              ? 'Escolha os exercícios que faltam'
              : plan.toSave.isEmpty
              ? 'Nada novo para importar'
              : 'Importar ${plan.toSave.length} '
                    '${plan.toSave.length == 1 ? 'treino' : 'treinos'}',
        ),
      ),
    ];
  }

  Widget _done(ColorScheme scheme) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 56, color: scheme.primary),
          const SizedBox(height: 12),
          Text(
            _savedCount == 1
                ? '1 treino importado!'
                : '$_savedCount treinos importados!',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Eles já aparecem no seu histórico, no mapa muscular e nas '
            'conquistas.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Concluir'),
          ),
        ],
      ),
    ),
  );
}

/// Escolher o exercício para um nome do arquivo: sugestões parecidas,
/// busca na biblioteca ou criar como exercício próprio.
class _ExerciseChoiceSheet extends StatefulWidget {
  const _ExerciseChoiceSheet({required this.name, required this.pool});

  final String name;
  final List<Exercise> pool;

  @override
  State<_ExerciseChoiceSheet> createState() => _ExerciseChoiceSheetState();
}

class _ExerciseChoiceSheetState extends State<_ExerciseChoiceSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final suggestions = matchExercisesByName(widget.name, widget.pool);
    final q = _query.trim().toLowerCase();
    final results = q.isEmpty
        ? const <Exercise>[]
        : widget.pool
              .where(
                (e) =>
                    e.name.toLowerCase().contains(q) ||
                    e.alternateName.toLowerCase().contains(q),
              )
              .take(20)
              .toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: ListView(
            children: [
              Text(
                widget.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Buscar na biblioteca',
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              if (q.isEmpty && suggestions.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Parecidos',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
              for (final e
                  in q.isEmpty ? suggestions.map((s) => s.exercise) : results)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(e.name),
                  subtitle: Text('${e.muscleGroup} · ${e.equipment}'),
                  onTap: () => Navigator.pop(context, ImportChoice.library(e)),
                ),
              const Divider(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.add),
                title: const Text('Criar como exercício próprio'),
                subtitle: Text('Fica com o nome "${widget.name}"'),
                onTap: () => _createOwn(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createOwn(BuildContext context) async {
    final choice = await showDialog<ImportChoice>(
      context: context,
      builder: (_) => _OwnNameDialog(initial: widget.name),
    );
    if (choice == null || !context.mounted) return;
    Navigator.pop(context, choice);
  }
}

/// Nome e grupo muscular do exercício próprio (o grupo é obrigatório: é
/// ele que coloca o exercício no mapa muscular).
class _OwnNameDialog extends StatefulWidget {
  const _OwnNameDialog({required this.initial});
  final String initial;

  @override
  State<_OwnNameDialog> createState() => _OwnNameDialogState();
}

class _OwnNameDialogState extends State<_OwnNameDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  String? _group;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Exercício próprio'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _group,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Grupo muscular *'),
          items: [
            for (final g in ownExerciseMuscleGroups)
              DropdownMenuItem(value: g, child: Text(g)),
          ],
          onChanged: (g) => setState(() => _group = g),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _group == null || _controller.text.trim().isEmpty
            ? null
            : () => Navigator.pop(
                context,
                ImportChoice.own(_controller.text.trim(), muscleGroup: _group!),
              ),
        child: const Text('Criar'),
      ),
    ],
  );
}
