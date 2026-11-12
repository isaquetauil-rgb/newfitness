/// Calculadora de anilhas: quantas vão de cada lado da barra. Lógica pura:
/// sem Flutter e sem Firebase.
library;

import 'package:newfitness/shared/models/plate_setup.dart';

/// Resultado para um peso total.
class PlateLoad {
  const PlateLoad({
    required this.targetKg,
    required this.achievedKg,
    required this.barKg,
    required this.perSide,
  });

  /// Peso que o aluno pediu.
  final double targetKg;

  /// Peso que dá para montar (igual ao pedido, ou o mais próximo).
  final double achievedKg;
  final double barKg;

  /// Anilhas de UM lado, da maior para a menor.
  final List<double> perSide;

  bool get exact => (achievedKg - targetKg).abs() < 0.001;

  /// O pedido é menor que a barra vazia.
  bool get belowBar => targetKg < barKg - 0.001;

  /// Anilhas agrupadas: {20: 1, 10: 1, 2.5: 1}.
  Map<double, int> get grouped {
    final m = <double, int>{};
    for (final p in perSide) {
      m[p] = (m[p] ?? 0) + 1;
    }
    return m;
  }
}

// Tudo é calculado em unidades de 50 g, para somar sem erro de vírgula.
const _unitsPerKg = 20;
int _u(double kg) => (kg * _unitsPerKg).round();
double _kg(int units) => units / _unitsPerKg;

/// Monta [targetKg] com a barra e as anilhas de [setup] (pares ilimitados
/// de cada tamanho). Se não fecha exato, devolve o peso mais próximo
/// possível (no empate, o mais leve); entre as combinações desse peso, a com
/// menos anilhas.
PlateLoad loadPlates(double targetKg, PlateSetup setup) {
  final bar = setup.barKg;
  final plates = {
    for (final p in setup.platesKg)
      if (_u(p) > 0) _u(p),
  }.toList()..sort((a, b) => b.compareTo(a));

  if (targetKg <= bar || plates.isEmpty) {
    return PlateLoad(
      targetKg: targetKg,
      achievedKg: bar,
      barKg: bar,
      perSide: const [],
    );
  }

  // Peso de cada lado, limitado a 500 kg para a conta não explodir.
  final side = _u(((targetKg - bar) / 2).clamp(0, 500).toDouble());
  final maxSum = side + plates.first;

  // minCount[s] = menor número de anilhas que soma s; last[s] = a última.
  const inf = 1 << 30;
  final minCount = List<int>.filled(maxSum + 1, inf)..[0] = 0;
  final last = List<int>.filled(maxSum + 1, 0);
  for (var s = 1; s <= maxSum; s++) {
    for (final p in plates) {
      if (p <= s && minCount[s - p] + 1 < minCount[s]) {
        minCount[s] = minCount[s - p] + 1;
        last[s] = p;
      }
    }
  }

  // Soma possível mais perto do lado pedido (no empate, a menor).
  var best = 0;
  for (var s = 0; s <= maxSum; s++) {
    if (minCount[s] == inf) continue;
    final d = (s - side).abs();
    final bd = (best - side).abs();
    if (d < bd) best = s;
  }

  final perSide = <double>[];
  for (var s = best; s > 0; s -= last[s]) {
    perSide.add(_kg(last[s]));
  }
  perSide.sort((a, b) => b.compareTo(a));

  return PlateLoad(
    targetKg: targetKg,
    achievedKg: double.parse((bar + 2 * _kg(best)).toStringAsFixed(2)),
    barKg: bar,
    perSide: perSide,
  );
}

/// "62,5 kg", "20 kg", "1,25 kg".
String plateKg(double kg) {
  final s = kg == kg.roundToDouble()
      ? kg.toStringAsFixed(0)
      : kg.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');
  return '${s.replaceAll('.', ',')} kg';
}
