/// Regra de progressão de carga de um exercício. Lógica pura: sem Flutter e
/// sem Firebase, para poder ser testada e reaproveitada em qualquer tela.
library;

/// Como a carga sobe de uma sessão para a outra.
enum ProgressionType {
  /// Repetições fixas (ex.: "5"): bateu as reps em todas as séries, sobe a
  /// carga; travou várias vezes seguidas, reduz (deload).
  linear,

  /// Faixa de repetições (ex.: "8-12"): primeiro sobe as reps até o máximo
  /// da faixa em todas as séries; aí sobe a carga e volta ao mínimo.
  doubleProgression,
}

/// Nome curto em pt-BR, para telas e textos.
String progressionTypeLabel(ProgressionType type) => switch (type) {
  ProgressionType.linear => 'Linear (reps fixas)',
  ProgressionType.doubleProgression => 'Dupla (faixa de reps)',
};

ProgressionType? progressionTypeFromString(String? value) => switch (value) {
  'linear' => ProgressionType.linear,
  'doubleProgression' => ProgressionType.doubleProgression,
  _ => null,
};

String progressionTypeToString(ProgressionType type) => type.name;

class ProgressionRule {
  const ProgressionRule({
    required this.type,
    required this.minReps,
    required this.maxReps,
    this.targetSets,
    this.incrementKg = defaultIncrementKg,
    this.stallLimit = defaultStallLimit,
    this.deloadPercent = defaultDeloadPercent,
    this.roundingStepKg = defaultRoundingStepKg,
  }) : assert(minReps > 0 && maxReps >= minReps);

  static const double defaultIncrementKg = 2.5;
  static const int defaultStallLimit = 3;
  static const double defaultDeloadPercent = 10;
  static const double defaultRoundingStepKg = 0.5;

  final ProgressionType type;

  /// Na linear, [minReps] == [maxReps] == reps alvo.
  final int minReps;
  final int maxReps;

  /// Séries prescritas. Quando informado, fazer menos séries que isso conta
  /// como não ter batido a meta. `null`: vale o que foi feito.
  final int? targetSets;

  final double incrementKg;

  /// Sessões seguidas sem bater a meta (na mesma carga) até o deload.
  final int stallLimit;
  final double deloadPercent;

  /// A carga sugerida é sempre múltipla deste passo (anilhas de 0,5 kg).
  final double roundingStepKg;

  /// Monta a regra a partir do `targetReps` do plano ("8-12", "8–12",
  /// "8 a 12" → dupla; "10" → linear). Devolve `null` quando o texto não é
  /// uma contagem de repetições ("até a falha", "30 s", "1 km", vazio).
  ///
  /// [type] força o tipo escolhido pelo personal: dupla com número único vira
  /// faixa de um número só (equivale a linear sem deload), e linear com faixa
  /// usa o máximo da faixa como reps alvo.
  static ProgressionRule? fromTargetReps(
    String targetReps, {
    ProgressionType? type,
    int? targetSets,
    double incrementKg = defaultIncrementKg,
    int stallLimit = defaultStallLimit,
    double deloadPercent = defaultDeloadPercent,
    double roundingStepKg = defaultRoundingStepKg,
  }) {
    final range = parseRepRange(targetReps);
    if (range == null) return null;
    final (lo, hi) = range;
    final resolved =
        type ??
        (lo == hi ? ProgressionType.linear : ProgressionType.doubleProgression);
    final isLinear = resolved == ProgressionType.linear;
    return ProgressionRule(
      type: resolved,
      minReps: isLinear ? hi : lo,
      maxReps: hi,
      targetSets: targetSets,
      incrementKg: incrementKg > 0 ? incrementKg : defaultIncrementKg,
      stallLimit: stallLimit > 0 ? stallLimit : defaultStallLimit,
      deloadPercent: deloadPercent > 0 && deloadPercent < 100
          ? deloadPercent
          : defaultDeloadPercent,
      roundingStepKg: roundingStepKg > 0
          ? roundingStepKg
          : defaultRoundingStepKg,
    );
  }
}

final _range = RegExp(r'^(\d{1,3})\s*(?:-|–|—|a|até)\s*(\d{1,3})\b');
final _single = RegExp(r'^(\d{1,3})\b');
// Número seguido de unidade de tempo ou distância: não é contagem de reps.
// Vale em qualquer ponto do texto ("20-30 s", "3 x 1 km"). O lookahead evita
// confundir com palavras ("5 séries" não é tempo).
final _timeOrDistance = RegExp(
  r'\d\s*(?:s|seg|segundos|min|minutos|h|m|km|metros|passos)(?![a-zà-ú])',
  caseSensitive: false,
);

/// Faixa de repetições de um texto livre de prescrição, ou `null`.
/// "8-12" → (8, 12); "10" → (10, 10); "12 cada lado" → (12, 12).
(int, int)? parseRepRange(String text) {
  final raw = text.trim().toLowerCase();
  if (raw.isEmpty || _timeOrDistance.hasMatch(raw)) return null;
  final range = _range.firstMatch(raw);
  if (range != null) {
    final a = int.parse(range.group(1)!);
    final b = int.parse(range.group(2)!);
    if (a <= 0 || b <= 0) return null;
    return a <= b ? (a, b) : (b, a);
  }
  final single = _single.firstMatch(raw);
  if (single != null) {
    final n = int.parse(single.group(1)!);
    return n > 0 ? (n, n) : null;
  }
  return null;
}
