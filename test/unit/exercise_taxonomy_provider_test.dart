import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:newfitness/features/exercises/logic/exercise_taxonomy_provider.dart';
import 'package:newfitness/shared/models/equipment_item.dart';
import 'package:newfitness/shared/models/muscle_group.dart';
import 'package:newfitness/shared/models/sample_taxonomy.dart';

import '../helpers/mocks.dart';

void main() {
  late MockFirestoreService firestoreService;
  late StreamController<List<MuscleGroup>> muscleGroupsController;
  late StreamController<List<EquipmentItem>> equipmentController;

  setUpAll(() {
    registerFallbackValue(const MuscleGroup(id: '', name: ''));
    registerFallbackValue(const EquipmentItem(id: '', name: ''));
  });

  setUp(() {
    firestoreService = MockFirestoreService();
    muscleGroupsController = StreamController<List<MuscleGroup>>.broadcast();
    equipmentController = StreamController<List<EquipmentItem>>.broadcast();
    when(() => firestoreService.watchMuscleGroups())
        .thenAnswer((_) => muscleGroupsController.stream);
    when(() => firestoreService.watchEquipment())
        .thenAnswer((_) => equipmentController.stream);
    when(() => firestoreService.saveMuscleGroup(any()))
        .thenAnswer((_) async {});
    when(() => firestoreService.saveEquipment(any())).thenAnswer((_) async {});
  });

  tearDown(() {
    muscleGroupsController.close();
    equipmentController.close();
  });

  test(
    'semeia a taxonomia padrão quando a coleção do Firestore está vazia',
    () async {
      ExerciseTaxonomyProvider(firestoreService: firestoreService);
      muscleGroupsController.add(const []);
      equipmentController.add(const []);
      await Future<void>.delayed(Duration.zero);

      verify(() => firestoreService.saveMuscleGroup(any()))
          .called(sampleMuscleGroups.length);
      verify(() => firestoreService.saveEquipment(any()))
          .called(sampleEquipment.length);
    },
  );

  test(
    'NÃO sobrescreve itens já existentes — preserva edições feitas pelo admin '
    'mesmo quando o nome difere do padrão de fábrica',
    () async {
      ExerciseTaxonomyProvider(firestoreService: firestoreService);
      // Simula um grupo muscular já existente no Firestore, renomeado pelo
      // admin (nome diferente do que está em sampleMuscleGroups) — isso
      // reproduz o cenário do bug corrigido: re-sincronizar sempre teria
      // revertido esse nome de volta ao padrão a cada abertura do app.
      muscleGroupsController.add(const [
        MuscleGroup(id: 'peito', name: 'Peitoral (editado)'),
      ]);
      equipmentController.add(const [
        EquipmentItem(id: 'barra', name: 'Barra olímpica'),
      ]);
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => firestoreService.saveMuscleGroup(any()));
      verifyNever(() => firestoreService.saveEquipment(any()));
    },
  );

  test(
    'expõe a lista recebida do Firestore via muscleGroups/equipment',
    () async {
      final provider = ExerciseTaxonomyProvider(
        firestoreService: firestoreService,
      );
      const groups = [MuscleGroup(id: 'peito', name: 'Peito')];
      const items = [EquipmentItem(id: 'barra', name: 'Barra')];

      muscleGroupsController.add(groups);
      equipmentController.add(items);
      await Future<void>.delayed(Duration.zero);

      expect(provider.muscleGroups, groups);
      expect(provider.equipment, items);
    },
  );

  test(
    'saveMuscleGroup e deleteMuscleGroup delegam ao FirestoreService',
    () async {
      when(() => firestoreService.deleteMuscleGroup(any()))
          .thenAnswer((_) async {});
      final provider = ExerciseTaxonomyProvider(
        firestoreService: firestoreService,
      );
      const group = MuscleGroup(id: 'costas', name: 'Costas');

      await provider.saveMuscleGroup(group);
      await provider.deleteMuscleGroup('costas');

      verify(() => firestoreService.saveMuscleGroup(group)).called(1);
      verify(() => firestoreService.deleteMuscleGroup('costas')).called(1);
    },
  );

  test('saveEquipment e deleteEquipment delegam ao FirestoreService', () async {
    when(() => firestoreService.deleteEquipment(any()))
        .thenAnswer((_) async {});
    final provider = ExerciseTaxonomyProvider(
      firestoreService: firestoreService,
    );
    const item = EquipmentItem(id: 'polia', name: 'Polia');

    await provider.saveEquipment(item);
    await provider.deleteEquipment('polia');

    verify(() => firestoreService.saveEquipment(item)).called(1);
    verify(() => firestoreService.deleteEquipment('polia')).called(1);
  });
}
