import 'package:flutter/material.dart';

import 'package:newfitness/shared/models/exercise.dart';

/// Estado compartilhado do formulário de exercício — usado tanto pelo
/// cadastro do admin (`AdminExerciseFormScreen`, biblioteca global) quanto
/// pelo do instrutor (`CustomExerciseFormScreen`, biblioteca privada), que
/// diferem só em como tratam o vídeo e onde salvam. Mantém todos os
/// `TextEditingController`s (evita recriá-los a cada build) e os campos de
/// seleção (chips/switches), notificando a UI (`ExerciseFormFields`) quando
/// algo muda.
class ExerciseFormController extends ChangeNotifier {
  ExerciseFormController([this.existing]) {
    nameCtrl = TextEditingController(text: existing?.name ?? '');
    alternateNameCtrl = TextEditingController(
      text: existing?.alternateName ?? '',
    );
    muscleGroupCtrl = TextEditingController(text: existing?.muscleGroup ?? '');
    equipmentCtrl = TextEditingController(text: existing?.equipment ?? '');
    descriptionCtrl = TextEditingController(text: existing?.description ?? '');
    instructionsCtrl = TextEditingController(
      text: existing?.instructions.join('\n') ?? '',
    );
    executionNotesCtrl = TextEditingController(
      text: existing?.executionNotes ?? '',
    );
    commonMistakesCtrl = TextEditingController(
      text: existing?.commonMistakes.join('\n') ?? '',
    );
    careNotesCtrl = TextEditingController(text: existing?.careNotes ?? '');
    movementPatternCtrl = TextEditingController(
      text: existing?.movementPattern ?? '',
    );
    secondaryMusclesCtrl = TextEditingController(
      text: existing?.secondaryMuscles.join(', ') ?? '',
    );
    objectivesCtrl = TextEditingController(
      text: existing?.objectives.join(', ') ?? '',
    );
    searchTagsCtrl = TextEditingController(
      text: existing?.searchTags.join(', ') ?? '',
    );
    imageUrlsCtrl = TextEditingController(
      text: existing?.imageUrls.join('\n') ?? '',
    );
    defaultSetsCtrl = TextEditingController(
      text: existing?.defaultSets?.toString() ?? '',
    );
    defaultRepsCtrl = TextEditingController(text: existing?.defaultReps ?? '');
    defaultRestSecondsCtrl = TextEditingController(
      text: existing?.defaultRestSeconds?.toString() ?? '',
    );
    executionTempoSecondsCtrl = TextEditingController(
      text: existing?.executionTempoSeconds?.toString() ?? '',
    );
    defaultLoadCtrl = TextEditingController(
      text: existing?.defaultLoad?.toString() ?? '',
    );
    defaultDistanceMetersCtrl = TextEditingController(
      text: existing?.defaultDistanceMeters?.toString() ?? '',
    );
    defaultDurationSecondsCtrl = TextEditingController(
      text: existing?.defaultDurationSeconds?.toString() ?? '',
    );
    estimatedCaloriesPerMinuteCtrl = TextEditingController(
      text: existing?.estimatedCaloriesPerMinute?.toString() ?? '',
    );

    _category = existing?.category ?? '';
    _difficultyLevel = existing?.difficultyLevel ?? '';
    _loadUnit = existing?.loadUnit ?? '';
    _kineticChain = existing?.kineticChain ?? '';
    _tracksDistance = existing?.tracksDistance ?? false;
    _tracksDuration = existing?.tracksDuration ?? false;
    _isUnilateral = existing?.isUnilateral ?? false;
    variationIds = [...?existing?.variationExerciseIds];
    alternativeIds = [...?existing?.alternativeExerciseIds];
  }

  final Exercise? existing;

  late final TextEditingController nameCtrl;
  late final TextEditingController alternateNameCtrl;
  late final TextEditingController muscleGroupCtrl;
  late final TextEditingController equipmentCtrl;
  late final TextEditingController descriptionCtrl;
  late final TextEditingController instructionsCtrl;
  late final TextEditingController executionNotesCtrl;
  late final TextEditingController commonMistakesCtrl;
  late final TextEditingController careNotesCtrl;
  late final TextEditingController movementPatternCtrl;
  late final TextEditingController secondaryMusclesCtrl;
  late final TextEditingController objectivesCtrl;
  late final TextEditingController searchTagsCtrl;
  late final TextEditingController imageUrlsCtrl;
  late final TextEditingController defaultSetsCtrl;
  late final TextEditingController defaultRepsCtrl;
  late final TextEditingController defaultRestSecondsCtrl;
  late final TextEditingController executionTempoSecondsCtrl;
  late final TextEditingController defaultLoadCtrl;
  late final TextEditingController defaultDistanceMetersCtrl;
  late final TextEditingController defaultDurationSecondsCtrl;
  late final TextEditingController estimatedCaloriesPerMinuteCtrl;

  final muscleGroupFocusNode = FocusNode();
  final equipmentFocusNode = FocusNode();

  late String _category;
  String get category => _category;
  set category(String value) {
    _category = value;
    notifyListeners();
  }

  late String _difficultyLevel;
  String get difficultyLevel => _difficultyLevel;
  set difficultyLevel(String value) {
    _difficultyLevel = value;
    notifyListeners();
  }

  late String _loadUnit;
  String get loadUnit => _loadUnit;
  set loadUnit(String value) {
    _loadUnit = value;
    notifyListeners();
  }

  late String _kineticChain;
  String get kineticChain => _kineticChain;
  set kineticChain(String value) {
    _kineticChain = value;
    notifyListeners();
  }

  late bool _tracksDistance;
  bool get tracksDistance => _tracksDistance;
  set tracksDistance(bool value) {
    _tracksDistance = value;
    notifyListeners();
  }

  late bool _tracksDuration;
  bool get tracksDuration => _tracksDuration;
  set tracksDuration(bool value) {
    _tracksDuration = value;
    notifyListeners();
  }

  late bool _isUnilateral;
  bool get isUnilateral => _isUnilateral;
  set isUnilateral(bool value) {
    _isUnilateral = value;
    notifyListeners();
  }

  late List<String> variationIds;
  late List<String> alternativeIds;

  void setVariationIds(List<String> ids) {
    variationIds = ids;
    notifyListeners();
  }

  void setAlternativeIds(List<String> ids) {
    alternativeIds = ids;
    notifyListeners();
  }

  List<String> _splitCsv(String text) =>
      text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  List<String> _splitLines(String text) =>
      text.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  bool get isValid => nameCtrl.text.trim().isNotEmpty;

  Exercise buildExercise({required String id, required String videoUrl}) {
    return Exercise(
      id: id,
      name: nameCtrl.text.trim(),
      muscleGroup: muscleGroupCtrl.text.trim(),
      equipment: equipmentCtrl.text.trim(),
      description: descriptionCtrl.text.trim(),
      videoUrl: videoUrl,
      thumbnailUrl: existing?.thumbnailUrl,
      instructions: _splitLines(instructionsCtrl.text),
      alternateName: alternateNameCtrl.text.trim(),
      category: category,
      executionNotes: executionNotesCtrl.text.trim(),
      commonMistakes: _splitLines(commonMistakesCtrl.text),
      careNotes: careNotesCtrl.text.trim(),
      defaultSets: int.tryParse(defaultSetsCtrl.text.trim()),
      defaultReps: defaultRepsCtrl.text.trim(),
      executionTempoSeconds: int.tryParse(
        executionTempoSecondsCtrl.text.trim(),
      ),
      defaultRestSeconds: int.tryParse(defaultRestSecondsCtrl.text.trim()),
      defaultLoad: double.tryParse(
        defaultLoadCtrl.text.trim().replaceAll(',', '.'),
      ),
      loadUnit: loadUnit,
      tracksDistance: tracksDistance,
      defaultDistanceMeters: double.tryParse(
        defaultDistanceMetersCtrl.text.trim().replaceAll(',', '.'),
      ),
      tracksDuration: tracksDuration,
      defaultDurationSeconds: int.tryParse(
        defaultDurationSecondsCtrl.text.trim(),
      ),
      estimatedCaloriesPerMinute: double.tryParse(
        estimatedCaloriesPerMinuteCtrl.text.trim().replaceAll(',', '.'),
      ),
      imageUrls: _splitLines(imageUrlsCtrl.text),
      searchTags: _splitCsv(searchTagsCtrl.text),
      isUnilateral: isUnilateral,
      kineticChain: kineticChain,
      secondaryMuscles: _splitCsv(secondaryMusclesCtrl.text),
      movementPattern: movementPatternCtrl.text.trim(),
      difficultyLevel: difficultyLevel,
      objectives: _splitCsv(objectivesCtrl.text),
      variationExerciseIds: variationIds,
      alternativeExerciseIds: alternativeIds,
    );
  }

  @override
  void dispose() {
    for (final c in [
      nameCtrl,
      alternateNameCtrl,
      muscleGroupCtrl,
      equipmentCtrl,
      descriptionCtrl,
      instructionsCtrl,
      executionNotesCtrl,
      commonMistakesCtrl,
      careNotesCtrl,
      movementPatternCtrl,
      secondaryMusclesCtrl,
      objectivesCtrl,
      searchTagsCtrl,
      imageUrlsCtrl,
      defaultSetsCtrl,
      defaultRepsCtrl,
      defaultRestSecondsCtrl,
      executionTempoSecondsCtrl,
      defaultLoadCtrl,
      defaultDistanceMetersCtrl,
      defaultDurationSecondsCtrl,
      estimatedCaloriesPerMinuteCtrl,
    ]) {
      c.dispose();
    }
    muscleGroupFocusNode.dispose();
    equipmentFocusNode.dispose();
    super.dispose();
  }
}
