/// Taxonomia padronizada da biblioteca de exercícios (aprovada em 23/11/2026,
/// ver docs/auditoria-biblioteca-exercicios.md) e a conversão dos nomes
/// ANTIGOS na leitura.
///
/// Regra de compatibilidade: nada antigo é reescrito. Treinos salvos,
/// exercícios do personal e o retrato de músculos gravado nos treinos podem
/// ter "Pernas", "Braço", "Peso do corpo", "funcional"... e continuam sendo
/// entendidos: as funções abaixo convertem na hora de ler (filtros, mapa
/// muscular, rótulos).
library;

/// Grupos principais (filtros e mapa muscular).
const List<String> canonicalMuscleGroups = [
  'Peito',
  'Costas',
  'Ombros',
  'Bíceps',
  'Tríceps',
  'Antebraço',
  'Quadríceps',
  'Posteriores de coxa',
  'Glúteos',
  'Adutores',
  'Abdutores',
  'Panturrilha',
  'Abdômen',
  'Corpo todo',
];

/// Músculos (secundários e detalhe do principal).
const List<String> canonicalMuscles = [
  'Peitoral maior',
  'Latíssimo do dorso',
  'Trapézio',
  'Romboides',
  'Eretor da espinha',
  'Deltoide anterior',
  'Deltoide lateral',
  'Deltoide posterior',
  'Bíceps braquial',
  'Braquial',
  'Braquiorradial',
  'Tríceps braquial',
  'Quadríceps',
  'Posteriores de coxa',
  'Adutores',
  'Abdutores',
  'Glúteos',
  'Gastrocnêmio',
  'Sóleo',
  'Reto abdominal',
  'Oblíquos',
  'Transverso',
];

/// Equipamentos.
const List<String> canonicalEquipment = [
  'Barra',
  'Halteres',
  'Anilha',
  'Polia',
  'Máquina',
  'Smith',
  'Kettlebell',
  'Elástico',
  'Peso corporal',
  'Banco',
  'Caneleira',
  'Bola medicinal',
  'Barra fixa',
  'Esteira',
  'Bicicleta',
  'Elíptico',
  'Remo',
  'Escada',
  'Corda',
];

String _key(String s) => s
    .trim()
    .toLowerCase()
    .replaceAll(RegExp('[áàâã]'), 'a')
    .replaceAll(RegExp('[éê]'), 'e')
    .replaceAll('í', 'i')
    .replaceAll(RegExp('[óôõ]'), 'o')
    .replaceAll('ú', 'u')
    .replaceAll('ç', 'c');

/// Nomes antigos de grupo → grupos padronizados equivalentes. "Pernas" e
/// "Braço" eram genéricos: valem para todos os grupos da região.
const Map<String, List<String>> _legacyGroups = {
  'pernas': [
    'Quadríceps',
    'Posteriores de coxa',
    'Glúteos',
    'Adutores',
    'Abdutores',
    'Panturrilha',
  ],
  'perna': [
    'Quadríceps',
    'Posteriores de coxa',
    'Glúteos',
    'Adutores',
    'Abdutores',
    'Panturrilha',
  ],
  'braco': ['Bíceps', 'Tríceps', 'Antebraço'],
  'bracos': ['Bíceps', 'Tríceps', 'Antebraço'],
  'ombro': ['Ombros'],
  'posterior de coxa': ['Posteriores de coxa'],
  'posteriores': ['Posteriores de coxa'],
  'panturrilhas': ['Panturrilha'],
  'abdomen (core)': ['Abdômen'],
  'core': ['Abdômen'],
  'gluteo': ['Glúteos'],
};

/// Grupos padronizados que um nome de grupo (novo ou antigo) representa.
/// Nome desconhecido volta como está.
Set<String> canonicalGroupsOf(String raw) {
  final k = _key(raw);
  if (k.isEmpty) return const {};
  for (final g in canonicalMuscleGroups) {
    if (_key(g) == k) return {g};
  }
  final legacy = _legacyGroups[k];
  if (legacy != null) return legacy.toSet();
  return {raw.trim()};
}

/// Nomes antigos de equipamento → nome padronizado.
const Map<String, String> _legacyEquipment = {
  'peso do corpo': 'Peso corporal',
  'esteira/bike': 'Esteira',
  'bike': 'Bicicleta',
  'corda de pular': 'Corda',
  'maquina smith': 'Smith',
};

/// Equipamento padronizado (lê também os nomes antigos). Desconhecido volta
/// como está.
String canonicalEquipmentName(String raw) {
  final k = _key(raw);
  if (k.isEmpty) return '';
  for (final e in canonicalEquipment) {
    if (_key(e) == k) return e;
  }
  return _legacyEquipment[k] ?? raw.trim();
}

/// Categoria padronizada (id: forca, cardio, mobilidade, alongamento, hiit).
/// Lê também os valores antigos: funcional e potencia → forca;
/// condicionamento → cardio; "Cardio" com maiúscula → cardio.
String canonicalCategory(String raw) {
  final k = _key(raw);
  switch (k) {
    case '':
      return '';
    case 'forca':
    case 'funcional':
    case 'potencia':
      return 'forca';
    case 'cardio':
    case 'condicionamento':
      return 'cardio';
    case 'mobilidade':
      return 'mobilidade';
    case 'alongamento':
      return 'alongamento';
    case 'hiit':
      return 'hiit';
    default:
      return k;
  }
}

/// Categorias que não contam séries de musculação no mapa muscular.
bool isNonStrengthCategory(String category) {
  final c = canonicalCategory(category);
  return c == 'cardio' || c == 'mobilidade' || c == 'alongamento';
}
