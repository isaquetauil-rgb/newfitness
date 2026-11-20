import 'parq.dart';
import 'plate_setup.dart';

/// Meta semanal de treinos quando o aluno ainda não escolheu a dele.
const int defaultWeeklyGoal = 3;

enum UserRole { student, instructor, nutritionist }

String userRoleToString(UserRole role) {
  switch (role) {
    case UserRole.instructor:
      return 'instructor';
    case UserRole.nutritionist:
      return 'nutritionist';
    case UserRole.student:
      return 'student';
  }
}

UserRole userRoleFromString(String? value) {
  switch (value) {
    case 'instructor':
      return UserRole.instructor;
    case 'nutritionist':
      return UserRole.nutritionist;
    default:
      return UserRole.student;
  }
}

/// Dados de perfil do usuário armazenados no Firestore.
class UserProfile {
  final String uid;
  final String name;
  final String email;
  final double? weightKg;
  final double? heightCm;
  final double? goalWeightKg;
  final DateTime? birthDate;
  final UserRole role;
  final String? instructorId; // preenchido só para alunos, depois de vincular
  // Vínculo independente do instrutor — um aluno pode ter os dois, um só,
  // ou nenhum. A nutricionista fica isolada do domínio de treino (e
  // vice-versa): ver `firestore.rules` (nutrition_chat/nutrition_plans não
  // são legíveis pelo instrutor, training_plans não é legível pela
  // nutricionista).
  final String? nutritionistId;
  final String? inviteCode; // preenchido só para instrutores/nutricionistas
  final bool isPrivate;

  /// Barra e anilhas da academia do aluno (calculadora de anilhas). Campo
  /// opcional: perfis antigos não têm.
  final PlateSetup? plateSetup;

  /// PAR-Q respondido no onboarding (com data). Opcional.
  final ParQ? parq;

  /// Quando o aluno aceitou o aviso de responsabilidade do treino livre
  /// (ms desde a época). Opcional.
  final int? freeWorkoutTermsAcceptedAt;

  /// O personal vinculado desativou o treino livre deste aluno. Só o
  /// personal vinculado (ou o admin) muda — ver `firestore.rules`. Só vale
  /// enquanto há personal vinculado ([freeWorkoutBlocked]).
  final bool? freeWorkoutDisabled;

  /// Meta semanal de treinos escolhida pelo aluno (campo opcional; sem ela
  /// vale [defaultWeeklyGoal]). A sequência de semanas conta as semanas que
  /// bateram a meta.
  final int? weeklyGoal;

  /// Resumo das conquistas já ganhas: id da conquista → quando (ms). Campo
  /// opcional, recalculado do histórico (ver `achievements.dart`); fica
  /// gravado para não "perder" uma conquista se a meta mudar depois.
  final Map<String, int>? achievements;

  /// Meta semanal em uso (a do aluno ou a padrão).
  int get effectiveWeeklyGoal =>
      (weeklyGoal != null && weeklyGoal! >= 1 && weeklyGoal! <= 7)
      ? weeklyGoal!
      : defaultWeeklyGoal;

  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    this.weightKg,
    this.heightCm,
    this.goalWeightKg,
    this.birthDate,
    this.role = UserRole.student,
    this.instructorId,
    this.nutritionistId,
    this.inviteCode,
    this.isPrivate = false,
    this.plateSetup,
    this.parq,
    this.freeWorkoutTermsAcceptedAt,
    this.freeWorkoutDisabled,
    this.weeklyGoal,
    this.achievements,
  });

  /// Treino livre bloqueado agora: o personal desativou e ainda está
  /// vinculado (se o vínculo acabar, o bloqueio deixa de valer).
  bool get freeWorkoutBlocked =>
      freeWorkoutDisabled == true && (instructorId?.isNotEmpty ?? false);

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    return UserProfile(
      uid: uid,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      weightKg: (map['weightKg'] as num?)?.toDouble(),
      heightCm: (map['heightCm'] as num?)?.toDouble(),
      goalWeightKg: (map['goalWeightKg'] as num?)?.toDouble(),
      birthDate: map['birthDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['birthDate'] as int)
          : null,
      role: userRoleFromString(map['role'] as String?),
      instructorId: map['instructorId'] as String?,
      nutritionistId: map['nutritionistId'] as String?,
      inviteCode: map['inviteCode'] as String?,
      isPrivate: map['isPrivate'] as bool? ?? false,
      plateSetup: map['plateSetup'] is Map
          ? PlateSetup.fromMap(
              Map<String, dynamic>.from(map['plateSetup'] as Map),
            )
          : null,
      parq: ParQ.fromMap(map['parq']),
      freeWorkoutTermsAcceptedAt: (map['freeWorkoutTermsAcceptedAt'] as num?)
          ?.toInt(),
      freeWorkoutDisabled: map['freeWorkoutDisabled'] as bool?,
      weeklyGoal: (map['weeklyGoal'] as num?)?.toInt(),
      achievements: map['achievements'] is Map
          ? {
              for (final e in (map['achievements'] as Map).entries)
                if (e.value is num) '${e.key}': (e.value as num).toInt(),
            }
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'weightKg': weightKg,
      'heightCm': heightCm,
      'goalWeightKg': goalWeightKg,
      'birthDate': birthDate?.millisecondsSinceEpoch,
      'role': userRoleToString(role),
      'instructorId': instructorId,
      'nutritionistId': nutritionistId,
      'inviteCode': inviteCode,
      'isPrivate': isPrivate,
      // Omitido quando nulo: a atualização do perfil (merge) não apaga o
      // que o aluno configurou.
      'plateSetup': ?plateSetup?.toMap(),
      'parq': ?parq?.toMap(),
      'freeWorkoutTermsAcceptedAt': ?freeWorkoutTermsAcceptedAt,
      'freeWorkoutDisabled': ?freeWorkoutDisabled,
      'weeklyGoal': ?weeklyGoal,
      'achievements': ?achievements,
    };
  }

  UserProfile copyWith({
    String? name,
    double? weightKg,
    double? heightCm,
    double? goalWeightKg,
    DateTime? birthDate,
    UserRole? role,
    String? instructorId,
    String? nutritionistId,
    String? inviteCode,
    bool? isPrivate,
    PlateSetup? plateSetup,
    ParQ? parq,
    int? freeWorkoutTermsAcceptedAt,
    bool? freeWorkoutDisabled,
    int? weeklyGoal,
    Map<String, int>? achievements,
  }) {
    return UserProfile(
      uid: uid,
      name: name ?? this.name,
      email: email,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      goalWeightKg: goalWeightKg ?? this.goalWeightKg,
      birthDate: birthDate ?? this.birthDate,
      role: role ?? this.role,
      instructorId: instructorId ?? this.instructorId,
      nutritionistId: nutritionistId ?? this.nutritionistId,
      inviteCode: inviteCode ?? this.inviteCode,
      isPrivate: isPrivate ?? this.isPrivate,
      plateSetup: plateSetup ?? this.plateSetup,
      parq: parq ?? this.parq,
      freeWorkoutTermsAcceptedAt:
          freeWorkoutTermsAcceptedAt ?? this.freeWorkoutTermsAcceptedAt,
      freeWorkoutDisabled: freeWorkoutDisabled ?? this.freeWorkoutDisabled,
      weeklyGoal: weeklyGoal ?? this.weeklyGoal,
      achievements: achievements ?? this.achievements,
    );
  }
}
