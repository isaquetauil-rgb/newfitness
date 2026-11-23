"""Etapa 2 da biblioteca de exercícios: correções dos exercícios gerais e as
4 variações novas. Gera etapa2_correcoes.json (usado pelo script de gravação
e pela atualização da biblioteca padrão no código).

Campos corrigidos (só estes; o resto do exercício fica como está):
grupo, músculos secundários, equipamento, categoria, padrão de movimento,
dificuldade, unilateral e "por tempo". IDs nunca mudam.

Rodar: python tool/biblioteca/etapa2_correcoes.py
"""
import json
import os

# id: (grupo, [secundários], equipamento, categoria, padrão, dificuldade, unilateral, porTempo)
C = {
    # ----- Peito -----
    'bench_press': ('Peito', ['Tríceps braquial', 'Deltoide anterior'], 'Barra', 'forca', 'Empurrar horizontal', 'intermediario', False, False),
    'dumbbell_bench_press': ('Peito', ['Tríceps braquial', 'Deltoide anterior'], 'Halteres', 'forca', 'Empurrar horizontal', 'iniciante', False, False),
    'incline_dumbbell_press': ('Peito', ['Deltoide anterior', 'Tríceps braquial'], 'Halteres', 'forca', 'Empurrar horizontal', 'intermediario', False, False),
    'machine_chest_press': ('Peito', ['Tríceps braquial', 'Deltoide anterior'], 'Máquina', 'forca', 'Empurrar horizontal', 'iniciante', False, False),
    'pec_deck': ('Peito', ['Deltoide anterior'], 'Máquina', 'forca', 'Adução horizontal', 'iniciante', False, False),
    'cable_crossover': ('Peito', ['Deltoide anterior'], 'Polia', 'forca', 'Adução horizontal', 'intermediario', False, False),
    'push_up': ('Peito', ['Tríceps braquial', 'Deltoide anterior', 'Reto abdominal'], 'Peso corporal', 'forca', 'Empurrar horizontal', 'iniciante', False, False),
    'wall_push_up': ('Peito', ['Tríceps braquial', 'Deltoide anterior'], 'Peso corporal', 'forca', 'Empurrar horizontal', 'iniciante', False, False),
    # ----- Costas -----
    'lat_pulldown': ('Costas', ['Bíceps braquial', 'Romboides'], 'Polia', 'forca', 'Puxar vertical', 'iniciante', False, False),
    'pull_up': ('Costas', ['Bíceps braquial', 'Romboides'], 'Barra fixa', 'forca', 'Puxar vertical', 'intermediario', False, False),
    'bent_over_row': ('Costas', ['Romboides', 'Trapézio', 'Deltoide posterior', 'Bíceps braquial', 'Eretor da espinha'], 'Barra', 'forca', 'Puxar horizontal', 'intermediario', False, False),
    'seated_cable_row': ('Costas', ['Romboides', 'Trapézio', 'Bíceps braquial'], 'Polia', 'forca', 'Puxar horizontal', 'iniciante', False, False),
    'dumbbell_row': ('Costas', ['Romboides', 'Deltoide posterior', 'Bíceps braquial'], 'Halteres', 'forca', 'Puxar horizontal', 'iniciante', True, False),
    'cat_cow': ('Costas', [], 'Peso corporal', 'mobilidade', 'Mobilidade', 'iniciante', False, False),
    'thoracic_rotation': ('Costas', [], 'Peso corporal', 'mobilidade', 'Mobilidade', 'iniciante', False, False),
    # ----- Ombros -----
    'shoulder_press': ('Ombros', ['Tríceps braquial', 'Trapézio'], 'Barra', 'forca', 'Empurrar vertical', 'intermediario', False, False),
    'dumbbell_shoulder_press': ('Ombros', ['Tríceps braquial', 'Trapézio'], 'Halteres', 'forca', 'Empurrar vertical', 'iniciante', False, False),
    'lateral_raise': ('Ombros', ['Trapézio'], 'Halteres', 'forca', 'Abdução de ombro', 'iniciante', False, False),
    'rear_delt_fly': ('Ombros', ['Romboides', 'Trapézio'], 'Halteres', 'forca', 'Abdução horizontal', 'iniciante', False, False),
    'face_pull': ('Ombros', ['Romboides', 'Trapézio'], 'Polia', 'forca', 'Puxar horizontal', 'iniciante', False, False),
    'band_pull_apart': ('Ombros', ['Romboides', 'Trapézio'], 'Elástico', 'forca', 'Abdução horizontal', 'iniciante', False, False),
    'band_external_rotation': ('Ombros', [], 'Elástico', 'forca', 'Rotação de ombro', 'iniciante', False, False),
    # ----- Bíceps / Tríceps / Antebraço -----
    'bicep_curl': ('Bíceps', ['Braquial', 'Braquiorradial'], 'Barra', 'forca', 'Flexão de cotovelo', 'iniciante', False, False),
    'hammer_curl': ('Bíceps', ['Braquiorradial', 'Braquial'], 'Halteres', 'forca', 'Flexão de cotovelo', 'iniciante', False, False),
    'tricep_extension': ('Tríceps', [], 'Halteres', 'forca', 'Extensão de cotovelo', 'iniciante', False, False),
    'triceps_pushdown': ('Tríceps', [], 'Polia', 'forca', 'Extensão de cotovelo', 'iniciante', False, False),
    'dead_hang': ('Antebraço', ['Latíssimo do dorso'], 'Barra fixa', 'forca', 'Isometria de pegada', 'iniciante', False, True),
    # ----- Quadríceps -----
    'squat': ('Quadríceps', ['Glúteos', 'Adutores', 'Eretor da espinha'], 'Barra', 'forca', 'Agachamento', 'intermediario', False, False),
    'hack_squat': ('Quadríceps', ['Glúteos'], 'Máquina', 'forca', 'Agachamento', 'intermediario', False, False),
    'leg_press': ('Quadríceps', ['Glúteos', 'Adutores'], 'Máquina', 'forca', 'Agachamento', 'iniciante', False, False),
    'leg_extension': ('Quadríceps', [], 'Máquina', 'forca', 'Extensão de joelho', 'iniciante', False, False),
    'bulgarian_split_squat': ('Quadríceps', ['Glúteos', 'Adutores'], 'Halteres', 'forca', 'Avanço', 'intermediario', True, False),
    'lunge': ('Quadríceps', ['Glúteos', 'Adutores'], 'Halteres', 'forca', 'Avanço', 'iniciante', True, False),
    'side_lunge': ('Quadríceps', ['Adutores', 'Glúteos'], 'Peso corporal', 'forca', 'Avanço lateral', 'intermediario', True, False),
    'step_up': ('Quadríceps', ['Glúteos'], 'Banco', 'forca', 'Avanço', 'iniciante', True, False),
    'sit_to_stand': ('Quadríceps', ['Glúteos'], 'Peso corporal', 'forca', 'Agachamento', 'iniciante', False, False),
    'squat_jump': ('Quadríceps', ['Glúteos', 'Gastrocnêmio'], 'Peso corporal', 'forca', 'Salto', 'intermediario', False, False),
    'box_jump': ('Quadríceps', ['Glúteos', 'Gastrocnêmio'], 'Peso corporal', 'forca', 'Salto', 'intermediario', False, False),
    'lateral_bound': ('Quadríceps', ['Glúteos', 'Abdutores', 'Gastrocnêmio'], 'Peso corporal', 'forca', 'Salto', 'intermediario', False, False),
    # ----- Posteriores de coxa -----
    'leg_curl': ('Posteriores de coxa', ['Gastrocnêmio'], 'Máquina', 'forca', 'Flexão de joelho', 'iniciante', False, False),
    'nordic_curl': ('Posteriores de coxa', ['Gastrocnêmio'], 'Peso corporal', 'forca', 'Flexão de joelho', 'avancado', False, False),
    'romanian_deadlift': ('Posteriores de coxa', ['Glúteos', 'Eretor da espinha'], 'Barra', 'forca', 'Dobradiça de quadril', 'intermediario', False, False),
    # ----- Glúteos / Abdutores -----
    'deadlift': ('Glúteos', ['Posteriores de coxa', 'Eretor da espinha', 'Quadríceps', 'Trapézio'], 'Barra', 'forca', 'Dobradiça de quadril', 'intermediario', False, False),
    'hip_thrust': ('Glúteos', ['Posteriores de coxa'], 'Barra', 'forca', 'Extensão de quadril', 'intermediario', False, False),
    'glute_bridge': ('Glúteos', ['Posteriores de coxa'], 'Peso corporal', 'forca', 'Extensão de quadril', 'iniciante', False, False),
    'cable_kickback': ('Glúteos', ['Posteriores de coxa'], 'Polia', 'forca', 'Extensão de quadril', 'iniciante', True, False),
    'kettlebell_swing': ('Glúteos', ['Posteriores de coxa', 'Eretor da espinha'], 'Kettlebell', 'forca', 'Dobradiça de quadril', 'intermediario', False, False),
    'hip_abduction': ('Abdutores', ['Glúteos'], 'Máquina', 'forca', 'Abdução de quadril', 'iniciante', False, False),
    'hip_90_90': ('Glúteos', [], 'Peso corporal', 'mobilidade', 'Mobilidade', 'iniciante', False, False),
    # ----- Panturrilha -----
    'calf_raise': ('Panturrilha', ['Sóleo'], 'Máquina', 'forca', 'Flexão plantar', 'iniciante', False, False),
    'seated_calf_raise': ('Panturrilha', ['Gastrocnêmio'], 'Máquina', 'forca', 'Flexão plantar', 'iniciante', False, False),
    'ankle_mobility': ('Panturrilha', [], 'Peso corporal', 'mobilidade', 'Mobilidade', 'iniciante', False, False),
    # ----- Abdômen -----
    'crunch': ('Abdômen', ['Oblíquos'], 'Peso corporal', 'forca', 'Flexão de tronco', 'iniciante', False, False),
    'leg_raise': ('Abdômen', ['Oblíquos'], 'Peso corporal', 'forca', 'Flexão de quadril', 'iniciante', False, False),
    'plank': ('Abdômen', ['Transverso', 'Oblíquos'], 'Peso corporal', 'forca', 'Isometria de core', 'iniciante', False, True),
    'side_plank': ('Abdômen', ['Oblíquos', 'Transverso'], 'Peso corporal', 'forca', 'Isometria de core', 'intermediario', False, True),
    'russian_twist': ('Abdômen', ['Oblíquos'], 'Peso corporal', 'forca', 'Rotação de tronco', 'iniciante', False, False),
    'mountain_climber': ('Abdômen', ['Quadríceps', 'Deltoide anterior'], 'Peso corporal', 'hiit', 'Cardio', 'iniciante', False, False),
    # ----- Corpo todo -----
    'burpee': ('Corpo todo', ['Peitoral maior', 'Quadríceps', 'Tríceps braquial'], 'Peso corporal', 'hiit', 'Cardio', 'intermediario', False, False),
    'bear_crawl': ('Corpo todo', ['Deltoide anterior', 'Reto abdominal', 'Quadríceps'], 'Peso corporal', 'hiit', 'Locomoção', 'iniciante', False, False),
    'jump_rope': ('Corpo todo', ['Gastrocnêmio'], 'Corda', 'cardio', 'Cardio', 'iniciante', False, False),
    'shadow_boxing': ('Corpo todo', ['Deltoide anterior'], 'Peso corporal', 'cardio', 'Cardio', 'iniciante', False, False),
    'med_ball_slam': ('Corpo todo', ['Latíssimo do dorso', 'Reto abdominal'], 'Bola medicinal', 'forca', 'Potência', 'intermediario', False, False),
    'farmer_walk': ('Corpo todo', ['Trapézio', 'Braquiorradial', 'Oblíquos'], 'Halteres', 'forca', 'Carregar', 'iniciante', False, False),
    'single_leg_balance': ('Corpo todo', ['Abdutores', 'Gastrocnêmio'], 'Peso corporal', 'mobilidade', 'Equilíbrio', 'iniciante', True, False),
    'heel_toe_walk': ('Corpo todo', ['Gastrocnêmio'], 'Peso corporal', 'mobilidade', 'Equilíbrio', 'iniciante', False, False),
    'hip_escape': ('Corpo todo', ['Glúteos', 'Oblíquos'], 'Peso corporal', 'mobilidade', 'Locomoção', 'iniciante', False, False),
}

# Versões GERAIS de 4 exercícios que hoje só existem como exercício do
# personal (os do personal continuam intactos; o plano do Mattheus usa eles).
NOVOS = {
    'close_grip_lat_pulldown': {
        'name': 'Puxada alta com triângulo',
        'alternateName': 'Puxada com pegada neutra fechada',
        'description': 'Puxada na polia alta com o triângulo (pegada neutra e fechada).',
        'instructions': [
            'Sente-se com as coxas presas no apoio e segure o triângulo.',
            'Puxe o triângulo até a parte de cima do peito, levando os cotovelos para baixo.',
            'Volte devagar até os braços quase estenderem.',
        ],
        'base': ('Costas', ['Bíceps braquial', 'Romboides'], 'Polia', 'forca', 'Puxar vertical', 'iniciante', False, False),
    },
    'cable_curl': {
        'name': 'Rosca direta na polia',
        'alternateName': 'Rosca na polia baixa',
        'description': 'Flexão de cotovelo na polia baixa, com barra reta ou W.',
        'instructions': [
            'Fique de frente para a polia baixa, com a barra nas mãos e os cotovelos junto ao corpo.',
            'Flexione os cotovelos até a barra chegar perto dos ombros.',
            'Desça devagar sem afastar os cotovelos do tronco.',
        ],
        'base': ('Bíceps', ['Braquial', 'Braquiorradial'], 'Polia', 'forca', 'Flexão de cotovelo', 'iniciante', False, False),
    },
    'machine_rear_delt_fly': {
        'name': 'Crucifixo inverso na máquina',
        'alternateName': 'Voador inverso',
        'description': 'Abertura dos braços para trás no voador, de frente para o encosto.',
        'instructions': [
            'Sente-se de frente para o encosto do voador e segure as alças na altura dos ombros.',
            'Abra os braços para trás, com os cotovelos levemente flexionados.',
            'Volte devagar até as mãos quase se encontrarem.',
        ],
        'base': ('Ombros', ['Romboides', 'Trapézio'], 'Máquina', 'forca', 'Abdução horizontal', 'iniciante', False, False),
    },
    'cable_lateral_raise': {
        'name': 'Elevação lateral unilateral na polia',
        'alternateName': 'Elevação lateral no cabo',
        'description': 'Elevação lateral com um braço, na polia baixa.',
        'instructions': [
            'Fique de lado para a polia baixa e segure a alça com a mão do lado de fora.',
            'Eleve o braço pela lateral até a altura do ombro, com o cotovelo levemente flexionado.',
            'Desça devagar e repita; depois troque de lado.',
        ],
        'base': ('Ombros', ['Trapézio'], 'Polia', 'forca', 'Abdução de ombro', 'intermediario', True, False),
    },
}


def as_fields(t):
    g, sec, eq, cat, pad, dif, uni, tempo = t
    return {
        'muscleGroup': g,
        'secondaryMuscles': sec,
        'equipment': eq,
        'category': cat,
        'movementPattern': pad,
        'difficultyLevel': dif,
        'isUnilateral': uni,
        'tracksDuration': tempo,
    }


def main():
    out = {
        'correcoes': {k: as_fields(v) for k, v in C.items()},
        'novos': {
            k: {
                **{f: v[f] for f in ('name', 'alternateName', 'description', 'instructions')},
                **as_fields(v['base']),
                'videoUrl': '',
                'revisaoProfissionalPendente': True,
            }
            for k, v in NOVOS.items()
        },
    }
    here = os.path.dirname(os.path.abspath(__file__))
    with open(os.path.join(here, 'etapa2_correcoes.json'), 'w', encoding='utf-8') as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
    print(f"{len(out['correcoes'])} correções, {len(out['novos'])} novos")


if __name__ == '__main__':
    main()
