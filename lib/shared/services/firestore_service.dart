import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/error/app_exception.dart';
import '../../core/logging/app_logger.dart';
import '../models/body_photo.dart';
import '../models/chat_message.dart';
import '../models/equipment_item.dart';
import '../models/exercise.dart';
import '../models/exercise_progress_record.dart';
import '../models/meal_photo.dart';
import '../models/announcement.dart';
import '../models/appointment.dart';
import '../models/muscle_group.dart';
import '../models/nutrition_message.dart';
import '../models/nutrition_plan.dart';
import '../models/physical_assessment.dart';
import '../models/plan_template.dart';
import '../models/reminder.dart';
import '../models/subscription.dart';
import '../models/training_plan.dart';
import '../models/user_profile.dart';
import '../models/workout.dart';

final _log = AppLogger.of('FirestoreService');

/// Encapsula toda a leitura/escrita no Cloud Firestore.
///
/// Coleções usadas (ver [FirestorePaths]):
///   users/{uid}                -> perfil do usuário
///   users/{uid}/workouts/{id}  -> treinos daquele usuário
///   exercises/{id}             -> biblioteca de exercícios (global)
class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<T> _guard<T>(String op, Future<T> Function() action) async {
    try {
      return await action();
    } catch (e, st) {
      _log.warning('Falha em "$op"', e, st);
      throw _mapError(op, e, st);
    }
  }

  Stream<T> _guardStream<T>(String op, Stream<T> stream) {
    return stream.handleError((Object e, StackTrace st) {
      _log.warning('Falha em "$op"', e, st);
      throw _mapError(op, e, st);
    });
  }

  AppException _mapError(String op, Object e, StackTrace st) {
    if (e is FirebaseException) {
      if (e.code == 'permission-denied') {
        return AuthException(
          'Você não tem permissão para fazer isso.',
          cause: e,
          stackTrace: st,
        );
      }
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        return NetworkException(
          'Sem conexão com o servidor. Tente novamente.',
          cause: e,
          stackTrace: st,
        );
      }
    }
    return UnknownException(
      'Erro ao executar "$op".',
      cause: e,
      stackTrace: st,
    );
  }

  // ---------- Perfil ----------

  Future<void> createUserProfile(UserProfile profile) {
    return _guard('createUserProfile', () {
      return _db
          .collection(FirestorePaths.users)
          .doc(profile.uid)
          .set(profile.toMap());
    });
  }

  Future<UserProfile?> getUserProfile(String uid) {
    return _guard('getUserProfile', () async {
      final doc = await _db.collection(FirestorePaths.users).doc(uid).get();
      if (!doc.exists) return null;
      return UserProfile.fromMap(uid, doc.data()!);
    });
  }

  /// Campos controlados pelo servidor/admin — nunca vão numa atualização
  /// feita pelo próprio usuário (as regras recusam qualquer mudança neles).
  static const _serverControlledFields = {
    'role',
    'instructorId',
    'nutritionistId',
    'inviteCode',
  };

  /// Atualiza os dados editáveis do perfil (nome, peso, altura...). Não
  /// envia papel/vínculos/código de convite: um perfil local desatualizado
  /// (ex: antes do `inviteCode` chegar da Cloud Function) não pode tentar
  /// sobrescrever esses campos — seria negado pelas regras.
  Future<void> updateUserProfile(UserProfile profile) {
    return _guard('updateUserProfile', () {
      final data = profile.toMap()
        ..removeWhere((key, _) => _serverControlledFields.contains(key));
      return _db
          .collection(FirestorePaths.users)
          .doc(profile.uid)
          .set(data, SetOptions(merge: true));
    });
  }

  /// Lista todos os usuários cadastrados — só o admin tem permissão para
  /// isso (ver `firestore.rules`).
  Stream<List<UserProfile>> watchAllUsers() {
    return _guardStream(
      'watchAllUsers',
      _db
          .collection(FirestorePaths.users)
          .orderBy('name')
          .snapshots()
          .map(
            (snap) => snap.docs
                .map((d) => UserProfile.fromMap(d.id, d.data()))
                .toList(),
          ),
    );
  }

  // ---------- Instrutor / Aluno ----------

  // O vínculo aluno -> instrutor/nutricionista (gravar `instructorId`/
  // `nutritionistId`) NÃO é mais feito por aqui — `firestore.rules` proíbe o
  // próprio usuário de alterar esses campos (só admin ou a Cloud Function
  // conseguem), exatamente para que um código de convite precise ser
  // validado no servidor antes de conceder o vínculo. Ver
  // `AuthProvider.linkToInstructor`/`linkToNutritionist`, que chamam a
  // Cloud Function `linkToProfessional` (`functions/src/linking.ts`).

  /// Alunos ATUALMENTE vinculados à nutricionista — mesmo critério de
  /// [watchStudents], com `nutritionistId`/`nutrition_students`.
  Stream<List<Map<String, dynamic>>> watchNutritionStudents(
    String nutritionistId,
  ) {
    return _guardStream(
      'watchNutritionStudents',
      _watchLinkedStudents(
        linkField: 'nutritionistId',
        professionalUid: nutritionistId,
        entriesPath: FirestorePaths.nutritionStudents(nutritionistId),
      ),
    );
  }

  /// Lista (com atualização em tempo real) os alunos ATUALMENTE vinculados
  /// a um instrutor.
  ///
  /// A fonte de verdade do vínculo é o perfil do aluno (`instructorId`) —
  /// é o que as regras usam para dar acesso. A subcoleção
  /// `users/{instructorId}/students` guarda só os dados do instrutor sobre
  /// cada aluno (notas, mensalidade, plano) e pode conter alunos que já
  /// trocaram de instrutor; por isso ela é usada apenas para completar os
  /// dados, nunca para decidir quem aparece na lista. Antes, um aluno que
  /// trocava de instrutor continuava aparecendo para o anterior (sem
  /// conseguir abrir nada, porque o acesso era negado).
  Stream<List<Map<String, dynamic>>> watchStudents(String instructorId) {
    return _guardStream(
      'watchStudents',
      _watchLinkedStudents(
        linkField: 'instructorId',
        professionalUid: instructorId,
        entriesPath: FirestorePaths.students(instructorId),
      ),
    );
  }

  Stream<List<Map<String, dynamic>>> _watchLinkedStudents({
    required String linkField,
    required String professionalUid,
    required String entriesPath,
  }) {
    // A regra de leitura de `users/{id}` aceita esta consulta porque o
    // filtro garante `resource.data.<linkField> == request.auth.uid`.
    final linked = _db
        .collection(FirestorePaths.users)
        .where(linkField, isEqualTo: professionalUid)
        .snapshots()
        .map(
          (snap) => [
            for (final d in snap.docs)
              {
                'uid': d.id,
                'name': d.data()['name'] as String? ?? '',
                'email': d.data()['email'] as String? ?? '',
              },
          ],
        );
    final entries = _db
        .collection(entriesPath)
        .snapshots()
        .map((snap) => {for (final d in snap.docs) d.id: d.data()});
    return combineLinkedStudents(linked, entries);
  }

  // ---------- Treinos ----------

  CollectionReference<Map<String, dynamic>> _workoutsRef(String uid) =>
      _db.collection(FirestorePaths.workouts(uid));

  Future<String> saveWorkout(Workout workout) {
    return _guard('saveWorkout', () async {
      final ref = _workoutsRef(workout.userId);
      if (workout.id.isEmpty) {
        final doc = await ref.add(workout.toMap());
        return doc.id;
      } else {
        await ref.doc(workout.id).set(workout.toMap());
        return workout.id;
      }
    });
  }

  Stream<List<Workout>> watchWorkouts(String uid) {
    return _guardStream(
      'watchWorkouts',
      _workoutsRef(uid)
          .orderBy('date', descending: true)
          .snapshots()
          .map(
            (snap) =>
                snap.docs.map((d) => Workout.fromMap(d.id, d.data())).toList(),
          ),
    );
  }

  Future<void> deleteWorkout(String uid, String workoutId) {
    return _guard(
      'deleteWorkout',
      () => _workoutsRef(uid).doc(workoutId).delete(),
    );
  }

  // ---------- Biblioteca de exercícios ----------

  Stream<List<Exercise>> watchExercises() {
    return _guardStream(
      'watchExercises',
      _db
          .collection(FirestorePaths.exercises)
          .orderBy('name')
          .snapshots()
          .map(
            (snap) =>
                snap.docs.map((d) => Exercise.fromMap(d.id, d.data())).toList(),
          ),
    );
  }

  Future<void> seedExercise(Exercise exercise) {
    return _guard('seedExercise', () {
      return _db
          .collection(FirestorePaths.exercises)
          .doc(exercise.id)
          .set(exercise.toMap(), SetOptions(merge: true));
    });
  }

  Future<void> deleteExercise(String id) {
    return _guard(
      'deleteExercise',
      () => _db.collection(FirestorePaths.exercises).doc(id).delete(),
    );
  }

  // ---------- Exercícios próprios do instrutor (biblioteca privada) ----------

  CollectionReference<Map<String, dynamic>> _customExercisesRef(
    String instructorUid,
  ) => _db.collection(FirestorePaths.customExercises(instructorUid));

  /// Biblioteca privada de exercícios de um instrutor — visível pra ele e
  /// (por regra do Firestore) pros próprios alunos vinculados, mas nunca pra
  /// outros instrutores. Diferente de `watchExercises` (global, curada pelo
  /// admin).
  Stream<List<Exercise>> watchCustomExercises(String instructorUid) {
    return _guardStream(
      'watchCustomExercises',
      _customExercisesRef(instructorUid)
          .orderBy('name')
          .snapshots()
          .map(
            (snap) =>
                snap.docs.map((d) => Exercise.fromMap(d.id, d.data())).toList(),
          ),
    );
  }

  Future<void> saveCustomExercise(String instructorUid, Exercise exercise) {
    return _guard('saveCustomExercise', () {
      return _customExercisesRef(instructorUid)
          .doc(exercise.id)
          .set(exercise.toMap(), SetOptions(merge: true));
    });
  }

  Future<void> deleteCustomExercise(String instructorUid, String exerciseId) {
    return _guard(
      'deleteCustomExercise',
      () => _customExercisesRef(instructorUid).doc(exerciseId).delete(),
    );
  }

  // ---------- Taxonomia (grupos musculares / equipamentos) ----------
  //
  // Coleções de referência curadas pelo admin — existir como coleção (em
  // vez de string solta) é o que permite adicionar um grupo muscular ou
  // equipamento novo sem alterar o código do app (ver `AdminTaxonomyScreen`).

  Stream<List<MuscleGroup>> watchMuscleGroups() {
    return _guardStream(
      'watchMuscleGroups',
      _db
          .collection(FirestorePaths.muscleGroups)
          .orderBy('name')
          .snapshots()
          .map(
            (snap) => snap.docs
                .map((d) => MuscleGroup.fromMap(d.id, d.data()))
                .toList(),
          ),
    );
  }

  Future<void> saveMuscleGroup(MuscleGroup group) {
    return _guard('saveMuscleGroup', () {
      return _db
          .collection(FirestorePaths.muscleGroups)
          .doc(group.id)
          .set(group.toMap(), SetOptions(merge: true));
    });
  }

  Future<void> deleteMuscleGroup(String id) {
    return _guard(
      'deleteMuscleGroup',
      () => _db.collection(FirestorePaths.muscleGroups).doc(id).delete(),
    );
  }

  Stream<List<EquipmentItem>> watchEquipment() {
    return _guardStream(
      'watchEquipment',
      _db
          .collection(FirestorePaths.equipment)
          .orderBy('name')
          .snapshots()
          .map(
            (snap) => snap.docs
                .map((d) => EquipmentItem.fromMap(d.id, d.data()))
                .toList(),
          ),
    );
  }

  Future<void> saveEquipment(EquipmentItem item) {
    return _guard('saveEquipment', () {
      return _db
          .collection(FirestorePaths.equipment)
          .doc(item.id)
          .set(item.toMap(), SetOptions(merge: true));
    });
  }

  Future<void> deleteEquipment(String id) {
    return _guard(
      'deleteEquipment',
      () => _db.collection(FirestorePaths.equipment).doc(id).delete(),
    );
  }

  // ---------- Evolução por exercício (progress_records) ----------

  /// Quantos pontos de histórico mantemos por exercício — o suficiente para
  /// um gráfico de evolução útil sem o documento crescer indefinidamente.
  static const _progressHistoryLimit = 50;

  Stream<List<ExerciseProgressRecord>> watchProgressRecords(String uid) {
    return _guardStream(
      'watchProgressRecords',
      _db
          .collection(FirestorePaths.progressRecords(uid))
          .orderBy('lastPerformedAt', descending: true)
          .snapshots()
          .map(
            (snap) => snap.docs
                .map((d) => ExerciseProgressRecord.fromMap(d.id, d.data()))
                .toList(),
          ),
    );
  }

  Stream<ExerciseProgressRecord?> watchProgressRecord(
    String uid,
    String exerciseId,
  ) {
    return _guardStream(
      'watchProgressRecord',
      _db
          .collection(FirestorePaths.progressRecords(uid))
          .doc(exerciseId)
          .snapshots()
          .map(
            (doc) => doc.exists
                ? ExerciseProgressRecord.fromMap(doc.id, doc.data()!)
                : null,
          ),
    );
  }

  /// Atualiza (nunca recria do zero) o rollup de evolução de cada exercício
  /// presente em [workout] — chamado por `WorkoutProvider.finishWorkout`
  /// logo depois de `saveWorkout`. Ignora exercícios sem nenhuma carga/
  /// volume registrado (ex: o aluno adicionou o exercício mas não chegou a
  /// preencher nenhuma série).
  Future<void> recordExerciseProgress(Workout workout) {
    return _guard('recordExerciseProgress', () async {
      final ref = _db.collection(
        FirestorePaths.progressRecords(workout.userId),
      );
      final aggregated = aggregateProgressInputs(workout.exercises);

      for (final entry in aggregated.entries) {
        final doc = ref.doc(entry.key);
        final snapshot = await doc.get();
        final existing = snapshot.exists
            ? ExerciseProgressRecord.fromMap(entry.key, snapshot.data()!)
            : null;

        final updated = ExerciseProgressRecord.merge(
          existing: existing,
          exerciseId: entry.key,
          exerciseName: entry.value.exerciseName,
          date: workout.date,
          topSetLoadKg: entry.value.topSetLoadKg,
          totalVolume: entry.value.totalVolume,
          historyLimit: _progressHistoryLimit,
        );
        await doc.set(updated.toMap());
      }
    });
  }

  // ---------- Lembretes (água / suplementos) ----------

  CollectionReference<Map<String, dynamic>> _remindersRef(String uid) =>
      _db.collection(FirestorePaths.reminders(uid));

  Stream<List<Reminder>> watchReminders(String uid) {
    return _guardStream(
      'watchReminders',
      _remindersRef(uid)
          .orderBy('hour')
          .snapshots()
          .map(
            (snap) =>
                snap.docs.map((d) => Reminder.fromMap(d.id, d.data())).toList(),
          ),
    );
  }

  Future<String> saveReminder(String uid, Reminder reminder) {
    return _guard('saveReminder', () async {
      final ref = _remindersRef(uid);
      if (reminder.id.isEmpty) {
        final doc = await ref.add(reminder.toMap());
        return doc.id;
      } else {
        await ref.doc(reminder.id).set(reminder.toMap());
        return reminder.id;
      }
    });
  }

  Future<void> deleteReminder(String uid, String reminderId) {
    return _guard(
      'deleteReminder',
      () => _remindersRef(uid).doc(reminderId).delete(),
    );
  }

  // ---------- Fotos de evolução do corpo ----------

  CollectionReference<Map<String, dynamic>> _bodyPhotosRef(String uid) =>
      _db.collection(FirestorePaths.bodyPhotos(uid));

  Stream<List<BodyPhoto>> watchBodyPhotos(String uid) {
    return _guardStream(
      'watchBodyPhotos',
      _bodyPhotosRef(uid)
          .orderBy('date', descending: true)
          .snapshots()
          .map(
            (snap) => snap.docs
                .map((d) => BodyPhoto.fromMap(d.id, d.data()))
                .toList(),
          ),
    );
  }

  Future<void> addBodyPhoto(BodyPhoto photo) {
    return _guard(
      'addBodyPhoto',
      () => _bodyPhotosRef(photo.userId).add(photo.toMap()),
    );
  }

  Future<void> deleteBodyPhoto(String uid, String photoId) {
    return _guard(
      'deleteBodyPhoto',
      () => _bodyPhotosRef(uid).doc(photoId).delete(),
    );
  }

  // ---------- Avaliação física (medidas estruturadas) ----------

  CollectionReference<Map<String, dynamic>> _physicalAssessmentsRef(
    String uid,
  ) => _db.collection(FirestorePaths.physicalAssessments(uid));

  Stream<List<PhysicalAssessment>> watchPhysicalAssessments(String uid) {
    return _guardStream(
      'watchPhysicalAssessments',
      _physicalAssessmentsRef(uid)
          .orderBy('date', descending: true)
          .snapshots()
          .map(
            (snap) => snap.docs
                .map((d) => PhysicalAssessment.fromMap(d.id, d.data()))
                .toList(),
          ),
    );
  }

  Future<void> addPhysicalAssessment(PhysicalAssessment assessment) {
    return _guard(
      'addPhysicalAssessment',
      () => _physicalAssessmentsRef(assessment.userId).add(assessment.toMap()),
    );
  }

  /// Regrava a avaliação inteira — as regras só aceitam se quem grava for o
  /// autor e se `userId`/`recordedBy`/`createdByUid`/`createdAt` não mudarem.
  Future<void> updatePhysicalAssessment(PhysicalAssessment assessment) {
    return _guard(
      'updatePhysicalAssessment',
      () =>
          _physicalAssessmentsRef(assessment.userId)
              .doc(assessment.id)
              .set(assessment.toMap()),
    );
  }

  Future<void> deletePhysicalAssessment(String uid, String assessmentId) {
    return _guard(
      'deletePhysicalAssessment',
      () => _physicalAssessmentsRef(uid).doc(assessmentId).delete(),
    );
  }

  // ---------- Chat com IA ----------

  CollectionReference<Map<String, dynamic>> _chatRef(String uid) =>
      _db.collection(FirestorePaths.chatMessages(uid));

  Stream<List<ChatMessage>> watchChatMessages(String uid) {
    return _guardStream(
      'watchChatMessages',
      _chatRef(uid)
          .orderBy('createdAt')
          .snapshots()
          .map(
            (snap) => snap.docs
                .map((d) => ChatMessage.fromMap(d.id, d.data()))
                .toList(),
          ),
    );
  }

  Future<void> addChatMessage(String uid, ChatMessage message) {
    return _guard('addChatMessage', () => _chatRef(uid).add(message.toMap()));
  }

  // ---------- Fotos de refeição ----------

  CollectionReference<Map<String, dynamic>> _mealPhotosRef(String uid) =>
      _db.collection(FirestorePaths.mealPhotos(uid));

  Stream<List<MealPhoto>> watchMealPhotos(String uid) {
    return _guardStream(
      'watchMealPhotos',
      _mealPhotosRef(uid)
          .orderBy('date', descending: true)
          .snapshots()
          .map(
            (snap) => snap.docs
                .map((d) => MealPhoto.fromMap(d.id, d.data()))
                .toList(),
          ),
    );
  }

  Future<String> addMealPhoto(MealPhoto photo) {
    return _guard('addMealPhoto', () async {
      final doc = await _mealPhotosRef(photo.userId).add(photo.toMap());
      return doc.id;
    });
  }

  Future<void> updateMealPhotoAnalysis(
    String uid,
    String photoId,
    String analysis,
  ) {
    return _guard(
      'updateMealPhotoAnalysis',
      () => _mealPhotosRef(uid).doc(photoId).update({'aiAnalysis': analysis}),
    );
  }

  Future<void> markMealPhotoAnalysisFailed(
    String uid,
    String photoId,
    String reason,
  ) {
    return _guard(
      'markMealPhotoAnalysisFailed',
      () =>
          _mealPhotosRef(uid).doc(photoId).update({'aiAnalysisError': reason}),
    );
  }

  Future<void> deleteMealPhoto(String uid, String photoId) {
    return _guard(
      'deleteMealPhoto',
      () => _mealPhotosRef(uid).doc(photoId).delete(),
    );
  }

  // ---------- Planos de treino (instrutor -> aluno) ----------

  CollectionReference<Map<String, dynamic>> _trainingPlansRef(String uid) =>
      _db.collection(FirestorePaths.trainingPlans(uid));

  Stream<List<TrainingPlan>> watchTrainingPlans(String studentUid) {
    return _guardStream(
      'watchTrainingPlans',
      _trainingPlansRef(studentUid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (snap) => snap.docs
                .map((d) => TrainingPlan.fromMap(d.id, d.data()))
                .toList(),
          ),
    );
  }

  Future<void> saveTrainingPlan(TrainingPlan plan) {
    return _guard('saveTrainingPlan', () async {
      final ref = _trainingPlansRef(plan.studentUid);
      if (plan.id.isEmpty) {
        await ref.add(plan.toMap());
      } else {
        await ref.doc(plan.id).set(plan.toMap());
      }
    });
  }

  Future<void> deleteTrainingPlan(String studentUid, String planId) {
    return _guard(
      'deleteTrainingPlan',
      () => _trainingPlansRef(studentUid).doc(planId).delete(),
    );
  }

  /// Atualiza a nota do instrutor sobre um aluno (ex: "dor lombar
  /// crônica"), usada como contexto para as sugestões de IA. Guardada
  /// junto da entrada denormalizada em `users/{instructorId}/students`.
  Future<void> updateStudentNote(
    String instructorId,
    String studentUid,
    String note,
  ) {
    return _guard('updateStudentNote', () {
      return _db
          .collection(FirestorePaths.students(instructorId))
          .doc(studentUid)
          .set({'notes': note}, SetOptions(merge: true));
    });
  }

  // ---------- Nutrição (isolada do domínio de treino do instrutor) ----------

  CollectionReference<Map<String, dynamic>> _nutritionChatRef(String uid) =>
      _db.collection(FirestorePaths.nutritionChat(uid));

  Stream<List<NutritionMessage>> watchNutritionChat(String uid) {
    return _guardStream(
      'watchNutritionChat',
      _nutritionChatRef(uid)
          .orderBy('createdAt')
          .snapshots()
          .map(
            (snap) => snap.docs
                .map((d) => NutritionMessage.fromMap(d.id, d.data()))
                .toList(),
          ),
    );
  }

  Future<void> addNutritionMessage(String uid, NutritionMessage message) {
    return _guard(
      'addNutritionMessage',
      () => _nutritionChatRef(uid).add(message.toMap()),
    );
  }

  CollectionReference<Map<String, dynamic>> _nutritionPlansRef(String uid) =>
      _db.collection(FirestorePaths.nutritionPlans(uid));

  Stream<List<NutritionPlan>> watchNutritionPlans(String studentUid) {
    return _guardStream(
      'watchNutritionPlans',
      _nutritionPlansRef(studentUid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (snap) => snap.docs
                .map((d) => NutritionPlan.fromMap(d.id, d.data()))
                .toList(),
          ),
    );
  }

  Future<void> saveNutritionPlan(NutritionPlan plan) {
    return _guard('saveNutritionPlan', () async {
      final ref = _nutritionPlansRef(plan.studentUid);
      if (plan.id.isEmpty) {
        await ref.add(plan.toMap());
      } else {
        await ref.doc(plan.id).set(plan.toMap());
      }
    });
  }

  Future<void> deleteNutritionPlan(String studentUid, String planId) {
    return _guard(
      'deleteNutritionPlan',
      () => _nutritionPlansRef(studentUid).doc(planId).delete(),
    );
  }

  // ---------- Modelos de plano (instrutor, reutilizável entre alunos) ----------

  CollectionReference<Map<String, dynamic>> _planTemplatesRef(
    String instructorUid,
  ) => _db.collection(FirestorePaths.planTemplates(instructorUid));

  Stream<List<PlanTemplate>> watchPlanTemplates(String instructorUid) {
    return _guardStream(
      'watchPlanTemplates',
      _planTemplatesRef(instructorUid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (snap) => snap.docs
                .map((d) => PlanTemplate.fromMap(d.id, d.data()))
                .toList(),
          ),
    );
  }

  Future<void> savePlanTemplate(PlanTemplate template) {
    return _guard('savePlanTemplate', () async {
      final ref = _planTemplatesRef(template.instructorUid);
      if (template.id.isEmpty) {
        await ref.add(template.toMap());
      } else {
        await ref.doc(template.id).set(template.toMap());
      }
    });
  }

  Future<void> deletePlanTemplate(String instructorUid, String templateId) {
    return _guard(
      'deletePlanTemplate',
      () => _planTemplatesRef(instructorUid).doc(templateId).delete(),
    );
  }

  // ---------- Agenda (compromissos instrutor <-> aluno) ----------

  CollectionReference<Map<String, dynamic>> _appointmentsRef(String uid) =>
      _db.collection(FirestorePaths.appointments(uid));

  Stream<List<Appointment>> watchAppointmentsForStudent(String studentUid) {
    return _guardStream(
      'watchAppointmentsForStudent',
      _appointmentsRef(studentUid)
          .orderBy('start')
          .snapshots()
          .map(
            (snap) => snap.docs
                .map((d) => Appointment.fromMap(d.id, d.data()))
                .toList(),
          ),
    );
  }

  /// Consolida os compromissos de TODOS os alunos de um instrutor numa
  /// coisa só, via *collection group query* (mesmo princípio de
  /// `countWorkoutsLogged`, mas aqui devolvendo os documentos, não só a
  /// contagem) — evita duplicar o compromisso num documento por instrutor.
  Stream<List<Appointment>> watchAppointmentsForInstructor(
    String instructorUid,
  ) {
    return _guardStream(
      'watchAppointmentsForInstructor',
      _db
          .collectionGroup(FirestorePaths.appointmentsGroup)
          .where('instructorUid', isEqualTo: instructorUid)
          .orderBy('start')
          .snapshots()
          .map(
            (snap) => snap.docs
                .map((d) => Appointment.fromMap(d.id, d.data()))
                .toList(),
          ),
    );
  }

  Future<void> saveAppointment(Appointment appointment) {
    return _guard('saveAppointment', () async {
      final ref = _appointmentsRef(appointment.studentUid);
      if (appointment.id.isEmpty) {
        await ref.add(appointment.toMap());
      } else {
        await ref.doc(appointment.id).set(appointment.toMap());
      }
    });
  }

  Future<void> deleteAppointment(String studentUid, String appointmentId) {
    return _guard(
      'deleteAppointment',
      () => _appointmentsRef(studentUid).doc(appointmentId).delete(),
    );
  }

  // ---------- Financeiro (mensalidade via Mercado Pago) ----------
  //
  // Escrita de `finance/subscription` e `finance/subscription/payments` é
  // feita só pela Cloud Function (Admin SDK) — ver `functions/src/mercadopago.ts`.
  // O cliente só lê e, pro instrutor, define o valor mensal do aluno
  // (`monthlyFeeCents`, guardado na entrada denormalizada em `students`).

  Stream<Subscription> watchSubscription(String uid) {
    return _guardStream(
      'watchSubscription',
      _db
          .doc(FirestorePaths.financeSubscriptionDoc(uid))
          .snapshots()
          .map((doc) => Subscription.fromMap(doc.data())),
    );
  }

  Stream<List<SubscriptionPayment>> watchPayments(String uid) {
    return _guardStream(
      'watchPayments',
      _db
          .collection(FirestorePaths.financePayments(uid))
          .orderBy('date', descending: true)
          .snapshots()
          .map(
            (snap) => snap.docs
                .map((d) => SubscriptionPayment.fromMap(d.id, d.data()))
                .toList(),
          ),
    );
  }

  /// Uso de IA (fotos de refeição/evolução) do mês corrente — só leitura;
  /// quem incrementa é a Cloud Function, depois de cada análise concluída
  /// (ver `functions/src/index.ts`).
  Stream<AiUsage> watchAiUsage(String uid) {
    final month = DateTime.now().toIso8601String().substring(0, 7);
    return _guardStream(
      'watchAiUsage',
      _db
          .doc(FirestorePaths.aiUsageDoc(uid, month))
          .snapshots()
          .map((doc) => AiUsage.fromMap(doc.data())),
    );
  }

  /// Define o valor mensal (em centavos) que um instrutor cobra de um aluno
  /// — mesmo padrão de `updateStudentNote`.
  Future<void> updateStudentFee(
    String instructorId,
    String studentUid,
    int feeCents,
  ) {
    return _guard('updateStudentFee', () {
      return _db
          .collection(FirestorePaths.students(instructorId))
          .doc(studentUid)
          .set({'monthlyFeeCents': feeCents}, SetOptions(merge: true));
    });
  }

  // ---------- Estatísticas (painel de administração) ----------
  //
  // Usa aggregate queries (`.count()`) — o Firestore conta no servidor sem
  // baixar os documentos, então isso é barato mesmo com muitos registros.

  // ---------- Timeline (mural de avisos) ----------

  CollectionReference<Map<String, dynamic>> get _announcementsRef =>
      _db.collection('announcements');

  Stream<List<Announcement>> watchAnnouncements() {
    return _guardStream(
      'watchAnnouncements',
      _announcementsRef
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (snap) => snap.docs
                .map((d) => Announcement.fromMap(d.id, d.data()))
                .toList(),
          ),
    );
  }

  Future<void> createAnnouncement(Announcement announcement) {
    return _guard(
      'createAnnouncement',
      () => _announcementsRef.add(announcement.toMap()),
    );
  }

  Future<void> deleteAnnouncement(String id) {
    return _guard(
      'deleteAnnouncement',
      () => _announcementsRef.doc(id).delete(),
    );
  }

  Future<void> toggleAnnouncementLike(String id, String uid, bool liked) {
    return _guard('toggleAnnouncementLike', () {
      return _announcementsRef.doc(id).update({
        'likeUids': liked
            ? FieldValue.arrayUnion([uid])
            : FieldValue.arrayRemove([uid]),
      });
    });
  }
}

/// Junta a lista de alunos vinculados (fonte de verdade, do perfil do aluno)
/// com as entradas denormalizadas do profissional (notas, mensalidade...):
/// só aparece quem está em [linked]; nome/e-mail vêm do perfil atual.
/// Emite quando as duas fontes já tiverem emitido ao menos uma vez.
Stream<List<Map<String, dynamic>>> combineLinkedStudents(
  Stream<List<Map<String, dynamic>>> linked,
  Stream<Map<String, Map<String, dynamic>>> entries,
) {
  late StreamController<List<Map<String, dynamic>>> controller;
  StreamSubscription<List<Map<String, dynamic>>>? linkedSub;
  StreamSubscription<Map<String, Map<String, dynamic>>>? entriesSub;
  List<Map<String, dynamic>>? lastLinked;
  Map<String, Map<String, dynamic>>? lastEntries;

  void emit() {
    final l = lastLinked;
    final e = lastEntries;
    if (l == null || e == null) return;
    final merged =
        [
          for (final student in l) {...?e[student['uid']], ...student},
        ]..sort(
          (a, b) => (a['name'] as String).toLowerCase().compareTo(
            (b['name'] as String).toLowerCase(),
          ),
        );
    controller.add(merged);
  }

  controller = StreamController<List<Map<String, dynamic>>>(
    onListen: () {
      linkedSub = linked.listen((v) {
        lastLinked = v;
        emit();
      }, onError: controller.addError);
      entriesSub = entries.listen((v) {
        lastEntries = v;
        emit();
      }, onError: controller.addError);
    },
    onCancel: () async {
      await linkedSub?.cancel();
      await entriesSub?.cancel();
    },
  );
  return controller.stream;
}
