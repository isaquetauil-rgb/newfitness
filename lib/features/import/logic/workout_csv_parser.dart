/// Leitura dos CSVs exportados pelo Hevy e pelo Strong. Lógica pura: sem
/// Flutter e sem Firebase. Não usa nem consulta código de outros projetos —
/// só o formato público dos arquivos.
library;

import 'package:newfitness/shared/models/workout_set.dart';
import 'package:newfitness/shared/utils/one_rep_max.dart';

enum ImportSource {
  hevy('Hevy'),
  strong('Strong');

  const ImportSource(this.label);
  final String label;
}

/// Unidade do peso no arquivo do Strong (o arquivo não diz qual é).
enum WeightUnit { kg, lb }

const double _lbToKg = 0.45359237;

class ImportedSet {
  const ImportedSet({
    this.type = SetType.normal,
    this.reps = 0,
    this.weightKg = 0,
    this.seconds = 0,
  });

  final SetType type;
  final int reps;
  final double weightKg;
  final int seconds;
}

class ImportedExercise {
  ImportedExercise(this.name);
  final String name;
  final List<ImportedSet> sets = [];
}

class ImportedWorkout {
  ImportedWorkout({
    required this.source,
    required this.title,
    required this.start,
    this.durationSeconds = 0,
  });

  final ImportSource source;
  final String title;
  final DateTime start;
  int durationSeconds;
  final List<ImportedExercise> exercises = [];

  /// Identidade estável no arquivo: o mesmo treino exportado de novo tem a
  /// mesma chave (base para não duplicar).
  String get key =>
      '${source.name}|${start.toIso8601String()}|${title.trim().toLowerCase()}';

  int get setCount => exercises.fold(0, (n, e) => n + e.sets.length);
}

class CsvImportResult {
  const CsvImportResult({
    required this.source,
    required this.workouts,
    required this.skippedRows,
    required this.unitFromFile,
  });

  final ImportSource source;

  /// Do mais antigo para o mais recente.
  final List<ImportedWorkout> workouts;

  /// Linhas ignoradas (sem data, série vazia, descanso do Strong...).
  final int skippedRows;

  /// O próprio arquivo diz a unidade (Hevy sempre; Strong só às vezes).
  final bool unitFromFile;

  /// Nomes de exercício distintos, na ordem em que aparecem.
  List<String> get exerciseNames => {
    for (final w in workouts)
      for (final e in w.exercises) e.name,
  }.toList();
}

/// Lê o CSV (Hevy ou Strong, separado por vírgula ou ponto e vírgula).
/// [strongUnit]: unidade do peso do Strong quando o arquivo não informa.
/// Lança [FormatException] (mensagem em português) se não reconhecer.
CsvImportResult parseWorkoutCsv(
  String text, {
  WeightUnit strongUnit = WeightUnit.kg,
}) {
  final rows = parseCsvRows(text.replaceFirst('﻿', ''));
  if (rows.isEmpty) {
    throw const FormatException('O arquivo está vazio.');
  }
  final header = [for (final h in rows.first) h.trim().toLowerCase()];
  final body = rows.skip(1).where((r) => r.any((c) => c.trim().isNotEmpty));
  if (header.contains('exercise_title') && header.contains('start_time')) {
    return _parseHevy(header, body);
  }
  if (header.contains('exercise name') && header.contains('date')) {
    return _parseStrong(header, body, strongUnit);
  }
  throw const FormatException(
    'Arquivo não reconhecido. Use o CSV exportado pelo Hevy ou pelo Strong.',
  );
}

// ---------- Hevy ----------

CsvImportResult _parseHevy(List<String> header, Iterable<List<String>> rows) {
  final col = _columns(header);
  final inLb = !header.contains('weight_kg') && header.contains('weight_lbs');
  final workouts = <String, ImportedWorkout>{};
  var skipped = 0;

  for (final r in rows) {
    final start = parseHevyDate(_get(r, col['start_time']));
    final name = _get(r, col['exercise_title']).trim();
    if (start == null || name.isEmpty) {
      skipped++;
      continue;
    }
    final title = _get(r, col['title']).trim();
    final w = workouts.putIfAbsent(
      '$title|$start',
      () => ImportedWorkout(
        source: ImportSource.hevy,
        title: title.isEmpty ? 'Treino importado' : title,
        start: start,
      ),
    );
    final end = parseHevyDate(_get(r, col['end_time']));
    if (end != null && end.isAfter(start)) {
      w.durationSeconds = end.difference(start).inSeconds;
    }
    final rawWeight = _num(_get(r, col[inLb ? 'weight_lbs' : 'weight_kg']));
    final set = ImportedSet(
      type: switch (_get(r, col['set_type']).trim().toLowerCase()) {
        'warmup' => SetType.warmup,
        'dropset' || 'drop' => SetType.drop,
        'failure' => SetType.failure,
        _ => SetType.normal,
      },
      reps: _num(_get(r, col['reps'])).round(),
      weightKg: roundKg(inLb ? rawWeight * _lbToKg : rawWeight),
      seconds: _num(_get(r, col['duration_seconds'])).round(),
    );
    if (!_addSet(w, name, set)) skipped++;
  }
  return CsvImportResult(
    source: ImportSource.hevy,
    workouts: _sorted(workouts.values),
    skippedRows: skipped,
    unitFromFile: true,
  );
}

const _months = {
  'jan': 1,
  'feb': 2,
  'fev': 2,
  'mar': 3,
  'apr': 4,
  'abr': 4,
  'may': 5,
  'mai': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'ago': 8,
  'sep': 9,
  'set': 9,
  'oct': 10,
  'out': 10,
  'nov': 11,
  'dec': 12,
  'dez': 12,
};

/// "15 Jan 2024, 18:02" (Hevy) ou data ISO. `null` se não reconhecer.
DateTime? parseHevyDate(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  final m = RegExp(
    r'^(\d{1,2})\s+([A-Za-zçÇ]{3})[a-zç]*\.?\s+(\d{4}),?\s+(\d{1,2}):(\d{2})',
  ).firstMatch(s);
  if (m != null) {
    final month = _months[m.group(2)!.toLowerCase()];
    if (month == null) return null;
    return DateTime(
      int.parse(m.group(3)!),
      month,
      int.parse(m.group(1)!),
      int.parse(m.group(4)!),
      int.parse(m.group(5)!),
    );
  }
  return DateTime.tryParse(s);
}

// ---------- Strong ----------

CsvImportResult _parseStrong(
  List<String> header,
  Iterable<List<String>> rows,
  WeightUnit unit,
) {
  final col = _columns(header);
  final unitCol = col['weight unit'];
  final workouts = <String, ImportedWorkout>{};
  var skipped = 0;

  for (final r in rows) {
    final start = DateTime.tryParse(_get(r, col['date']).trim());
    final name = _get(r, col['exercise name']).trim();
    final order = _get(r, col['set order']).trim().toUpperCase();
    // Linhas de descanso ("Rest Timer") e afins não são séries.
    final type = switch (order) {
      'W' => SetType.warmup,
      'D' => SetType.drop,
      'F' => SetType.failure,
      _ when int.tryParse(order) != null => SetType.normal,
      _ => null,
    };
    if (start == null || name.isEmpty || type == null) {
      skipped++;
      continue;
    }
    final title = _get(r, col['workout name']).trim();
    final w = workouts.putIfAbsent(
      '$title|$start',
      () => ImportedWorkout(
        source: ImportSource.strong,
        title: title.isEmpty ? 'Treino importado' : title,
        start: start,
        durationSeconds: parseStrongDuration(_get(r, col['duration'])),
      ),
    );
    final rowUnit = _get(r, unitCol).trim().toLowerCase();
    final inLb = rowUnit.isNotEmpty
        ? rowUnit.startsWith('lb')
        : unit == WeightUnit.lb;
    final rawWeight = _num(_get(r, col['weight']));
    final set = ImportedSet(
      type: type,
      reps: _num(_get(r, col['reps'])).round(),
      weightKg: roundKg(inLb ? rawWeight * _lbToKg : rawWeight),
      seconds: _num(_get(r, col['seconds'])).round(),
    );
    if (!_addSet(w, name, set)) skipped++;
  }
  return CsvImportResult(
    source: ImportSource.strong,
    workouts: _sorted(workouts.values),
    skippedRows: skipped,
    unitFromFile: unitCol != null,
  );
}

/// "1h 8m", "45m", "38s", "1h" → segundos.
int parseStrongDuration(String raw) {
  var total = 0;
  for (final m in RegExp(r'(\d+)\s*([hms])').allMatches(raw.toLowerCase())) {
    final n = int.parse(m.group(1)!);
    total += switch (m.group(2)) {
      'h' => n * 3600,
      'm' => n * 60,
      _ => n,
    };
  }
  return total;
}

// ---------- comum ----------

/// Junta a série ao exercício (o mesmo nome seguido vira um exercício só).
/// Série sem reps, sem carga e sem tempo é ignorada.
bool _addSet(ImportedWorkout w, String name, ImportedSet set) {
  if (set.reps <= 0 && set.weightKg <= 0 && set.seconds <= 0) return false;
  var exercise = w.exercises.isEmpty ? null : w.exercises.last;
  if (exercise == null || exercise.name != name) {
    exercise = ImportedExercise(name);
    w.exercises.add(exercise);
  }
  exercise.sets.add(set);
  return true;
}

List<ImportedWorkout> _sorted(Iterable<ImportedWorkout> list) =>
    list.where((w) => w.exercises.isNotEmpty).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

Map<String, int> _columns(List<String> header) => {
  for (var i = 0; i < header.length; i++) header[i]: i,
};

String _get(List<String> row, int? i) =>
    i == null || i >= row.length ? '' : row[i];

/// "62.5", "62,5" ou vazio (= 0).
double _num(String raw) =>
    double.tryParse(raw.trim().replaceAll(',', '.')) ?? 0;

/// CSV com aspas (RFC 4180). O separador (vírgula ou ponto e vírgula) é o
/// que mais aparece na primeira linha, fora de aspas.
List<List<String>> parseCsvRows(String text) {
  final firstLine = text.split('\n').first;
  final unquoted = firstLine.replaceAll(RegExp(r'"[^"]*"'), '');
  final sep = ';'.allMatches(unquoted).length > ','.allMatches(unquoted).length
      ? ';'
      : ',';

  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell.write(c);
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == sep) {
      row.add(cell.toString());
      cell.clear();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(cell.toString());
      cell.clear();
      rows.add(row);
      row = <String>[];
    } else {
      cell.write(c);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    rows.add(row);
  }
  return rows;
}
