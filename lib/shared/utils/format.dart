/// Formatação de números para a tela, em pt-BR. Use SEMPRE estas funções para
/// mostrar peso: vírgula decimal e sem ".0" (19 kg, 13,3 kg, 62,5 kg).
library;

/// Número de quilos em pt-BR, sem a unidade: até 2 casas, sem zeros à
/// direita e com ponto de milhar. 19 → "19", 13.3 → "13,3", 1.25 → "1,25",
/// 1100 → "1.100", 52340.5 → "52.340,5".
///
/// Só para MOSTRAR. Em campo editável use o número sem milhar (o "." seria
/// lido como vírgula decimal).
String formatKgNumber(double kg) {
  final rounded = (kg * 100).round() / 100;
  var text = rounded.toStringAsFixed(2);
  text = text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  if (text == '-0') text = '0';
  final negative = text.startsWith('-');
  if (negative) text = text.substring(1);
  final parts = text.split('.');
  final grouped = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  final decimals = parts.length > 1 ? ',${parts[1]}' : '';
  return '${negative ? '-' : ''}$grouped$decimals';
}

/// Peso com a unidade: "19 kg", "13,3 kg", "62,5 kg", "52.340 kg".
String formatKg(double kg) => '${formatKgNumber(kg)} kg';

/// Segundos de exercício por tempo: "45 s", "1 min 30 s".
String formatSeconds(int seconds) {
  if (seconds < 60) return '$seconds s';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return s == 0 ? '$m min' : '$m min $s s';
}
