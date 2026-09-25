import 'package:newfitness/shared/models/user_profile.dart';

/// Validações do pedido de profissional — as MESMAS de
/// `professional_requests` em `firestore.rules` (o app avisa antes; as
/// regras garantem).

/// UFs válidas para o CREF.
const brazilianUfs = [
  'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MT', 'MS', //
  'MG', 'PA', 'PB', 'PR', 'PE', 'PI', 'RJ', 'RN', 'RS', 'RO', 'RR', 'SC', //
  'SP', 'SE', 'TO',
];

/// Regiões do CRN: "1" a "11".
final crnRegions = [for (var i = 1; i <= 11; i++) '$i'];

/// Regiões aceitas para o tipo de profissional pedido.
List<String> regionsFor(UserRole kind) =>
    kind == UserRole.nutritionist ? crnRegions : brazilianUfs;

// 4 a 30 caracteres (letras, números, ".", "/", "-" e espaço), sem espaço
// nas pontas — igual à regra do Firestore.
final _registrationPattern = RegExp(
  r'^[A-Za-z0-9./-][A-Za-z0-9./ -]{2,28}[A-Za-z0-9./-]$',
);

/// Mensagem de erro, ou `null` se o número (já com trim) é válido.
String? validateRegistrationNumber(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return 'Informe o número do registro.';
  if (value.length < 4 || value.length > 30) {
    return 'O registro deve ter de 4 a 30 caracteres.';
  }
  if (!_registrationPattern.hasMatch(value)) {
    return 'Use só letras, números, ponto, barra, hífen e espaço.';
  }
  return null;
}

String? validateRegistrationRegion(UserRole kind, String? region) {
  if (region == null || !regionsFor(kind).contains(region)) {
    return kind == UserRole.nutritionist
        ? 'Escolha a região do CRN (1 a 11).'
        : 'Escolha a UF do CREF.';
  }
  return null;
}

/// Motivo da recusa: obrigatório, de 1 a 500 caracteres (com trim).
String? validateRejectionReason(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return 'Informe o motivo da recusa.';
  if (value.length > 500) return 'Use no máximo 500 caracteres.';
  return null;
}
