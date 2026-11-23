"""Gera lib/shared/models/sample_exercise_stage3.dart a partir de
etapa3_fichas.json (fonte única das fichas da Etapa 3).

Rodar: python tool/biblioteca/etapa3_fichas.py && python tool/biblioteca/gerar_dart_etapa3.py
"""
import json
import os

here = os.path.dirname(os.path.abspath(__file__))
root = os.path.abspath(os.path.join(here, '..', '..'))
data = json.load(open(os.path.join(here, 'etapa3_fichas.json'), encoding='utf-8'))


def lit(v):
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, str):
        return "'" + v.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$') + "'"
    if isinstance(v, list):
        return '<String>[' + ', '.join(lit(x) for x in v) + ']'
    raise TypeError(v)


def entry(fields, indent):
    return '{\n' + ''.join(f"{indent}  '{k}': {lit(v)},\n" for k, v in fields.items()) + indent + '}'


def mapping(name, d, typ='Map<String, Map<String, Object>>'):
    out = [f'const {typ} {name} = {{']
    for k, v in d.items():
        out.append(f"  '{k}': {entry(v, '  ')},")
    out.append('};')
    return out


out = [
    '// GERADO por tool/biblioteca/gerar_dart_etapa3.py a partir de',
    '// tool/biblioteca/etapa3_fichas.json. Não edite à mão.',
    '//',
    '// Etapa 3 da biblioteca: erros comuns, cuidados, tags e alternativas dos',
    '// exercícios gerais existentes (só preenche o que está vazio) e os',
    '// exercícios gerais novos. Todo texto tem revisão profissional pendente;',
    '// vídeo e imagem ficam vazios.',
    '// ignore_for_file: lines_longer_than_80_chars',
    'library;',
    '',
    "import 'exercise.dart';",
    '',
]
out += mapping('stage3ExerciseFills', data['existentes'])
out.append('')
out += mapping('stage3Renames', data['renomear'])
out.append('')
out += mapping('_stage3New', data['novos'])
out += [
    '',
    '/// Exercícios gerais novos da Etapa 3.',
    'final List<Exercise> stage3NewExercises = [',
    '  for (final e in _stage3New.entries) Exercise.fromMap(e.key, e.value),',
    '];',
    '',
    'bool _isEmpty(Object? v) =>',
    "    v == null || v == '' || (v is List && v.isEmpty);",
    '',
    '/// Aplica as fichas da Etapa 3 a um exercício geral existente: preenche só',
    '/// os campos vazios, aplica a troca de nome (tríceps com corda) e marca a',
    '/// revisão profissional pendente.',
    'Exercise applyStage3(Exercise e) {',
    '  final fill = stage3ExerciseFills[e.id];',
    '  final rename = stage3Renames[e.id];',
    '  if (fill == null && rename == null) return e;',
    '  final map = e.toMap();',
    '  fill?.forEach((k, v) {',
    '    if (_isEmpty(map[k])) map[k] = v;',
    '  });',
    '  if (rename != null) map.addAll(rename);',
    "  map['professionalReviewPending'] = true;",
    '  return Exercise.fromMap(e.id, map);',
    '}',
    '',
]
path = os.path.join(root, 'lib', 'shared', 'models', 'sample_exercise_stage3.dart')
open(path, 'w', encoding='utf-8', newline='\n').write('\n'.join(out))
print('gerado', path)
