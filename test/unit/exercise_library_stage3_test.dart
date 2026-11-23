import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:newfitness/shared/models/exercise.dart';
import 'package:newfitness/shared/models/sample_exercise_stage3.dart';
import 'package:newfitness/shared/models/sample_exercises.dart';

void main() {
  final byId = {for (final e in sampleExercises) e.id: e};
  final fichas = jsonDecode(
    File('tool/biblioteca/etapa3_fichas.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final novos = (fichas['novos'] as Map).keys.cast<String>().toSet();

  test('Dart gerado está em dia com etapa3_fichas.json', () {
    expect(stage3NewExercises.map((e) => e.id).toSet(), novos);
    expect(
      stage3ExerciseFills.keys.toSet(),
      (fichas['existentes'] as Map).keys.toSet(),
    );
  });

  test('123 exercícios gerais (71 + 52 novos), sem IDs ou nomes repetidos', () {
    expect(novos.length, 52);
    expect(sampleExercises.length, 123);
    expect(byId.length, 123);
    final names = sampleExercises.map((e) => e.name.toLowerCase()).toSet();
    expect(names.length, 123);
    for (final id in stage3ExerciseFills.keys) {
      expect(novos, isNot(contains(id)), reason: 'novo não sobrescreve $id');
    }
  });

  test('toda ficha tem erros comuns, cuidados, tags e revisão pendente', () {
    for (final e in sampleExercises) {
      expect(e.commonMistakes, isNotEmpty, reason: e.id);
      expect(e.careNotes.trim(), isNotEmpty, reason: e.id);
      expect(e.searchTags, isNotEmpty, reason: e.id);
      expect(e.professionalReviewPending, isTrue, reason: e.id);
    }
  });

  test('alternativas só apontam para exercícios que existem', () {
    for (final e in sampleExercises) {
      expect(e.alternativeExerciseIds, isNotEmpty, reason: e.id);
      for (final alt in e.alternativeExerciseIds) {
        expect(byId.containsKey(alt), isTrue, reason: '${e.id} -> $alt');
        expect(alt, isNot(e.id));
      }
    }
  });

  test('alternativas curadas antes continuam as mesmas', () {
    expect(byId['dumbbell_bench_press']!.alternativeExerciseIds, [
      'bench_press',
      'machine_chest_press',
      'incline_dumbbell_press',
      'push_up',
    ]);
  });

  test('novos: ficha completa, sem vídeo nem imagem inventados', () {
    for (final id in novos) {
      final e = byId[id]!;
      expect(e.videoUrl, isEmpty, reason: id);
      expect(e.imageUrls, isEmpty, reason: id);
      expect(e.description.trim(), isNotEmpty, reason: id);
      expect(e.instructions.length, greaterThanOrEqualTo(3), reason: id);
      expect(e.alternateName.trim(), isNotEmpty, reason: id);
      expect(e.movementPattern.trim(), isNotEmpty, reason: id);
      expect(exerciseDifficultyLevels, contains(e.difficultyLevel));
      expect(e.defaultSets, isNotNull, reason: id);
      expect(e.defaultRestSeconds, isNotNull, reason: id);
      if (e.tracksDuration) {
        expect(e.defaultDurationSeconds, isNotNull, reason: id);
      } else {
        expect(e.defaultReps.trim(), isNotEmpty, reason: id);
      }
    }
  });

  test('cardio e canoa são por tempo; unilaterais marcados', () {
    for (final id in [
      'stationary_bike',
      'elliptical',
      'rowing_machine',
      'stair_climber',
      'treadmill_run_walk',
      'hollow_hold',
    ]) {
      expect(byId[id]!.tracksDuration, isTrue, reason: id);
    }
    for (final id in [
      'single_arm_cable_row',
      'cable_external_rotation',
      'concentration_curl',
      'triceps_kickback',
      'single_leg_extension',
      'smith_lunge',
      'single_leg_curl',
      'single_leg_hip_thrust',
      'ankle_weight_kickback',
      'cable_hip_abduction',
      'single_leg_calf_raise',
      'single_arm_overhead_triceps_extension',
    ]) {
      expect(byId[id]!.isUnilateral, isTrue, reason: id);
    }
    expect(byId['alternating_dumbbell_curl']!.isUnilateral, isFalse);
  });

  test('tríceps com corda e com barra são exercícios separados', () {
    final corda = byId['triceps_pushdown']!;
    final barra = byId['triceps_bar_pushdown']!;
    expect(corda.name, 'Tríceps na polia com corda');
    expect(corda.videoUrl, isNotEmpty); // o vídeo atual já é com corda
    expect(barra.name, 'Tríceps na polia com barra');
    expect(barra.videoUrl, isEmpty);
    expect(corda.alternativeExerciseIds, contains('triceps_bar_pushdown'));
    // Nenhuma ficha mistura corda e barra.
    for (final e in sampleExercises) {
      final d = e.description.toLowerCase();
      expect(
        d.contains('corda ou barra') || d.contains('barra ou corda'),
        isFalse,
        reason: e.id,
      );
    }
  });

  test('"Roda abdominal" é equipamento da taxonomia e usado na roda', () {
    expect(canonicalEquipment, contains('Roda abdominal'));
    expect(canonicalEquipmentName('ab wheel'), 'Roda abdominal');
    expect(byId['ab_wheel_rollout']!.equipment, 'Roda abdominal');
  });

  test('busca acha nomes que ficaram de fora como tags dos existentes', () {
    expect(
      byId['close_grip_lat_pulldown']!.searchTags,
      contains('puxada neutra'),
    );
    expect(byId['leg_raise']!.searchTags, contains('abdominal infra'));
    expect(byId['cable_crossover']!.searchTags, contains('crossover alto'));
    expect(byId['triceps_pushdown']!.searchTags, contains('tríceps corda'));
  });
}
