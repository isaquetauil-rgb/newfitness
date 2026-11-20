import 'package:flutter_test/flutter_test.dart';
import 'package:newfitness/features/exercises/presentation/exercise_form_controller.dart';

void main() {
  test('exercício novo exige nome e grupo muscular', () {
    final form = ExerciseFormController();
    expect(form.validationError, 'Dê um nome ao exercício.');
    form.nameCtrl.text = 'Remada no banco';
    expect(form.validationError, contains('grupo muscular'));
    expect(form.isValid, isFalse);
    form.muscleGroupCtrl.text = 'Costas';
    expect(form.validationError, isNull);
    expect(form.isValid, isTrue);
    expect(form.buildExercise(id: 'x', videoUrl: '').muscleGroup, 'Costas');
    form.dispose();
  });
}
