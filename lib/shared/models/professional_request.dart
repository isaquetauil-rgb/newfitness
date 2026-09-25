import 'user_profile.dart';

enum ProfessionalRequestStatus { pending, approved, rejected }

ProfessionalRequestStatus _statusFromString(String? value) {
  switch (value) {
    case 'approved':
      return ProfessionalRequestStatus.approved;
    case 'rejected':
      return ProfessionalRequestStatus.rejected;
    default:
      return ProfessionalRequestStatus.pending;
  }
}

/// Pedido de um aluno para virar personal (`instructor`, com CREF) ou
/// nutricionista (`nutritionist`, com CRN) — `professional_requests/{uid}`.
/// O aluno só cria (como pendente); aprovar/recusar é do admin, pela Cloud
/// Function `reviewProfessionalRequest`, que também grava o motivo da
/// recusa. Datas chegam já convertidas para [DateTime] pelo
/// `FirestoreService` (no Firestore são timestamps do servidor).
class ProfessionalRequest {
  final String uid;
  final UserRole kind;
  final String registrationNumber;

  /// UF do CREF (ex: "SP") ou região do CRN ("1" a "11").
  final String registrationRegion;
  final String name;
  final String email;
  final ProfessionalRequestStatus status;
  final DateTime? createdAt;
  final DateTime? reviewedAt;
  final String? rejectionReason;

  const ProfessionalRequest({
    required this.uid,
    required this.kind,
    required this.registrationNumber,
    required this.registrationRegion,
    required this.name,
    required this.email,
    required this.status,
    this.createdAt,
    this.reviewedAt,
    this.rejectionReason,
  });

  /// Rótulo do conselho + registro, ex: "CREF 123456-G/SP", "CRN-3 12345".
  String get registrationLabel => kind == UserRole.nutritionist
      ? 'CRN-$registrationRegion $registrationNumber'
      : 'CREF $registrationNumber/$registrationRegion';

  factory ProfessionalRequest.fromMap(String id, Map<String, dynamic> map) {
    return ProfessionalRequest(
      uid: id,
      kind: userRoleFromString(map['kind'] as String?),
      registrationNumber: map['registrationNumber'] as String? ?? '',
      registrationRegion: map['registrationRegion'] as String? ?? '',
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      status: _statusFromString(map['status'] as String?),
      createdAt: map['createdAt'] as DateTime?,
      reviewedAt: map['reviewedAt'] as DateTime?,
      rejectionReason: map['rejectionReason'] as String?,
    );
  }
}
