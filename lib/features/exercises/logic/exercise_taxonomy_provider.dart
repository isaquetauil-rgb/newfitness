import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:newfitness/core/di/injector.dart';
import 'package:newfitness/core/logging/app_logger.dart';
import 'package:newfitness/shared/models/equipment_item.dart';
import 'package:newfitness/shared/models/muscle_group.dart';
import 'package:newfitness/shared/models/sample_taxonomy.dart';
import 'package:newfitness/shared/services/firestore_service.dart';

final _log = AppLogger.of('ExerciseTaxonomyProvider');

/// Mantém em cache as coleções de referência `muscle_groups` e `equipment`
/// — a taxonomia usada pelos formulários de exercício (dropdown/autocomplete
/// em vez de texto solto) e pelos filtros da biblioteca. Faz seed de uma
/// lista padrão no Firestore só quando a coleção ainda está vazia (nunca
/// re-escreve por cima de itens que já existem) — diferente do padrão de
/// `ExerciseProvider` (que resincroniza sempre): aqui o admin edita nome e
/// descrição pela tela de administração, e essas edições precisam
/// sobreviver a um novo lançamento do app.
class ExerciseTaxonomyProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;
  StreamSubscription<List<MuscleGroup>>? _muscleGroupsSub;
  StreamSubscription<List<EquipmentItem>>? _equipmentSub;

  bool _seededMuscleGroups = false;
  bool _seededEquipment = false;

  ExerciseTaxonomyProvider({FirestoreService? firestoreService})
    : _firestoreService = firestoreService ?? getIt<FirestoreService>() {
    _subscribe();
  }

  void _subscribe() {
    _muscleGroupsSub?.cancel();
    _equipmentSub?.cancel();
    _muscleGroupsSub = _firestoreService.watchMuscleGroups().listen((list) {
      _muscleGroups = list;
      notifyListeners();
      if (!_seededMuscleGroups) {
        _seededMuscleGroups = true;
        if (list.isEmpty) _seedMuscleGroups();
      }
    }, onError: (_) {});
    _equipmentSub = _firestoreService.watchEquipment().listen((list) {
      _equipment = list;
      notifyListeners();
      if (!_seededEquipment) {
        _seededEquipment = true;
        if (list.isEmpty) _seedEquipment();
      }
    }, onError: (_) {});
  }

  /// Refaz as assinaturas quando o usuário logado muda (ver `app.dart`) —
  /// um listener que recebeu permission-denied no logout não volta sozinho.
  void restart() {
    _seededMuscleGroups = false;
    _seededEquipment = false;
    _subscribe();
  }

  List<MuscleGroup> _muscleGroups = [];
  List<EquipmentItem> _equipment = [];

  List<MuscleGroup> get muscleGroups =>
      _muscleGroups.isNotEmpty ? _muscleGroups : sampleMuscleGroups;
  List<EquipmentItem> get equipment =>
      _equipment.isNotEmpty ? _equipment : sampleEquipment;

  /// Só roda quando a coleção `muscle_groups` está genuinamente vazia (ver
  /// listener acima) — uma vez semeada, nunca mais escreve por cima do que
  /// o admin já editou.
  Future<void> _seedMuscleGroups() async {
    try {
      for (final group in sampleMuscleGroups) {
        await _firestoreService.saveMuscleGroup(group);
      }
    } catch (e, st) {
      _log.warning('Falha ao semear grupos musculares padrão', e, st);
    }
  }

  Future<void> _seedEquipment() async {
    try {
      for (final item in sampleEquipment) {
        await _firestoreService.saveEquipment(item);
      }
    } catch (e, st) {
      _log.warning('Falha ao semear equipamentos padrão', e, st);
    }
  }

  Future<void> saveMuscleGroup(MuscleGroup group) =>
      _firestoreService.saveMuscleGroup(group);

  Future<void> deleteMuscleGroup(String id) =>
      _firestoreService.deleteMuscleGroup(id);

  Future<void> saveEquipment(EquipmentItem item) =>
      _firestoreService.saveEquipment(item);

  Future<void> deleteEquipment(String id) =>
      _firestoreService.deleteEquipment(id);

  @override
  void dispose() {
    _muscleGroupsSub?.cancel();
    _equipmentSub?.cancel();
    super.dispose();
  }
}
