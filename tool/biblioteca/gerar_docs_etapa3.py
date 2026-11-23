"""Gera os documentos de revisão da Etapa 3 a partir de etapa3_fichas.json
e de um backup da biblioteca (para os campos que os existentes já têm).

Rodar: python tool/biblioteca/gerar_docs_etapa3.py <backup.json>
Gera docs/etapa3-amostra-fichas.md e docs/etapa3-fichas-completas.md.
"""
import json
import os
import sys

here = os.path.dirname(os.path.abspath(__file__))
root = os.path.abspath(os.path.join(here, '..', '..'))
data = json.load(open(os.path.join(here, 'etapa3_fichas.json'), encoding='utf-8'))
backup = json.load(open(sys.argv[1], encoding='utf-8'))['exercises']

DIF = {'iniciante': 'Iniciante', 'intermediario': 'Intermediário', 'avancado': 'Avançado'}
CAT = {'forca': 'Força', 'cardio': 'Cardio', 'mobilidade': 'Mobilidade', 'hiit': 'HIIT', 'alongamento': 'Alongamento'}


def name_of(i):
    if i in data['novos']:
        return data['novos'][i]['name']
    return data['renomear'].get(i, {}).get('name') or backup[i]['name']


def ficha(i, full=True):
    novo = i in data['novos']
    if novo:
        e = data['novos'][i]
        origem = 'novo (Bloco %s)' % data['blocoDosNovos'][i]
    else:
        e = dict(backup[i])
        for k, v in data['existentes'][i].items():
            if not e.get(k):
                e[k] = v
        e.update(data['renomear'].get(i, {}))
        origem = 'existente (texto novo: erros, cuidados, tags, alternativas)'
    s = []
    s.append(f"### {e['name']}  `{i}`")
    s.append('')
    s.append(f"*{origem} · revisão profissional pendente*")
    s.append('')
    rows = [
        ('Nome alternativo', e.get('alternateName') or '—'),
        ('Grupo', e['muscleGroup']),
        ('Músculos secundários', ', '.join(e.get('secondaryMuscles') or []) or '—'),
        ('Equipamento', e['equipment']),
        ('Categoria', CAT.get(e.get('category'), e.get('category'))),
        ('Padrão de movimento', e.get('movementPattern') or '—'),
        ('Dificuldade', DIF.get(e.get('difficultyLevel'), '—')),
        ('Unilateral', 'sim' if e.get('isUnilateral') else 'não'),
    ]
    if e.get('tracksDuration'):
        dur = e.get('defaultDurationSeconds')
        rows.append(('Sugestão', f"{e.get('defaultSets') or 1} × {dur // 60 if dur and dur >= 60 else dur} {'min' if dur and dur >= 60 else 's'}"
                     + (f", descanso {e['defaultRestSeconds']} s" if e.get('defaultRestSeconds') else '')))
    elif e.get('defaultSets'):
        rows.append(('Sugestão', f"{e['defaultSets']} × {e['defaultReps']}, descanso {e['defaultRestSeconds']} s"))
    rows.append(('Vídeo / imagem', 'vazio' if not e.get('videoUrl') else 'vídeo já existente (não mudou)'))
    s.append('| Campo | Valor |')
    s.append('|---|---|')
    for k, v in rows:
        s.append(f'| {k} | {v} |')
    s.append('')
    if full:
        s.append(f"**Descrição:** {e.get('description', '')}")
        s.append('')
        s.append('**Como fazer:**')
        for n, step in enumerate(e.get('instructions') or [], 1):
            s.append(f'{n}. {step}')
        s.append('')
    s.append('**Erros comuns:**')
    for m in e['commonMistakes']:
        s.append(f'- {m}')
    s.append('')
    s.append(f"**Cuidados:** {e['careNotes']}")
    s.append('')
    s.append(f"**Tags de busca:** {', '.join(e['searchTags'])}")
    s.append('')
    alts = e.get('alternativeExerciseIds') or []
    s.append(f"**Alternativas:** {', '.join(name_of(a) for a in alts) or '—'}")
    s.append('')
    return '\n'.join(s)


AMOSTRA = ['decline_bench_press', 'ab_wheel_rollout', 'pendulum_squat', 'stationary_bike', 'deadlift']

head = ['# Etapa 3 · Parte B — amostra de 5 fichas completas', '',
        'Nada foi gravado no Firestore. Todo texto abaixo é sugestão e fica marcado como',
        '"revisão profissional pendente" até um profissional com CREF revisar.', '',
        'Amostra: 2 novos do Bloco A (um de peito, a roda abdominal com o equipamento novo),',
        '1 do Bloco B (versão geral de exercício do personal), 1 de cardio e 1 existente',
        '(o levantamento terra, que já tinha instruções e vídeo e ganha erros, cuidados,',
        'tags e alternativas).', '',
        'Todas as fichas estão em `docs/etapa3-fichas-completas.md`.', '']
open(os.path.join(root, 'docs', 'etapa3-amostra-fichas.md'), 'w', encoding='utf-8', newline='\n').write(
    '\n'.join(head) + '\n' + '\n---\n\n'.join(ficha(i) for i in AMOSTRA))

allh = ['# Etapa 3 · Parte B — todas as fichas (revisão profissional pendente)', '',
        f"{len(data['novos'])} novos com ficha completa e {len(data['existentes'])} existentes com o texto novo",
        '(erros comuns, cuidados, tags e alternativas; nos existentes, campos que já',
        'tinham conteúdo ficam como estavam).', '', '## Novos', '']
body = [ficha(i) for i in data['novos']]
body2 = [ficha(i, full=False) for i in data['existentes']]
open(os.path.join(root, 'docs', 'etapa3-fichas-completas.md'), 'w', encoding='utf-8', newline='\n').write(
    '\n'.join(allh) + '\n' + '\n'.join(body) + '\n## Existentes\n\n' + '\n'.join(body2))
print('docs gerados')
