/// Transforma o CSV lido ([CsvImportResult]) em treinos do NewFitness:
/// casa os nomes com a biblioteca e evita duplicar. Lógica pura.
library;

import 'package:newfitness/features/exercises/logic/exercise_similarity.dart';
import 'package:newfitness/features/import/logic/workout_csv_parser.dart';
import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/models/logged_exercise.dart';
import 'package:newfitness/shared/models/workout.dart';
import 'package:newfitness/shared/models/workout_set.dart';

/// Para que exercício do app vai um nome do arquivo.
class ImportChoice {
  ImportChoice.library(Exercise e)
    : exerciseId = e.id,
      exerciseName = e.name,
      own = false;

  /// Exercício próprio do aluno (não está na biblioteca).
  ImportChoice.own(String name)
    : exerciseId = ownExerciseId(name),
      exerciseName = name.trim(),
      own = true;

  final String exerciseId;
  final String exerciseName;
  final bool own;
}

/// Id de exercício próprio: `own_` + nome sem acento/símbolo.
String ownExerciseId(String name) {
  final slug = name
      .toLowerCase()
      .replaceAll(RegExp('[áàâã]'), 'a')
      .replaceAll(RegExp('[éê]'), 'e')
      .replaceAll('í', 'i')
      .replaceAll(RegExp('[óôõ]'), 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp('[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return 'own_${slug.isEmpty ? 'exercicio' : slug}';
}

/// Casamentos automáticos: nome do arquivo → exercício da biblioteca, só
/// quando a semelhança passa de [autoNameMatchScore]. Os demais ficam de
/// fora (o aluno escolhe na prévia).
Map<String, ImportChoice> suggestChoices(
  List<String> names,
  List<Exercise> pool,
) {
  final out = <String, ImportChoice>{};
  for (final n in names) {
    final best = matchExercisesByName(n, pool, limit: 1);
    if (best.isNotEmpty && best.first.score >= autoNameMatchScore) {
      out[n] = ImportChoice.library(best.first.exercise);
    }
  }
  return out;
}

/// Hash FNV-1a de 32 bits (duas vezes, com sementes diferentes) em
/// hexadecimal: id estável a partir da chave.
String _hash(String text) {
  String fnv(int seed) {
    var h = seed;
    for (final unit in text.codeUnits) {
      h ^= unit;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }

  return fnv(0x811c9dc5) + fnv(0x01234567);
}

/// Id do documento do treino importado: o mesmo treino do mesmo arquivo
/// sempre gera o mesmo id (reimportar não duplica).
String importDocId(ImportedWorkout w) =>
    'import_${w.source.name}_${_hash(w.key)}';

class ImportPlan {
  const ImportPlan({required this.toSave, required this.duplicates});

  /// Treinos novos, do mais antigo para o mais recente.
  final List<Workout> toSave;

  /// Treinos do arquivo que já estavam no histórico (ignorados).
  final int duplicates;
}

/// Monta os treinos a gravar. [choices] precisa ter todos os nomes do
/// arquivo; [history] é o histórico atual (para não duplicar).
ImportPlan buildImport(
  CsvImportResult parsed,
  Map<String, ImportChoice> choices, {
  required String userId,
  required Iterable<Workout> history,
}) {
  final missing = parsed.exerciseNames.where((n) => !choices.containsKey(n));
  if (missing.isNotEmpty) {
    throw ArgumentError('Exercícios sem escolha: ${missing.join(', ')}');
  }
  final existingIds = {for (final w in history) w.id};
  final existingKeys = {
    for (final w in history)
      if (w.importKey != null) w.importKey!,
  };
  final toSave = <Workout>[];
  var duplicates = 0;
  for (final w in parsed.workouts) {
    final id = importDocId(w);
    if (existingIds.contains(id) || existingKeys.contains(w.key)) {
      duplicates++;
      continue;
    }
    toSave.add(
      Workout(
        id: id,
        userId: userId,
        date: w.start,
        name: w.title,
        durationSeconds: w.durationSeconds,
        importedFrom: w.source.name,
        importKey: w.key,
        exercises: [
          for (final e in w.exercises)
            LoggedExercise(
              exerciseId: choices[e.name]!.exerciseId,
              exerciseName: choices[e.name]!.exerciseName,
              sets: [
                for (final s in e.sets)
                  WorkoutSet(
                    reps: s.reps,
                    weightKg: s.weightKg,
                    seconds: s.seconds,
                    type: s.type,
                    completed: true,
                  ),
              ],
            ),
        ],
      ),
    );
  }
  return ImportPlan(toSave: toSave, duplicates: duplicates);
}
