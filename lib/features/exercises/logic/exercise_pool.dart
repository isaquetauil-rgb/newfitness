import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:newfitness/features/auth/logic/auth_provider.dart';
import 'package:newfitness/features/exercises/logic/exercise_provider.dart';
import 'package:newfitness/features/instructor/logic/custom_exercise_provider.dart';
import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/models/sample_exercises.dart';
import 'package:newfitness/shared/models/user_profile.dart';

/// Junta a biblioteca global de exercícios com a biblioteca privada do
/// instrutor vinculado ao usuário logado (ou a própria, se ele for o
/// instrutor) — mesmo critério de visibilidade usado em
/// `ExercisePickerScreen`, reaproveitado aqui para alimentar a busca de
/// exercícios alternativos (ver `exercise_similarity.dart`).
Future<List<Exercise>> loadExercisePool(BuildContext context) async {
  final exerciseProvider = context.read<ExerciseProvider>();
  final global = exerciseProvider.exercises.isNotEmpty
      ? exerciseProvider.exercises
      : sampleExercises;

  final profile = context.read<AuthProvider>().profile;
  final customLibraryUid = profile == null
      ? null
      : profile.role == UserRole.instructor
      ? profile.uid
      : profile.instructorId;
  if (customLibraryUid == null) return global;

  final custom = await context
      .read<CustomExerciseProvider>()
      .watchExercises(customLibraryUid)
      .first;
  return [...custom, ...global];
}
