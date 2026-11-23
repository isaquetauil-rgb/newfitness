"""Gera lib/shared/models/sample_exercise_corrections.dart a partir de
etapa2_correcoes.json (fonte única das correções da Etapa 2).

Rodar: python tool/biblioteca/gerar_dart.py
"""
import json
import os

here = os.path.dirname(os.path.abspath(__file__))
root = os.path.abspath(os.path.join(here, '..', '..'))
data = json.load(open(os.path.join(here, 'etapa2_correcoes.json'), encoding='utf-8'))


def lit(v):
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if isinstance(v, str):
        return "'" + v.replace('\\', '\\\\').replace("'", "\\'") + "'"
    if isinstance(v, list):
        return '[' + ', '.join(lit(x) for x in v) + ']'
    raise TypeError(v)


def entry(fields, indent='    '):
    return '{\n' + ''.join(f"{indent}  '{k}': {lit(v)},\n" for k, v in fields.items()) + indent + '}'


out = [
    '// GERADO por tool/biblioteca/gerar_dart.py a partir de',
    '// tool/biblioteca/etapa2_correcoes.json. Não edite à mão.',
    '//',
    '// Etapa 2 da biblioteca: grupo, músculos secundários, equipamento,',
    '// categoria, padrão de movimento, dificuldade, unilateral e "por tempo"',
    '// de cada exercício padrão (IDs não mudam), e as versões gerais de 4',
    '// exercícios que antes só existiam como exercício do personal.',
    '// ignore_for_file: lines_longer_than_80_chars',
    'library;',
    '',
    "import 'exercise.dart';",
    '',
    'const Map<String, Map<String, Object>> sampleExerciseCorrections = {',
]
for k, v in data['correcoes'].items():
    out.append(f"  '{k}': {entry(v, '  ')},")
out.append('};')
out.append('')
out.append('/// Exercícios gerais novos da Etapa 2 (textos com revisão profissional')
out.append('/// pendente; sem vídeo até alguém conferir um).')
out.append('final List<Exercise> stage2NewExercises = [')
for k, v in data['novos'].items():
    fields = dict(v)
    rev = fields.pop('revisaoProfissionalPendente', False)
    fields.pop('videoUrl', None)
    out.append('  Exercise(')
    out.append(f"    id: {lit(k)},")
    out.append(f"    name: {lit(fields['name'])},")
    out.append(f"    alternateName: {lit(fields['alternateName'])},")
    out.append(f"    muscleGroup: {lit(fields['muscleGroup'])},")
    out.append(f"    secondaryMuscles: const {lit(fields['secondaryMuscles'])},")
    out.append(f"    equipment: {lit(fields['equipment'])},")
    out.append(f"    category: {lit(fields['category'])},")
    out.append(f"    movementPattern: {lit(fields['movementPattern'])},")
    out.append(f"    difficultyLevel: {lit(fields['difficultyLevel'])},")
    out.append(f"    isUnilateral: {lit(fields['isUnilateral'])},")
    out.append(f"    tracksDuration: {lit(fields['tracksDuration'])},")
    out.append(f"    description: {lit(fields['description'])},")
    out.append("    videoUrl: '',")
    out.append(f"    instructions: const {lit(fields['instructions'])},")
    out.append(f"    professionalReviewPending: {lit(rev)},")
    out.append('  ),')
out.append('];')
out.append('')
out.append('/// Aplica [sampleExerciseCorrections] sobre um exercício padrão (o resto')
out.append('/// dele — nome, vídeo, instruções — fica como está).')
out.append('Exercise applySampleCorrection(Exercise e) {')
out.append('  final fix = sampleExerciseCorrections[e.id];')
out.append('  if (fix == null) return e;')
out.append('  return Exercise.fromMap(e.id, {...e.toMap(), ...fix});')
out.append('}')
out.append('')

path = os.path.join(root, 'lib', 'shared', 'models', 'sample_exercise_corrections.dart')
open(path, 'w', encoding='utf-8', newline='\n').write('\n'.join(out))
print('gerado', path)
