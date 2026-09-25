/// Chaves e rótulos das medidas corporais (cm) — a chave crua fica salva em
/// [PhysicalAssessment.measurementsCm]. O mapa é livre: cada avaliação só
/// grava as medidas que foram de fato tiradas naquele dia.
class BodyMeasurement {
  BodyMeasurement._();

  static const neck = 'neck';
  static const shoulders = 'shoulders';
  static const chest = 'chest';
  static const waist = 'waist';
  static const abdomen = 'abdomen';
  static const hip = 'hip';
  static const rightArm = 'rightArm';
  static const leftArm = 'leftArm';
  static const rightForearm = 'rightForearm';
  static const leftForearm = 'leftForearm';
  static const rightThigh = 'rightThigh';
  static const leftThigh = 'leftThigh';
  static const rightCalf = 'rightCalf';
  static const leftCalf = 'leftCalf';

  // Chaves da primeira versão do formulário (sem lado). Continuam sendo
  // lidas/exibidas para não perder o histórico, mas não aparecem mais no
  // formulário de nova avaliação.
  static const legacyArm = 'arm';
  static const legacyThigh = 'thigh';
  static const legacyCalf = 'calf';

  /// Ordem do formulário e das listagens.
  static const all = [
    neck,
    shoulders,
    chest,
    waist,
    abdomen,
    hip,
    rightArm,
    leftArm,
    rightForearm,
    leftForearm,
    rightThigh,
    leftThigh,
    rightCalf,
    leftCalf,
  ];

  static const legacy = [legacyArm, legacyThigh, legacyCalf];

  /// Medidas destacadas no resumo da tela de evolução.
  static const highlights = [waist, abdomen, hip, chest, rightArm, rightThigh];

  static const labels = {
    neck: 'Pescoço',
    shoulders: 'Ombros',
    chest: 'Peito/tórax',
    waist: 'Cintura',
    abdomen: 'Abdômen',
    hip: 'Quadril',
    rightArm: 'Braço direito',
    leftArm: 'Braço esquerdo',
    rightForearm: 'Antebraço direito',
    leftForearm: 'Antebraço esquerdo',
    rightThigh: 'Coxa direita',
    leftThigh: 'Coxa esquerda',
    rightCalf: 'Panturrilha direita',
    leftCalf: 'Panturrilha esquerda',
    legacyArm: 'Braço (sem lado)',
    legacyThigh: 'Coxa (sem lado)',
    legacyCalf: 'Panturrilha (sem lado)',
  };

  /// Rótulo de qualquer chave, inclusive uma desconhecida (gravada por uma
  /// versão futura do app) — nesse caso mostra a própria chave.
  static String labelOf(String key) => labels[key] ?? key;

  /// Todas as chaves presentes em [assessments], na ordem canônica
  /// (conhecidas primeiro, depois legadas, depois desconhecidas).
  static List<String> keysIn(Iterable<PhysicalAssessment> assessments) {
    final present = <String>{
      for (final a in assessments) ...a.measurementsCm.keys,
    };
    return [
      for (final k in [...all, ...legacy])
        if (present.contains(k)) k,
      for (final k in present)
        if (!all.contains(k) && !legacy.contains(k)) k,
    ];
  }
}

/// Método usado para obter o % de gordura — só faz sentido registrar o
/// percentual quando ele veio de uma medição (nunca estimado pelo app).
class BodyFatMethod {
  BodyFatMethod._();

  static const bioimpedance = 'bioimpedance';
  static const skinfold = 'skinfold';
  static const dexa = 'dexa';
  static const other = 'other';

  static const all = [bioimpedance, skinfold, dexa, other];

  static const labels = {
    bioimpedance: 'Bioimpedância',
    skinfold: 'Dobras cutâneas',
    dexa: 'DEXA',
    other: 'Outro',
  };

  static String labelOf(String key) => labels[key] ?? key;
}

/// Origem da avaliação ([PhysicalAssessment.recordedBy]).
class AssessmentSource {
  AssessmentSource._();

  static const self = 'self';
  static const instructor = 'instructor';

  static String labelOf(String key) => switch (key) {
    self => 'Registrada pelo aluno',
    instructor => 'Registrada pelo instrutor',
    _ => key,
  };
}

/// Uma avaliação física numa data — peso, altura, composição corporal e
/// medidas em cm, todos opcionais. A coleção `physical_assessments` inteira
/// é o histórico do aluno (um documento por avaliação).
///
/// Diferente de [BodyPhoto] (fotos de evolução), aqui os dados são
/// numéricos, permitindo comparar e plotar evolução ao longo do tempo.
///
/// Documentos antigos (antes de `heightCm`/`createdByUid`/etc.) continuam
/// válidos: todos os campos novos são opcionais na leitura.
class PhysicalAssessment {
  final String id;
  final String userId;
  final DateTime date;
  final double? weightKg;
  final double? heightCm;
  final double? bodyFatPercent;
  final String? bodyFatMethod; // ver [BodyFatMethod]
  final double? muscleMassKg;
  final Map<String, double> measurementsCm;

  /// Origem: 'self' (o próprio aluno) | 'instructor' — ver [AssessmentSource].
  final String recordedBy;

  /// Quem gravou (profissional responsável quando [recordedBy] é
  /// 'instructor'). Nulo em avaliações antigas.
  final String? createdByUid;
  final String? createdByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? notes;

  const PhysicalAssessment({
    required this.id,
    required this.userId,
    required this.date,
    this.weightKg,
    this.heightCm,
    this.bodyFatPercent,
    this.bodyFatMethod,
    this.muscleMassKg,
    this.measurementsCm = const {},
    this.recordedBy = AssessmentSource.self,
    this.createdByUid,
    this.createdByName,
    this.createdAt,
    this.updatedAt,
    this.notes,
  });

  /// IMC (kg/m²) calculado a partir do peso e da altura desta avaliação —
  /// nunca gravado, para não ficar inconsistente com os valores de origem.
  /// [fallbackHeightCm] (ex.: altura do perfil) é usado quando esta
  /// avaliação não registrou altura.
  double? bmi({double? fallbackHeightCm}) =>
      calculateBmi(weightKg, heightCm ?? fallbackHeightCm);

  static double? calculateBmi(double? weightKg, double? heightCm) {
    if (weightKg == null || heightCm == null || heightCm <= 0) return null;
    final m = heightCm / 100;
    return weightKg / (m * m);
  }

  bool get isEmpty =>
      weightKg == null &&
      heightCm == null &&
      bodyFatPercent == null &&
      muscleMassKg == null &&
      measurementsCm.isEmpty;

  factory PhysicalAssessment.fromMap(String id, Map<String, dynamic> map) {
    final rawMeasurements = map['measurementsCm'] as Map<String, dynamic>?;
    DateTime? millis(String key) => map[key] is int
        ? DateTime.fromMillisecondsSinceEpoch(map[key] as int)
        : null;
    return PhysicalAssessment(
      id: id,
      userId: map['userId'] as String? ?? '',
      date: millis('date') ?? DateTime.now(),
      weightKg: (map['weightKg'] as num?)?.toDouble(),
      heightCm: (map['heightCm'] as num?)?.toDouble(),
      bodyFatPercent: (map['bodyFatPercent'] as num?)?.toDouble(),
      bodyFatMethod: map['bodyFatMethod'] as String?,
      muscleMassKg: (map['muscleMassKg'] as num?)?.toDouble(),
      measurementsCm: {
        for (final entry in (rawMeasurements ?? const {}).entries)
          if (entry.value is num) entry.key: (entry.value as num).toDouble(),
      },
      recordedBy: map['recordedBy'] as String? ?? AssessmentSource.self,
      createdByUid: map['createdByUid'] as String?,
      createdByName: map['createdByName'] as String?,
      createdAt: millis('createdAt'),
      updatedAt: millis('updatedAt'),
      notes: map['notes'] as String?,
    );
  }

  /// Os nomes aqui precisam bater com a lista `hasOnly` de
  /// `physical_assessments` em `firestore.rules`.
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'date': date.millisecondsSinceEpoch,
      'weightKg': weightKg,
      'heightCm': heightCm,
      'bodyFatPercent': bodyFatPercent,
      'bodyFatMethod': bodyFatMethod,
      'muscleMassKg': muscleMassKg,
      'measurementsCm': measurementsCm,
      'recordedBy': recordedBy,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
      'notes': notes,
    };
  }

  PhysicalAssessment copyWith({
    String? id,
    DateTime? date,
    String? createdByUid,
    String? createdByName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PhysicalAssessment(
      id: id ?? this.id,
      userId: userId,
      date: date ?? this.date,
      weightKg: weightKg,
      heightCm: heightCm,
      bodyFatPercent: bodyFatPercent,
      bodyFatMethod: bodyFatMethod,
      muscleMassKg: muscleMassKg,
      measurementsCm: measurementsCm,
      recordedBy: recordedBy,
      createdByUid: createdByUid ?? this.createdByUid,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notes: notes,
    );
  }
}
