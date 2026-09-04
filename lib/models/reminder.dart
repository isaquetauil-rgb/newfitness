enum ReminderType { water, supplement }

/// Um lembrete recorrente (diário) de água ou suplemento, disparado como
/// notificação local no horário configurado.
class Reminder {
  final String id;
  final ReminderType type;
  final String label; // ex: "Beber água" ou nome do suplemento (ex: "Creatina")
  final String? dosage; // usado só para suplementos, ex: "5g" ou "1 cápsula"
  final int hour;
  final int minute;
  final bool enabled;

  const Reminder({
    required this.id,
    required this.type,
    required this.label,
    this.dosage,
    required this.hour,
    required this.minute,
    this.enabled = true,
  });

  /// ID numérico estável usado pelo plugin de notificações (precisa ser int).
  /// Deriva do hash do id string, truncado para caber em 31 bits.
  int get notificationId => id.hashCode & 0x7fffffff;

  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  factory Reminder.fromMap(String id, Map<String, dynamic> map) {
    return Reminder(
      id: id,
      type: (map['type'] as String?) == 'supplement'
          ? ReminderType.supplement
          : ReminderType.water,
      label: map['label'] as String? ?? '',
      dosage: map['dosage'] as String?,
      hour: (map['hour'] as num?)?.toInt() ?? 8,
      minute: (map['minute'] as num?)?.toInt() ?? 0,
      enabled: map['enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type == ReminderType.supplement ? 'supplement' : 'water',
      'label': label,
      'dosage': dosage,
      'hour': hour,
      'minute': minute,
      'enabled': enabled,
    };
  }

  Reminder copyWith({
    String? label,
    String? dosage,
    int? hour,
    int? minute,
    bool? enabled,
  }) {
    return Reminder(
      id: id,
      type: type,
      label: label ?? this.label,
      dosage: dosage ?? this.dosage,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      enabled: enabled ?? this.enabled,
    );
  }
}
