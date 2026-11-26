"""Etapa 3 da biblioteca: fichas (fonte única).

Gera tool/biblioteca/etapa3_fichas.json, usado por:
  * gerar_dart_etapa3.py  -> lib/shared/models/sample_exercise_stage3.dart
  * gravar_etapa3.js      -> Firestore real (só depois do "pode gravar")

Rodar: python tool/biblioteca/etapa3_fichas.py

Todo texto aqui é sugestão e fica marcado como "revisão profissional
pendente" (professionalReviewPending) até um profissional com CREF revisar.
Vídeo e imagem ficam vazios de propósito.
"""
import json
import os

here = os.path.dirname(os.path.abspath(__file__))

# ---------------------------------------------------------------------------
# Exercícios novos (52): 44 do Bloco A + 7 do Bloco B + tríceps com barra.
# ---------------------------------------------------------------------------
NOVOS = {}

# Vídeos achados depois na busca do YouTube e conferidos (oEmbed), aprovados
# pelo usuário em 2026-11-25.
_VIDEOS = json.load(open(os.path.join(here, 'videos_novos.json'), encoding='utf-8'))


def novo(id, name, alt, group, sec, equip, cat, pattern, diff, uni, desc,
         instr, mistakes, care, tags, alts, sets, reps, rest,
         timed=False, duration=None, load='kg', bloco='A'):
    assert id not in NOVOS, id
    NOVOS[id] = {
        'name': name,
        'alternateName': alt,
        'muscleGroup': group,
        'secondaryMuscles': sec,
        'equipment': equip,
        'category': cat,
        'movementPattern': pattern,
        'difficultyLevel': diff,
        'isUnilateral': uni,
        'tracksDuration': timed,
        'description': desc,
        'instructions': instr,
        'commonMistakes': mistakes,
        'careNotes': care,
        'searchTags': tags,
        'alternativeExerciseIds': alts,
        'defaultSets': sets,
        'defaultReps': reps,
        'defaultRestSeconds': rest,
        **({'defaultDurationSeconds': duration} if duration else {}),
        'loadUnit': load,
        'videoUrl': _VIDEOS.get(id, {}).get('videoUrl', ''),
        'imageUrls': [],
        'professionalReviewPending': True,
        '_bloco': bloco,
    }


# ----- Peito -----------------------------------------------------------------
novo('decline_bench_press', 'Supino declinado', 'Supino declinado com barra',
     'Peito', ['Tríceps braquial', 'Deltoide anterior'], 'Barra', 'forca',
     'Empurrar horizontal', 'intermediario', False,
     'Supino no banco declinado, com ênfase na parte de baixo do peitoral.',
     ['Prenda as pernas no apoio do banco declinado e deite com os olhos abaixo da barra.',
      'Segure a barra um pouco mais aberta que os ombros e tire do suporte com os braços estendidos.',
      'Desça a barra controlando até tocar a parte de baixo do peito.',
      'Empurre de volta até estender os cotovelos, sem tirar as costas do banco.'],
     ['Descer a barra no pescoço ou no meio do peito.',
      'Abrir demais os cotovelos (90° do tronco).',
      'Quicar a barra no peito.'],
     'Faça com alguém ajudando na saída e na volta da barra. Evite se a posição de cabeça para baixo causar tontura ou se tiver pressão alta descontrolada.',
     ['supino', 'peito inferior', 'declinado', 'barra'],
     ['bench_press', 'dips', 'machine_chest_press'], 4, '8-12', 90)

novo('dumbbell_fly', 'Crucifixo reto com halteres', 'Crucifixo no banco reto',
     'Peito', ['Deltoide anterior'], 'Halteres', 'forca',
     'Adução horizontal', 'iniciante', False,
     'Abertura e fechamento dos braços no banco reto, isolando o peitoral.',
     ['Deite no banco reto com um halter em cada mão, braços estendidos acima do peito e palmas viradas uma para a outra.',
      'Com os cotovelos levemente dobrados, abra os braços em arco até sentir o peito alongar.',
      'Feche os braços pelo mesmo caminho, como se abraçasse uma árvore.'],
     ['Dobrar e esticar os cotovelos durante o movimento (vira supino).',
      'Descer os halteres muito abaixo da linha do banco.',
      'Usar carga alta e perder o controle na parte de baixo.'],
     'Comece leve: a posição aberta força o ombro. Evite descer além do confortável se tiver dor ou instabilidade no ombro.',
     ['crucifixo', 'peito', 'halteres', 'isolamento', 'fly'],
     ['pec_deck', 'cable_crossover', 'incline_dumbbell_fly'], 3, '10-15', 60)

novo('incline_dumbbell_fly', 'Crucifixo inclinado com halteres', 'Crucifixo inclinado',
     'Peito', ['Deltoide anterior'], 'Halteres', 'forca',
     'Adução horizontal', 'iniciante', False,
     'Crucifixo no banco inclinado (30° a 45°), com ênfase na parte de cima do peitoral.',
     ['Ajuste o banco entre 30° e 45° e deite com um halter em cada mão acima do peito.',
      'Com os cotovelos levemente dobrados, abra os braços em arco até sentir o peito alongar.',
      'Feche os braços pelo mesmo caminho, até os halteres quase se encostarem.'],
     ['Inclinar demais o banco e transferir o trabalho para o ombro.',
      'Dobrar e esticar os cotovelos durante o movimento.',
      'Descer rápido e quicar na parte de baixo.'],
     'Use carga moderada e amplitude confortável. Evite se tiver dor no ombro na posição aberta.',
     ['crucifixo', 'peito superior', 'inclinado', 'halteres'],
     ['dumbbell_fly', 'low_cable_crossover', 'incline_dumbbell_press'], 3, '10-15', 60)

novo('low_cable_crossover', 'Crossover baixo (polia baixa)', 'Crossover de baixo para cima',
     'Peito', ['Deltoide anterior'], 'Polia', 'forca',
     'Adução horizontal', 'intermediario', False,
     'Crossover com as polias embaixo, puxando de baixo para cima (parte de cima do peitoral).',
     ['Coloque as duas polias na posição mais baixa e segure uma alça em cada mão.',
      'Dê um passo à frente, peito aberto e cotovelos levemente dobrados.',
      'Leve as mãos para cima e para o centro, até a altura do peito.',
      'Volte devagar até sentir o peito alongar.'],
     ['Usar os braços (rosca) em vez de fechar pelo peito.',
      'Arquear a lombar para subir mais carga.',
      'Soltar o peso rápido na volta.'],
     'Mantenha o abdômen firme para não compensar com a lombar.',
     ['crossover', 'polia baixa', 'peito superior', 'cabo'],
     ['incline_dumbbell_fly', 'cable_crossover', 'pec_deck'], 3, '12-15', 60)

# ----- Costas ----------------------------------------------------------------
novo('t_bar_row', 'Remada cavalinho', 'Remada T / barra T',
     'Costas', ['Latíssimo do dorso', 'Romboides', 'Trapézio', 'Bíceps braquial', 'Eretor da espinha'],
     'Barra', 'forca', 'Puxar horizontal', 'intermediario', False,
     'Remada com a barra T (ou barra presa no canto), tronco inclinado à frente.',
     ['Fique com uma perna de cada lado da barra, joelhos levemente dobrados.',
      'Incline o tronco à frente com a coluna neutra e segure a pegada.',
      'Puxe a barra em direção ao abdômen, aproximando as escápulas.',
      'Desça devagar até estender os braços, sem arredondar as costas.'],
     ['Arredondar a coluna durante a puxada.',
      'Levantar o tronco a cada repetição para ajudar a carga.',
      'Puxar só com os braços, sem mexer as escápulas.'],
     'Mantenha a coluna neutra o tempo todo. Evite ou use carga leve se tiver dor lombar; a remada apoiada no peito é uma opção mais segura.',
     ['remada', 'costas', 'barra t', 'cavalinho', 'espessura'],
     ['bent_over_row', 'seated_cable_row', 'dumbbell_row'], 4, '8-12', 90)

novo('single_arm_cable_row', 'Remada unilateral na polia', 'Remada com um braço no cabo',
     'Costas', ['Latíssimo do dorso', 'Romboides', 'Bíceps braquial', 'Oblíquos'],
     'Polia', 'forca', 'Puxar horizontal', 'iniciante', True,
     'Remada com um braço de cada vez na polia, na altura do peito ou do abdômen.',
     ['Ajuste a polia na altura do abdômen e segure a alça com uma mão.',
      'Afaste-se até o braço ficar estendido, pés firmes e tronco estável.',
      'Puxe a alça até o lado do corpo, levando o cotovelo para trás.',
      'Volte devagar deixando o ombro ir levemente à frente.'],
     ['Girar o tronco para puxar a carga.',
      'Encolher o ombro em direção à orelha.',
      'Fazer o lado mais fraco com menos repetições sem perceber.'],
     'Comece pelo lado mais fraco e repita o mesmo número de repetições do outro lado.',
     ['remada', 'unilateral', 'polia', 'costas', 'cabo'],
     ['dumbbell_row', 'seated_cable_row'], 3, '10-12', 60)

novo('reverse_grip_lat_pulldown', 'Puxada supinada', 'Puxada alta com pegada supinada',
     'Costas', ['Bíceps braquial', 'Romboides', 'Braquial'], 'Polia', 'forca',
     'Puxar vertical', 'iniciante', False,
     'Puxada na polia alta com as palmas viradas para você, na largura dos ombros.',
     ['Sente com as coxas presas no apoio e segure a barra com as palmas para você.',
      'Incline levemente o tronco para trás e puxe a barra até a parte de cima do peito.',
      'Leve os cotovelos para baixo e junto ao corpo.',
      'Volte devagar até estender os braços.'],
     ['Jogar o tronco para trás para puxar o peso.',
      'Puxar só até o queixo, sem completar o movimento.',
      'Soltar a barra rápido na subida.'],
     'Evite carga que obrigue a balançar o tronco. Atenção a dor no cotovelo com a pegada supinada.',
     ['puxada', 'supinada', 'costas', 'polia', 'pegada invertida'],
     ['lat_pulldown', 'close_grip_lat_pulldown', 'pull_up'], 3, '8-12', 90)

novo('cable_pullover', 'Pullover na polia', 'Pulldown de braços estendidos',
     'Costas', ['Tríceps braquial', 'Peitoral maior'], 'Polia', 'forca',
     'Extensão de ombro', 'intermediario', False,
     'Braços quase estendidos levando a barra (ou corda) da polia alta até as coxas.',
     ['Fique de frente para a polia alta segurando a barra ou corda com os braços quase estendidos.',
      'Incline levemente o tronco à frente, abdômen firme.',
      'Leve a barra em arco até as coxas, sem dobrar os cotovelos.',
      'Volte devagar até os braços ficarem acima da cabeça.'],
     ['Dobrar os cotovelos e transformar em tríceps.',
      'Jogar o tronco para baixo junto com a barra.',
      'Usar carga alta e perder o arco do movimento.'],
     'Evite amplitude total acima da cabeça se tiver dor no ombro.',
     ['pullover', 'polia', 'costas', 'dorsal', 'braços estendidos'],
     ['lat_pulldown', 'close_grip_lat_pulldown'], 3, '12-15', 60)

# ----- Ombros ----------------------------------------------------------------
novo('front_raise', 'Elevação frontal com halteres', 'Elevação frontal',
     'Ombros', ['Peitoral maior', 'Trapézio'], 'Halteres', 'forca',
     'Flexão de ombro', 'iniciante', False,
     'Elevação dos braços à frente até a altura dos ombros.',
     ['Em pé, um halter em cada mão à frente das coxas.',
      'Com os cotovelos levemente dobrados, eleve os braços à frente até a altura dos ombros.',
      'Desça devagar até a posição inicial.'],
     ['Balançar o tronco para subir o peso.',
      'Subir acima da linha dos ombros.',
      'Encolher os ombros durante a subida.'],
     'Use carga leve. Evite se tiver dor na frente do ombro ao elevar o braço.',
     ['elevação frontal', 'ombro', 'deltoide anterior', 'halteres'],
     ['dumbbell_shoulder_press', 'machine_shoulder_press'], 3, '10-15', 60)

novo('machine_shoulder_press', 'Desenvolvimento na máquina', 'Desenvolvimento articulado',
     'Ombros', ['Tríceps braquial', 'Trapézio'], 'Máquina', 'forca',
     'Empurrar vertical', 'iniciante', False,
     'Empurrar as alças da máquina para cima, sentado com as costas apoiadas.',
     ['Ajuste o banco para as alças ficarem na altura dos ombros.',
      'Sente com as costas apoiadas e segure as alças.',
      'Empurre para cima até quase estender os cotovelos.',
      'Desça devagar até a altura dos ombros.'],
     ['Banco muito baixo, começando com as mãos abaixo do ombro.',
      'Tirar as costas do encosto e arquear a lombar.',
      'Travar os cotovelos com força no topo.'],
     'Opção mais estável que barra e halteres para iniciantes. Evite se elevar o braço acima da cabeça causar dor.',
     ['desenvolvimento', 'máquina', 'ombro', 'empurrar'],
     ['dumbbell_shoulder_press', 'shoulder_press'], 3, '8-12', 90)

novo('machine_lateral_raise', 'Elevação lateral na máquina', 'Elevação lateral sentado na máquina',
     'Ombros', ['Trapézio'], 'Máquina', 'forca',
     'Abdução de ombro', 'iniciante', False,
     'Elevação lateral dos braços com apoio no cotovelo, na máquina própria.',
     ['Ajuste o banco para o eixo da máquina ficar na altura dos ombros.',
      'Apoie os braços nas almofadas e segure as alças.',
      'Eleve os braços para os lados até a altura dos ombros.',
      'Desça devagar.'],
     ['Encolher os ombros e usar o trapézio.',
      'Subir acima da linha dos ombros.',
      'Soltar o peso rápido na descida.'],
     'Ajuste bem o eixo da máquina ao ombro. Evite se tiver dor ao abrir o braço.',
     ['elevação lateral', 'máquina', 'deltoide lateral', 'ombro'],
     ['lateral_raise', 'cable_lateral_raise'], 3, '12-15', 60)

novo('cable_external_rotation', 'Rotação externa na polia', 'Rotação externa de ombro no cabo',
     'Ombros', ['Deltoide posterior'], 'Polia', 'forca',
     'Rotação de ombro', 'iniciante', True,
     'Rotação externa do ombro na polia, com o cotovelo junto ao corpo (manguito rotador).',
     ['Ajuste a polia na altura do cotovelo e fique de lado para ela.',
      'Segure a alça com a mão mais longe da polia, cotovelo dobrado a 90° e colado ao corpo.',
      'Gire o antebraço para fora, sem afastar o cotovelo do tronco.',
      'Volte devagar.'],
     ['Afastar o cotovelo do corpo.',
      'Girar o tronco em vez do ombro.',
      'Usar carga alta: é um exercício de controle.'],
     'Carga leve e movimento lento. Se for para reabilitação, siga a orientação do fisioterapeuta.',
     ['rotação externa', 'manguito rotador', 'ombro', 'polia', 'prevenção'],
     ['band_external_rotation', 'face_pull'], 3, '12-15', 45)

novo('band_shoulder_dislocate', 'Mobilidade de ombros com elástico (passagem)', 'Passagem de ombros',
     'Ombros', ['Peitoral maior', 'Trapézio'], 'Elástico', 'mobilidade',
     'Mobilidade', 'iniciante', False,
     'Passar o elástico da frente para trás da cabeça com os braços estendidos.',
     ['Segure o elástico com as mãos bem afastadas, braços estendidos à frente.',
      'Eleve os braços acima da cabeça e leve o elástico para trás até onde for confortável.',
      'Volte pelo mesmo caminho.',
      'Aproxime as mãos aos poucos, só se não houver dor.'],
     ['Dobrar os cotovelos para passar.',
      'Arquear a lombar para compensar.',
      'Pegada fechada demais logo no começo.'],
     'Sem dor: se doer, abra mais a pegada ou reduza a amplitude.',
     ['mobilidade', 'ombro', 'elástico', 'aquecimento', 'passagem'],
     ['thoracic_rotation', 'band_pull_apart'], 2, '10-15', 30, load='nenhuma')

# ----- Bíceps / Antebraço ------------------------------------------------------
novo('preacher_curl', 'Rosca Scott', 'Rosca no banco Scott',
     'Bíceps', ['Braquial', 'Braquiorradial'], 'Barra', 'forca',
     'Flexão de cotovelo', 'iniciante', False,
     'Rosca com os braços apoiados no banco Scott, com barra W ou reta.',
     ['Ajuste o banco para as axilas ficarem encostadas no topo do apoio.',
      'Segure a barra com as palmas para cima e os braços apoiados.',
      'Flexione os cotovelos levando a barra em direção aos ombros.',
      'Desça devagar até quase estender os braços.'],
     ['Tirar os cotovelos do apoio.',
      'Soltar o peso de uma vez no fim da descida.',
      'Usar o corpo para subir a barra.'],
     'Controle o final da descida: é onde o cotovelo fica mais exposto. Evite estender totalmente com carga alta.',
     ['rosca', 'scott', 'bíceps', 'barra w'],
     ['bicep_curl', 'concentration_curl', 'cable_curl'], 3, '8-12', 60)

novo('concentration_curl', 'Rosca concentrada', 'Rosca concentrada com halter',
     'Bíceps', ['Braquial'], 'Halteres', 'forca',
     'Flexão de cotovelo', 'iniciante', True,
     'Rosca sentada com o cotovelo apoiado na parte de dentro da coxa.',
     ['Sente no banco, pernas afastadas, e apoie o cotovelo na parte interna da coxa.',
      'Segure o halter com o braço estendido.',
      'Flexione o cotovelo levando o halter ao ombro.',
      'Desça devagar.'],
     ['Mexer o tronco para ajudar a subir.',
      'Tirar o cotovelo da coxa.',
      'Descer rápido.'],
     'Faça o mesmo número de repetições com os dois braços.',
     ['rosca', 'concentrada', 'bíceps', 'unilateral', 'halter'],
     ['preacher_curl', 'alternating_dumbbell_curl'], 3, '10-12', 45)

novo('alternating_dumbbell_curl', 'Rosca alternada com halteres', 'Rosca alternada',
     'Bíceps', ['Braquial', 'Braquiorradial'], 'Halteres', 'forca',
     'Flexão de cotovelo', 'iniciante', False,
     'Rosca em pé com halteres, um braço de cada vez, girando a palma para cima.',
     ['Em pé, um halter em cada mão ao lado do corpo, palmas para dentro.',
      'Suba um halter girando a palma para cima, cotovelo parado junto ao corpo.',
      'Desça devagar e repita com o outro braço.'],
     ['Balançar o tronco para subir.',
      'Levar o cotovelo à frente.',
      'Acelerar a troca de braço sem controlar a descida.'],
     'Conte as repetições de cada braço igualmente. Evite balançar se tiver dor lombar.',
     ['rosca', 'alternada', 'bíceps', 'halteres'],
     ['bicep_curl', 'hammer_curl', 'incline_dumbbell_curl'], 3, '10-12', 60)

novo('reverse_curl', 'Rosca inversa', 'Rosca pronada',
     'Antebraço', ['Braquial', 'Bíceps braquial'], 'Barra', 'forca',
     'Flexão de cotovelo', 'iniciante', False,
     'Rosca com as palmas viradas para baixo, para braquiorradial e antebraço.',
     ['Em pé, segure a barra com as palmas para baixo, na largura dos ombros.',
      'Flexione os cotovelos levando a barra até perto dos ombros.',
      'Desça devagar mantendo os punhos firmes.'],
     ['Dobrar os punhos para baixo durante a subida.',
      'Balançar o tronco.',
      'Usar a mesma carga da rosca direta (ela é bem menor).'],
     'Comece com carga leve. Evite se tiver dor no cotovelo do lado de fora (epicondilite).',
     ['rosca inversa', 'antebraço', 'pronada', 'barra'],
     ['hammer_curl', 'bicep_curl'], 3, '10-15', 60)

# ----- Tríceps -----------------------------------------------------------------
novo('triceps_bar_pushdown', 'Tríceps na polia com barra', 'Tríceps pulley com barra reta',
     'Tríceps', [], 'Polia', 'forca',
     'Extensão de cotovelo', 'iniciante', False,
     'Extensão dos cotovelos na polia alta com barra reta ou V (separado do tríceps com corda: a carga é diferente).',
     ['Fique de frente para a polia alta e segure a barra com as palmas para baixo.',
      'Cotovelos colados ao corpo e dobrados a 90°.',
      'Estenda os cotovelos até os braços ficarem retos.',
      'Volte devagar até 90° sem tirar os cotovelos do lugar.'],
     ['Afastar os cotovelos do corpo.',
      'Jogar o peso do corpo sobre a barra.',
      'Subir a barra acima do peito na volta.'],
     'Mantenha os punhos retos. Evite travar os cotovelos com força no fim.',
     ['tríceps', 'polia', 'barra', 'pulley', 'pushdown'],
     ['triceps_pushdown', 'tricep_extension', 'dips'], 3, '10-12', 60)

novo('triceps_kickback', 'Tríceps coice com halter', 'Coice de tríceps',
     'Tríceps', ['Deltoide posterior'], 'Halteres', 'forca',
     'Extensão de cotovelo', 'iniciante', True,
     'Extensão do cotovelo com o tronco inclinado e o braço junto ao corpo.',
     ['Apoie uma mão e um joelho no banco, tronco paralelo ao chão.',
      'Com o halter na outra mão, leve o cotovelo para trás até o braço ficar junto ao tronco.',
      'Estenda o cotovelo até o braço ficar reto.',
      'Volte devagar até 90°.'],
     ['Deixar o cotovelo cair durante o movimento.',
      'Balançar o halter.',
      'Arredondar as costas.'],
     'Carga leve, foco no controle. Mantenha a coluna neutra.',
     ['tríceps', 'coice', 'kickback', 'halter', 'unilateral'],
     ['triceps_pushdown', 'triceps_bar_pushdown', 'single_arm_overhead_triceps_extension'], 3, '10-15', 45)

novo('barbell_overhead_triceps_extension', 'Tríceps francês com barra', 'Tríceps francês',
     'Tríceps', [], 'Barra', 'forca',
     'Extensão de cotovelo', 'intermediario', False,
     'Extensão dos cotovelos com a barra atrás da cabeça, sentado ou em pé.',
     ['Sente com as costas apoiadas e segure a barra W acima da cabeça.',
      'Dobre os cotovelos levando a barra para trás da cabeça.',
      'Estenda os cotovelos de volta, sem abrir os braços.'],
     ['Abrir demais os cotovelos.',
      'Arquear a lombar.',
      'Descer rápido e bater a barra na nuca.'],
     'Evite se tiver dor no ombro ao elevar o braço. Use barra W para poupar os punhos.',
     ['tríceps', 'francês', 'barra', 'acima da cabeça'],
     ['tricep_extension', 'single_arm_overhead_triceps_extension', 'triceps_pushdown'], 3, '10-12', 60)

novo('dips', 'Mergulho nas paralelas', 'Paralelas / dips',
     'Tríceps', ['Peitoral maior', 'Deltoide anterior'], 'Peso corporal', 'forca',
     'Empurrar vertical', 'avancado', False,
     'Descer e subir o corpo apoiado nas barras paralelas.',
     ['Apoie as mãos nas paralelas e suba com os braços estendidos.',
      'Tronco mais reto para focar o tríceps; inclinado à frente para o peito.',
      'Desça dobrando os cotovelos até cerca de 90°.',
      'Empurre de volta até estender os braços.'],
     ['Descer demais e forçar a frente do ombro.',
      'Encolher os ombros perto das orelhas.',
      'Balançar as pernas para subir.'],
     'Exige força e ombro saudável. Use máquina de mergulho ou elástico de ajuda se ainda não fizer com o peso do corpo. Evite com dor no ombro.',
     ['mergulho', 'paralelas', 'dips', 'tríceps', 'peso corporal'],
     ['triceps_bar_pushdown', 'decline_bench_press', 'push_up'], 3, '6-12', 90, load='peso do corpo')

# ----- Quadríceps ----------------------------------------------------------------
novo('front_squat', 'Agachamento frontal', 'Front squat',
     'Quadríceps', ['Glúteos', 'Eretor da espinha', 'Reto abdominal'], 'Barra', 'forca',
     'Agachamento', 'avancado', False,
     'Agachamento com a barra apoiada na frente dos ombros, tronco mais reto.',
     ['Apoie a barra na frente dos ombros, cotovelos altos apontando à frente.',
      'Pés na largura dos ombros, abdômen firme.',
      'Agache mantendo o tronco o mais reto possível.',
      'Suba empurrando o chão, sem deixar os cotovelos caírem.'],
     ['Deixar os cotovelos caírem e a barra escorregar.',
      'Arredondar as costas no fundo.',
      'Joelhos caindo para dentro.'],
     'Exige mobilidade de punho, ombro e tornozelo. Aprenda com carga leve e acompanhamento.',
     ['agachamento', 'frontal', 'quadríceps', 'barra'],
     ['squat', 'smith_squat', 'hack_squat'], 4, '6-10', 120)

novo('smith_squat', 'Agachamento no Smith', 'Agachamento guiado',
     'Quadríceps', ['Glúteos', 'Adutores'], 'Smith', 'forca',
     'Agachamento', 'iniciante', False,
     'Agachamento com a barra guiada do Smith.',
     ['Posicione a barra nas costas (no trapézio) e destrave o Smith.',
      'Pés um pouco à frente da linha da barra, na largura dos ombros.',
      'Agache até onde mantiver a coluna neutra.',
      'Suba empurrando o chão.'],
     ['Pés colados na linha da barra, forçando os joelhos.',
      'Esquecer de travar a barra no fim da série.',
      'Tirar os calcanhares do chão.'],
     'Confira as travas de segurança antes de começar.',
     ['agachamento', 'smith', 'quadríceps', 'guiado'],
     ['squat', 'hack_squat', 'leg_press'], 4, '8-12', 90)

novo('single_leg_extension', 'Cadeira extensora unilateral', 'Extensora com uma perna',
     'Quadríceps', [], 'Máquina', 'forca',
     'Extensão de joelho', 'iniciante', True,
     'Cadeira extensora com uma perna de cada vez.',
     ['Ajuste o encosto e o rolo logo acima do tornozelo.',
      'Segure as alças e estenda uma perna até quase reta.',
      'Desça devagar e repita; depois troque de perna.'],
     ['Chutar o peso e perder o controle.',
      'Tirar o quadril do banco.',
      'Fazer menos repetições com a perna mais fraca.'],
     'Comece pela perna mais fraca. Evite carga alta com dor na frente do joelho.',
     ['extensora', 'unilateral', 'quadríceps', 'máquina'],
     ['leg_extension', 'bulgarian_split_squat'], 3, '10-15', 45)

novo('smith_lunge', 'Afundo no Smith', 'Avanço no Smith',
     'Quadríceps', ['Glúteos', 'Adutores'], 'Smith', 'forca',
     'Avanço', 'iniciante', True,
     'Afundo parado com a barra guiada do Smith nas costas.',
     ['Barra do Smith nas costas, um pé à frente e o outro atrás.',
      'Desça o joelho de trás em direção ao chão.',
      'Suba empurrando com o pé da frente.',
      'Faça todas as repetições e troque de perna.'],
     ['Passo curto demais, joelho da frente muito à frente.',
      'Tronco caindo para a frente.',
      'Joelho da frente caindo para dentro.'],
     'Destrave e trave a barra com cuidado. Evite se tiver dor no joelho ao descer.',
     ['afundo', 'avanço', 'smith', 'unilateral', 'pernas'],
     ['lunge', 'bulgarian_split_squat', 'step_up'], 3, '8-12', 60)

# ----- Posteriores de coxa ---------------------------------------------------------
novo('single_leg_curl', 'Mesa flexora unilateral', 'Flexora deitado com uma perna',
     'Posteriores de coxa', ['Gastrocnêmio'], 'Máquina', 'forca',
     'Flexão de joelho', 'iniciante', True,
     'Mesa flexora com uma perna de cada vez.',
     ['Deite de bruços com o rolo logo acima do calcanhar.',
      'Flexione uma perna trazendo o calcanhar em direção ao glúteo.',
      'Desça devagar e repita; depois troque de perna.'],
     ['Levantar o quadril do banco.',
      'Soltar o peso na descida.',
      'Girar o corpo para ajudar.'],
     'Mantenha o quadril encostado no banco. Comece pela perna mais fraca.',
     ['flexora', 'unilateral', 'posterior de coxa', 'máquina'],
     ['leg_curl', 'seated_leg_curl'], 3, '10-12', 45)

novo('seated_leg_curl', 'Cadeira flexora', 'Flexora sentado',
     'Posteriores de coxa', ['Gastrocnêmio'], 'Máquina', 'forca',
     'Flexão de joelho', 'iniciante', False,
     'Flexão dos joelhos sentado na máquina.',
     ['Ajuste o encosto para o joelho ficar no eixo da máquina e o rolo acima do calcanhar.',
      'Abaixe a trava das coxas.',
      'Flexione os joelhos levando o rolo para baixo e para trás.',
      'Volte devagar.'],
     ['Trava das coxas frouxa.',
      'Soltar o peso na volta.',
      'Tirar o quadril do banco.'],
     'Ajuste o eixo ao joelho antes de colocar carga.',
     ['flexora', 'cadeira flexora', 'posterior de coxa', 'máquina'],
     ['leg_curl', 'single_leg_curl', 'nordic_curl'], 3, '10-12', 60)

novo('dumbbell_romanian_deadlift', 'Stiff com halteres', 'Terra romeno com halteres',
     'Posteriores de coxa', ['Glúteos', 'Eretor da espinha'], 'Halteres', 'forca',
     'Dobradiça de quadril', 'iniciante', False,
     'Dobradiça de quadril com um halter em cada mão, joelhos levemente dobrados.',
     ['Em pé, halteres à frente das coxas, joelhos levemente dobrados.',
      'Leve o quadril para trás deslizando os halteres pelas pernas.',
      'Desça até sentir alongar atrás da coxa, coluna neutra.',
      'Suba empurrando o quadril à frente.'],
     ['Arredondar as costas.',
      'Dobrar demais os joelhos (vira agachamento).',
      'Afastar os halteres das pernas.'],
     'Pare a descida antes de perder a coluna neutra. Evite carga alta com dor lombar.',
     ['stiff', 'terra romeno', 'posterior de coxa', 'halteres'],
     ['romanian_deadlift', 'good_morning', 'kettlebell_swing'], 3, '8-12', 90)

novo('good_morning', 'Good morning (bom dia)', 'Bom dia',
     'Posteriores de coxa', ['Glúteos', 'Eretor da espinha'], 'Barra', 'forca',
     'Dobradiça de quadril', 'avancado', False,
     'Dobradiça de quadril com a barra nas costas.',
     ['Barra nas costas como no agachamento, joelhos levemente dobrados.',
      'Leve o quadril para trás inclinando o tronco à frente com a coluna neutra.',
      'Desça até o tronco quase paralelo ao chão ou até onde mantiver a coluna neutra.',
      'Suba empurrando o quadril à frente.'],
     ['Arredondar a lombar.',
      'Usar carga alta antes de dominar o movimento.',
      'Dobrar demais os joelhos.'],
     'Exige técnica: comece só com a barra. Evite com dor lombar ou hérnia.',
     ['good morning', 'bom dia', 'posterior de coxa', 'lombar', 'barra'],
     ['romanian_deadlift', 'back_extension_45', 'dumbbell_romanian_deadlift'], 3, '8-10', 90)

# ----- Glúteos -------------------------------------------------------------------
novo('back_extension_45', 'Extensão de quadril no banco 45°', 'Hiperextensão / banco romano',
     'Glúteos', ['Posteriores de coxa', 'Eretor da espinha'], 'Banco', 'forca',
     'Dobradiça de quadril', 'iniciante', False,
     'Extensão do quadril no banco 45° (banco romano).',
     ['Ajuste o apoio logo abaixo do quadril e prenda os pés.',
      'Desça o tronco dobrando no quadril, coluna neutra.',
      'Suba até o corpo ficar em linha reta, apertando os glúteos.'],
     ['Subir além da linha do corpo e arquear a lombar.',
      'Apoio alto demais, travando o quadril.',
      'Descer rápido.'],
     'Não passe da linha reta no topo. Evite com dor lombar aguda.',
     ['extensão de quadril', 'hiperextensão', 'banco romano', 'glúteos', 'lombar'],
     ['good_morning', 'romanian_deadlift', 'hip_thrust'], 3, '10-15', 60, load='peso do corpo')

novo('single_leg_hip_thrust', 'Elevação pélvica unilateral', 'Hip thrust com uma perna',
     'Glúteos', ['Posteriores de coxa'], 'Peso corporal', 'forca',
     'Extensão de quadril', 'intermediario', True,
     'Elevação pélvica com as costas no banco e uma perna apoiada.',
     ['Apoie a parte de cima das costas no banco e um pé no chão; a outra perna fica no ar.',
      'Empurre o chão com o calcanhar e suba o quadril até o tronco ficar alinhado.',
      'Aperte o glúteo no topo e desça devagar.',
      'Faça todas as repetições e troque de lado.'],
     ['Arquear a lombar no topo.',
      'Deixar o quadril girar para o lado da perna livre.',
      'Empurrar com a ponta do pé.'],
     'Mantenha o quadril nivelado. Comece sem carga.',
     ['elevação pélvica', 'hip thrust', 'unilateral', 'glúteos'],
     ['hip_thrust', 'glute_bridge', 'cable_kickback'], 3, '10-12', 60, load='peso do corpo')

novo('ankle_weight_kickback', 'Coice com caneleira (quatro apoios)', 'Glúteo quatro apoios',
     'Glúteos', ['Posteriores de coxa'], 'Caneleira', 'forca',
     'Extensão de quadril', 'iniciante', True,
     'Extensão do quadril em quatro apoios com caneleira.',
     ['Fique em quatro apoios com a caneleira no tornozelo.',
      'Com o joelho dobrado, empurre o pé para cima até a coxa ficar alinhada ao tronco.',
      'Desça devagar sem encostar o joelho no chão.',
      'Faça todas as repetições e troque de perna.'],
     ['Arquear a lombar para subir mais.',
      'Girar o quadril para o lado.',
      'Balançar a perna.'],
     'Abdômen firme para proteger a lombar.',
     ['coice', 'caneleira', 'glúteos', 'quatro apoios', 'unilateral'],
     ['cable_kickback', 'glute_bridge'], 3, '12-15', 45)

# ----- Abdutores / Adutores ---------------------------------------------------------
novo('cable_hip_abduction', 'Abdução de quadril na polia', 'Abdução em pé no cabo',
     'Abdutores', ['Glúteos'], 'Polia', 'forca',
     'Abdução de quadril', 'iniciante', True,
     'Afastar a perna para o lado em pé, com a polia baixa presa ao tornozelo.',
     ['Prenda a tornozeleira da polia baixa na perna mais longe da polia.',
      'Segure-se no aparelho, corpo reto.',
      'Afaste a perna para o lado sem inclinar o tronco.',
      'Volte devagar e troque de lado no fim.'],
     ['Inclinar o tronco para o lado.',
      'Girar o pé para fora.',
      'Balançar a perna.'],
     'Movimento curto e controlado; não force a amplitude.',
     ['abdução', 'polia', 'glúteo médio', 'unilateral'],
     ['hip_abduction', 'band_hip_abduction'], 3, '12-15', 45)

novo('band_hip_abduction', 'Abdução de quadril com elástico', 'Abdução com miniband',
     'Abdutores', ['Glúteos'], 'Elástico', 'forca',
     'Abdução de quadril', 'iniciante', False,
     'Afastar os joelhos contra o elástico, sentado ou deitado de lado.',
     ['Coloque o elástico logo acima dos joelhos.',
      'Sentado, com os pés no chão, afaste os joelhos contra o elástico.',
      'Segure um segundo e volte devagar.'],
     ['Deixar o elástico puxar os joelhos de volta rápido.',
      'Inclinar o tronco para ajudar.',
      'Elástico fraco demais.'],
     'Escolha um elástico que permita terminar as repetições com controle.',
     ['abdução', 'elástico', 'miniband', 'glúteo médio'],
     ['hip_abduction', 'cable_hip_abduction'], 3, '15-20', 45, load='nenhuma')

# ----- Panturrilha ----------------------------------------------------------------
novo('leg_press_calf_raise', 'Panturrilha no leg press', 'Gêmeos no leg press',
     'Panturrilha', ['Sóleo'], 'Máquina', 'forca',
     'Flexão plantar', 'iniciante', False,
     'Flexão plantar empurrando a plataforma do leg press com a ponta dos pés.',
     ['Sente no leg press e apoie só a ponta dos pés na borda de baixo da plataforma.',
      'Com os joelhos estendidos (sem travar), empurre a plataforma esticando os tornozelos.',
      'Volte devagar até sentir a panturrilha alongar.'],
     ['Destravar o leg press sem estar com os pés firmes.',
      'Dobrar os joelhos durante o movimento.',
      'Amplitude curta.'],
     'Cuidado: se o pé escorregar, a plataforma desce. Mantenha as travas por perto.',
     ['panturrilha', 'leg press', 'gêmeos'],
     ['calf_raise', 'smith_calf_raise', 'seated_calf_raise'], 4, '12-15', 45)

novo('single_leg_calf_raise', 'Panturrilha unilateral no degrau', 'Panturrilha com uma perna',
     'Panturrilha', ['Sóleo'], 'Halteres', 'forca',
     'Flexão plantar', 'iniciante', True,
     'Subir na ponta de um pé no degrau, com um halter na mão do mesmo lado.',
     ['Apoie a ponta de um pé no degrau e segure-se com a mão livre.',
      'Desça o calcanhar abaixo do degrau.',
      'Suba na ponta do pé o mais alto possível.',
      'Faça todas as repetições e troque de perna.'],
     ['Dobrar o joelho para ajudar.',
      'Amplitude curta.',
      'Subir rápido sem pausa no topo.'],
     'Pode ser feito sem halter. Segure-se em algo firme para não perder o equilíbrio.',
     ['panturrilha', 'unilateral', 'degrau', 'gêmeos'],
     ['calf_raise', 'smith_calf_raise'], 3, '12-15', 45)

# ----- Abdômen ---------------------------------------------------------------------
novo('cable_crunch', 'Abdominal na polia (ajoelhado)', 'Abdominal com corda',
     'Abdômen', ['Oblíquos'], 'Polia', 'forca',
     'Flexão de tronco', 'intermediario', False,
     'Flexão do tronco ajoelhado, puxando a corda da polia alta.',
     ['Ajoelhe de frente para a polia alta e segure a corda ao lado da cabeça.',
      'Flexione o tronco levando os cotovelos em direção às coxas.',
      'Volte devagar sem soltar a contração.'],
     ['Puxar com os braços.',
      'Sentar nos calcanhares (vira movimento de quadril).',
      'Carga alta com pouca amplitude.'],
     'Foque em enrolar a coluna. Evite com dor lombar ou hérnia ativa.',
     ['abdominal', 'polia', 'corda', 'reto abdominal'],
     ['crunch', 'ab_wheel_rollout'], 3, '12-15', 45)

novo('ab_wheel_rollout', 'Roda abdominal', 'Rollout',
     'Abdômen', ['Latíssimo do dorso', 'Transverso'], 'Roda abdominal', 'forca',
     'Isometria de core', 'avancado', False,
     'Rolar a roda à frente e voltar, mantendo o abdômen firme.',
     ['Ajoelhe e segure a roda à frente dos joelhos.',
      'Role a roda à frente devagar, sem deixar a lombar afundar.',
      'Vá só até onde conseguir manter a posição.',
      'Volte puxando com o abdômen.'],
     ['Deixar a lombar afundar.',
      'Ir longe demais logo no começo.',
      'Voltar puxando só com o quadril.'],
     'Exercício avançado. Comece com amplitude curta. Evite com dor lombar.',
     ['roda abdominal', 'rollout', 'core', 'abdômen'],
     ['plank', 'hollow_hold', 'dead_bug'], 3, '6-10', 60, load='peso do corpo')

novo('dead_bug', 'Dead bug (inseto morto)', 'Inseto morto',
     'Abdômen', ['Transverso', 'Reto abdominal'], 'Peso corporal', 'forca',
     'Isometria de core', 'iniciante', False,
     'Deitado de costas, estender braço e perna opostos mantendo a lombar no chão.',
     ['Deite de costas, braços estendidos para cima e joelhos a 90° no ar.',
      'Estenda um braço para trás e a perna oposta à frente, sem tirar a lombar do chão.',
      'Volte e repita do outro lado.'],
     ['Tirar a lombar do chão.',
      'Fazer rápido.',
      'Prender a respiração.'],
     'Bom para iniciantes e para reaprender o controle do core. Solte o ar ao estender.',
     ['dead bug', 'inseto morto', 'core', 'abdômen', 'estabilização'],
     ['bird_dog', 'hollow_hold', 'plank'], 3, '8-12 por lado', 45, load='peso do corpo')

novo('bird_dog', 'Perdigueiro (bird dog)', 'Quatro apoios alternado',
     'Abdômen', ['Eretor da espinha', 'Glúteos', 'Transverso'], 'Peso corporal', 'forca',
     'Isometria de core', 'iniciante', False,
     'Em quatro apoios, estender braço e perna opostos mantendo o tronco parado.',
     ['Fique em quatro apoios, mãos abaixo dos ombros e joelhos abaixo do quadril.',
      'Estenda um braço à frente e a perna oposta para trás.',
      'Segure 2 segundos sem girar o quadril.',
      'Volte e repita do outro lado.'],
     ['Girar o quadril ao levantar a perna.',
      'Arquear a lombar.',
      'Subir a perna acima da linha do tronco.'],
     'Movimento lento. Indicado também para quem tem dor lombar leve, com orientação.',
     ['bird dog', 'perdigueiro', 'core', 'lombar', 'estabilização'],
     ['dead_bug', 'side_plank'], 3, '8-12 por lado', 45, load='peso do corpo')

novo('hollow_hold', 'Canoa (hollow hold)', 'Hollow body',
     'Abdômen', ['Reto abdominal', 'Transverso'], 'Peso corporal', 'forca',
     'Isometria de core', 'intermediario', False,
     'Segurar o corpo em forma de canoa, deitado de costas, lombar no chão.',
     ['Deite de costas e encoste a lombar no chão.',
      'Tire os ombros e as pernas do chão, braços estendidos para trás.',
      'Segure a posição pelo tempo indicado.'],
     ['Lombar saindo do chão.',
      'Pernas baixas demais para a sua força.',
      'Prender a respiração.'],
     'Se a lombar sair do chão, dobre os joelhos ou suba as pernas.',
     ['canoa', 'hollow', 'core', 'isometria', 'abdômen'],
     ['plank', 'dead_bug', 'leg_raise'], 3, '', 45, timed=True, duration=30, load='peso do corpo')

# ----- Cardio ------------------------------------------------------------------------
CARDIO_CARE = 'Comece leve e aumente aos poucos. Pare se sentir dor no peito, falta de ar fora do normal ou tontura.'
novo('stationary_bike', 'Bicicleta ergométrica', 'Bike',
     'Corpo todo', ['Quadríceps', 'Glúteos', 'Gastrocnêmio'], 'Bicicleta', 'cardio',
     'Cardio', 'iniciante', False,
     'Pedalar na bicicleta ergométrica em ritmo contínuo ou intervalado.',
     ['Ajuste o banco: com o pedal embaixo, o joelho fica levemente dobrado.',
      'Comece com 3 a 5 minutos leves para aquecer.',
      'Mantenha o ritmo combinado pelo tempo do treino.',
      'Termine com alguns minutos leves.'],
     ['Banco baixo demais, forçando o joelho.',
      'Carga alta com pedalada muito lenta.',
      'Tronco jogado sobre o guidão.'],
     CARDIO_CARE,
     ['bike', 'bicicleta', 'cardio', 'aeróbico'],
     ['elliptical', 'rowing_machine', 'treadmill_run_walk'], 1, '', 0, timed=True, duration=1200, load='nenhuma')

novo('elliptical', 'Elíptico', 'Transport',
     'Corpo todo', ['Quadríceps', 'Glúteos', 'Posteriores de coxa'], 'Elíptico', 'cardio',
     'Cardio', 'iniciante', False,
     'Movimento contínuo no elíptico, com baixo impacto nas articulações.',
     ['Suba com os pés no centro dos pedais e segure as alças.',
      'Comece leve por 3 a 5 minutos.',
      'Mantenha o ritmo combinado com o tronco ereto.',
      'Termine com alguns minutos leves.'],
     ['Apoiar o peso do corpo nas alças.',
      'Ficar na ponta dos pés.',
      'Curvar o tronco.'],
     CARDIO_CARE,
     ['elíptico', 'transport', 'cardio', 'baixo impacto'],
     ['stationary_bike', 'stair_climber', 'treadmill_run_walk'], 1, '', 0, timed=True, duration=1200, load='nenhuma')

novo('rowing_machine', 'Remo ergômetro', 'Remo seco',
     'Corpo todo', ['Latíssimo do dorso', 'Quadríceps', 'Glúteos', 'Bíceps braquial'], 'Remo', 'cardio',
     'Cardio', 'intermediario', False,
     'Remada contínua no remo ergômetro: pernas, tronco e braços em sequência.',
     ['Prenda os pés e segure o puxador com os braços estendidos.',
      'Empurre com as pernas, depois incline o tronco levemente para trás e puxe o puxador até o abdômen.',
      'Volte na ordem inversa: braços, tronco e pernas.',
      'Mantenha o ritmo combinado.'],
     ['Puxar com os braços antes de empurrar com as pernas.',
      'Arredondar as costas.',
      'Jogar o tronco muito para trás.'],
     CARDIO_CARE + ' Evite com dor lombar até dominar a técnica.',
     ['remo', 'remo ergômetro', 'cardio', 'corpo todo'],
     ['stationary_bike', 'elliptical'], 1, '', 0, timed=True, duration=900, load='nenhuma')

novo('stair_climber', 'Escada (simulador)', 'Escada ergométrica',
     'Corpo todo', ['Quadríceps', 'Glúteos', 'Gastrocnêmio'], 'Escada', 'cardio',
     'Cardio', 'intermediario', False,
     'Subir degraus contínuos no simulador de escada.',
     ['Suba no aparelho segurando os apoios laterais.',
      'Comece numa velocidade lenta por alguns minutos.',
      'Suba apoiando o pé inteiro no degrau, tronco ereto.',
      'Termine reduzindo a velocidade.'],
     ['Apoiar o peso do corpo nas alças.',
      'Pisar só com a ponta do pé.',
      'Velocidade alta demais logo no começo.'],
     CARDIO_CARE,
     ['escada', 'simulador de escada', 'cardio', 'glúteos'],
     ['elliptical', 'treadmill_run_walk', 'step_up'], 1, '', 0, timed=True, duration=900, load='nenhuma')

# ----- Bloco B: versões gerais de exercícios do plano do Mattheus ------------------
novo('pendulum_squat', 'Agachamento pêndulo', 'Pêndulo',
     'Quadríceps', ['Glúteos', 'Adutores'], 'Máquina', 'forca',
     'Agachamento', 'iniciante', False,
     'Agachamento na máquina pêndulo, com as costas apoiadas.',
     ['Apoie as costas e os ombros nas almofadas, pés no meio da plataforma.',
      'Destrave e desça dobrando os joelhos até onde for confortável.',
      'Suba empurrando a plataforma sem travar os joelhos.'],
     ['Tirar os calcanhares da plataforma.',
      'Joelhos caindo para dentro.',
      'Descer rápido e quicar no fundo.'],
     'Ajuste a amplitude à sua mobilidade. Evite com dor no joelho ao descer.',
     ['agachamento', 'pêndulo', 'quadríceps', 'máquina'],
     ['hack_squat', 'leg_press', 'smith_squat'], 3, '8-12', 90, bloco='B')

novo('hip_adduction', 'Cadeira adutora', 'Adutora',
     'Adutores', [], 'Máquina', 'forca',
     'Adução de quadril', 'iniciante', False,
     'Fechar as pernas contra as almofadas da máquina adutora.',
     ['Sente com as costas apoiadas e as almofadas na parte de dentro dos joelhos.',
      'Feche as pernas até as almofadas quase se encostarem.',
      'Volte devagar até a abertura confortável.'],
     ['Abertura inicial maior que o confortável.',
      'Soltar o peso na volta.',
      'Tirar o quadril do banco.'],
     'Ajuste a abertura antes de colocar carga.',
     ['adutora', 'adutores', 'parte interna da coxa', 'máquina'],
     ['side_lunge'], 3, '12-15', 45, bloco='B')

novo('treadmill_run_walk', 'Corrida/caminhada na esteira', 'Esteira',
     'Corpo todo', ['Quadríceps', 'Posteriores de coxa', 'Gastrocnêmio'], 'Esteira', 'cardio',
     'Cardio', 'iniciante', False,
     'Caminhada ou corrida na esteira, contínua ou intervalada.',
     ['Prenda a chave de segurança na roupa antes de começar.',
      'Comece caminhando por 3 a 5 minutos.',
      'Aumente a velocidade ou a inclinação até o ritmo combinado.',
      'Termine caminhando alguns minutos.'],
     ['Segurar no painel durante a corrida.',
      'Passada longa demais, batendo o calcanhar à frente do corpo.',
      'Inclinação alta segurando nas alças.'],
     CARDIO_CARE,
     ['esteira', 'corrida', 'caminhada', 'cardio'],
     ['elliptical', 'stationary_bike', 'stair_climber'], 1, '', 0, timed=True, duration=1200, load='nenhuma', bloco='B')

novo('dumbbell_shrug', 'Encolhimento com halteres', 'Encolhimento',
     'Costas', ['Trapézio'], 'Halteres', 'forca',
     'Elevação de escápulas', 'iniciante', False,
     'Elevar os ombros em direção às orelhas segurando halteres.',
     ['Em pé, um halter em cada mão ao lado do corpo.',
      'Suba os ombros em direção às orelhas, sem dobrar os cotovelos.',
      'Segure um segundo e desça devagar.'],
     ['Girar os ombros.',
      'Dobrar os cotovelos para ajudar.',
      'Projetar a cabeça à frente.'],
     'Movimento só para cima e para baixo. Evite com dor no pescoço.',
     ['encolhimento', 'trapézio', 'halteres'],
     ['farmer_walk', 'face_pull'], 3, '12-15', 45, bloco='B')

novo('smith_calf_raise', 'Panturrilha no Smith', 'Gêmeos no Smith',
     'Panturrilha', ['Sóleo'], 'Smith', 'forca',
     'Flexão plantar', 'iniciante', False,
     'Subir na ponta dos pés com a barra do Smith nas costas.',
     ['Barra do Smith nas costas, ponta dos pés sobre uma anilha ou degrau.',
      'Desça os calcanhares abaixo da linha da ponta dos pés.',
      'Suba o mais alto possível e segure um segundo.',
      'Desça devagar.'],
     ['Dobrar os joelhos.',
      'Amplitude curta.',
      'Pés escorregando do apoio.'],
     'Use um apoio firme para os pés e trave a barra ao terminar.',
     ['panturrilha', 'smith', 'gêmeos'],
     ['calf_raise', 'leg_press_calf_raise', 'single_leg_calf_raise'], 4, '12-15', 45, bloco='B')

novo('incline_dumbbell_curl', 'Rosca inclinada com halteres (banco 45°)', 'Rosca 45°',
     'Bíceps', ['Braquial'], 'Halteres', 'forca',
     'Flexão de cotovelo', 'intermediario', False,
     'Rosca sentado no banco inclinado, braços pendurados atrás da linha do tronco.',
     ['Ajuste o banco a 45° e sente com as costas apoiadas, halteres pendurados.',
      'Flexione os cotovelos sem levar os braços à frente.',
      'Desça devagar até quase estender.'],
     ['Tirar as costas do banco.',
      'Levar os cotovelos à frente.',
      'Usar a mesma carga da rosca em pé.'],
     'Posição alonga bastante o bíceps: comece leve. Evite com dor na frente do ombro.',
     ['rosca', 'inclinada', 'rosca 45', 'bíceps', 'halteres'],
     ['alternating_dumbbell_curl', 'bicep_curl', 'preacher_curl'], 3, '10-12', 60, bloco='B')

novo('single_arm_overhead_triceps_extension', 'Tríceps francês unilateral com halter', 'Tríceps francês com um braço',
     'Tríceps', [], 'Halteres', 'forca',
     'Extensão de cotovelo', 'iniciante', True,
     'Extensão do cotovelo com um halter atrás da cabeça, um braço de cada vez.',
     ['Sentado, segure o halter com o braço estendido acima da cabeça.',
      'Dobre o cotovelo levando o halter para trás da cabeça.',
      'Estenda o cotovelo de volta sem mover o braço.',
      'Faça todas as repetições e troque de braço.'],
     ['Abrir o cotovelo para o lado.',
      'Arquear a lombar.',
      'Descer rápido demais.'],
     'Use a outra mão para apoiar o braço que trabalha. Evite com dor no ombro.',
     ['tríceps', 'francês', 'unilateral', 'halter'],
     ['barbell_overhead_triceps_extension', 'tricep_extension', 'triceps_kickback'], 3, '10-12', 45, bloco='B')


# ---------------------------------------------------------------------------
# Exercícios gerais existentes (71): erros comuns, cuidados, tags, alternativas.
# Campos que já tinham conteúdo ficam como estão (o gravador só preenche vazio).
# ---------------------------------------------------------------------------
EXIST = {}


def ex(id, mistakes, care, tags, alts):
    assert id not in EXIST, id
    EXIST[id] = {
        'commonMistakes': mistakes,
        'careNotes': care,
        'searchTags': tags,
        'alternativeExerciseIds': alts,
    }


SEM_DOR_OMBRO = 'Evite ou reduza a amplitude se sentir dor no ombro.'
LOMBAR = 'Mantenha a coluna neutra. Evite carga alta com dor lombar.'
JOELHO = 'Evite carga alta ou amplitude total se sentir dor no joelho.'

# Peito
ex('bench_press', ['Tirar o quadril do banco.', 'Quicar a barra no peito.', 'Abrir demais os cotovelos.'],
   'Use alguém para ajudar com carga alta. ' + SEM_DOR_OMBRO,
   ['supino', 'peito', 'barra', 'empurrar'], ['dumbbell_bench_press', 'machine_chest_press', 'push_up', 'decline_bench_press'])
ex('dumbbell_bench_press', ['Descer os halteres sem controle.', 'Bater os halteres no topo.', 'Abrir demais os cotovelos.'],
   SEM_DOR_OMBRO, ['supino', 'halteres', 'peito'], [])
ex('incline_dumbbell_press', ['Banco inclinado demais (vira ombro).', 'Tirar o quadril do banco.', 'Descer sem controle.'],
   SEM_DOR_OMBRO, ['supino inclinado', 'peito superior', 'halteres'], [])
ex('machine_chest_press', ['Banco na altura errada (alças acima do ombro).', 'Tirar as costas do encosto.', 'Travar os cotovelos com força.'],
   'Boa opção para iniciantes. ' + SEM_DOR_OMBRO, ['supino', 'máquina', 'peito'], [])
ex('push_up', ['Quadril caindo ou empinado.', 'Cotovelos muito abertos.', 'Amplitude curta.'],
   'Apoie os joelhos ou faça na parede se ainda não conseguir com o corpo reto. Evite com dor no punho.',
   ['flexão', 'apoio', 'peito', 'peso corporal'], ['wall_push_up', 'bench_press', 'dumbbell_bench_press', 'machine_chest_press'])
ex('wall_push_up', ['Pés perto demais da parede.', 'Quadril para trás.', 'Descer pouco.'],
   'Boa porta de entrada para a flexão de braço.', ['flexão na parede', 'iniciante', 'peito', 'idoso'],
   ['push_up', 'machine_chest_press'])
ex('cable_crossover', ['Dobrar e esticar os cotovelos (vira supino).', 'Arquear a lombar.', 'Soltar o peso rápido na volta.'],
   'Abdômen firme e passo à frente para ter estabilidade.', ['crossover', 'crossover alto', 'polia alta', 'peito', 'cabo'],
   ['pec_deck', 'dumbbell_fly', 'low_cable_crossover'])
ex('pec_deck', ['Banco na altura errada (cotovelos acima do ombro).', 'Abrir além do confortável.', 'Soltar o peso na volta.'],
   SEM_DOR_OMBRO, ['voador', 'peck deck', 'crucifixo máquina', 'peito'], ['cable_crossover', 'dumbbell_fly', 'incline_dumbbell_fly'])

# Costas
ex('bent_over_row', ['Arredondar a coluna.', 'Levantar o tronco a cada repetição.', 'Puxar só com os braços.'],
   LOMBAR, ['remada', 'remada curvada', 'costas', 'barra'], ['t_bar_row', 'seated_cable_row', 'dumbbell_row', 'single_arm_cable_row'])
ex('dumbbell_row', ['Girar o tronco para puxar.', 'Encolher o ombro.', 'Costas arredondadas.'],
   'Apoie mão e joelho no banco e mantenha a coluna neutra.', ['remada', 'serrote', 'unilateral', 'halter', 'costas'],
   ['single_arm_cable_row', 'bent_over_row', 'seated_cable_row'])
ex('seated_cable_row', ['Jogar o tronco para trás.', 'Arredondar as costas na volta.', 'Encolher os ombros.'],
   LOMBAR, ['remada baixa', 'polia', 'costas', 'remada sentada'], ['bent_over_row', 't_bar_row', 'dumbbell_row', 'single_arm_cable_row'])
ex('lat_pulldown', ['Puxar a barra atrás da nuca.', 'Jogar o tronco para trás.', 'Não completar a descida.'],
   'Puxe sempre pela frente, até a parte de cima do peito.', ['puxada', 'puxada frontal', 'costas', 'dorsal', 'polia'],
   ['pull_up', 'close_grip_lat_pulldown', 'reverse_grip_lat_pulldown'])
ex('close_grip_lat_pulldown', ['Jogar o tronco para trás.', 'Encolher os ombros.', 'Soltar rápido na subida.'],
   'Evite balançar o tronco para puxar a carga.', ['puxada', 'triângulo', 'puxada neutra', 'pegada neutra', 'costas'],
   ['lat_pulldown', 'reverse_grip_lat_pulldown', 'pull_up'])
ex('pull_up', ['Balançar o corpo (kipping) sem controle.', 'Não estender os braços embaixo.', 'Projetar o queixo à frente.'],
   'Use elástico ou a máquina de barra assistida até conseguir com o peso do corpo. ' + SEM_DOR_OMBRO,
   ['barra fixa', 'pull up', 'costas', 'peso corporal'], ['lat_pulldown', 'close_grip_lat_pulldown', 'reverse_grip_lat_pulldown'])
ex('face_pull', ['Puxar baixo demais (na altura do peito).', 'Usar carga alta e perder a rotação.', 'Jogar o tronco para trás.'],
   'Carga leve a moderada, foco na postura.', ['face pull', 'deltoide posterior', 'manguito', 'polia', 'postura'],
   ['rear_delt_fly', 'machine_rear_delt_fly', 'band_pull_apart'])
ex('cat_cow', ['Fazer rápido.', 'Mexer só o pescoço.', 'Prender a respiração.'],
   'Movimento sem dor e dentro da amplitude confortável.', ['gato e camelo', 'mobilidade', 'coluna', 'aquecimento'],
   ['thoracic_rotation', 'hip_90_90'])
ex('thoracic_rotation', ['Girar o quadril junto.', 'Forçar a amplitude.', 'Prender a respiração.'],
   'Sem dor; vá só até onde for confortável.', ['rotação torácica', 'mobilidade torácica', 'coluna', 'aquecimento'],
   ['cat_cow', 'band_shoulder_dislocate'])

# Ombros
ex('shoulder_press', ['Arquear a lombar.', 'Empurrar a barra à frente do rosto.', 'Descer pouco.'],
   'Abdômen e glúteos firmes. ' + SEM_DOR_OMBRO, ['desenvolvimento', 'militar', 'ombro', 'barra'],
   ['dumbbell_shoulder_press', 'machine_shoulder_press'])
ex('dumbbell_shoulder_press', ['Arquear a lombar.', 'Bater os halteres no topo.', 'Descer pouco.'],
   SEM_DOR_OMBRO, ['desenvolvimento', 'halteres', 'ombro'], ['shoulder_press', 'machine_shoulder_press'])
ex('lateral_raise', ['Balançar o tronco.', 'Subir acima da linha do ombro.', 'Encolher os ombros.'],
   'Carga leve e controle. ' + SEM_DOR_OMBRO, ['elevação lateral', 'deltoide lateral', 'ombro', 'halteres'],
   ['cable_lateral_raise', 'machine_lateral_raise'])
ex('cable_lateral_raise', ['Inclinar o tronco para longe da polia.', 'Encolher o ombro.', 'Subir acima da linha do ombro.'],
   'Faça o mesmo número de repetições dos dois lados.', ['elevação lateral', 'polia', 'unilateral', 'ombro'],
   ['lateral_raise', 'machine_lateral_raise'])
ex('rear_delt_fly', ['Usar as costas (remada) em vez do ombro.', 'Balançar o tronco.', 'Carga alta.'],
   'Mantenha a coluna neutra com o tronco inclinado.', ['crucifixo inverso', 'deltoide posterior', 'halteres'],
   ['machine_rear_delt_fly', 'face_pull', 'band_pull_apart'])
ex('machine_rear_delt_fly', ['Juntar as escápulas e usar as costas.', 'Banco na altura errada.', 'Soltar o peso na volta.'],
   'Ajuste o banco para as alças ficarem na altura dos ombros.', ['crucifixo inverso', 'máquina', 'deltoide posterior', 'voador invertido'],
   ['rear_delt_fly', 'face_pull', 'band_pull_apart'])
ex('band_pull_apart', ['Encolher os ombros.', 'Dobrar os cotovelos.', 'Elástico forte demais.'],
   'Bom para aquecer e para postura.', ['abertura com elástico', 'deltoide posterior', 'postura', 'aquecimento'],
   ['face_pull', 'rear_delt_fly', 'machine_rear_delt_fly'])
ex('band_external_rotation', ['Afastar o cotovelo do corpo.', 'Girar o tronco.', 'Elástico forte demais.'],
   'Movimento lento e leve. Em reabilitação, siga o fisioterapeuta.', ['rotação externa', 'manguito rotador', 'elástico', 'prevenção'],
   ['cable_external_rotation', 'face_pull'])

# Bíceps / Antebraço
ex('bicep_curl', ['Balançar o tronco.', 'Levar os cotovelos à frente.', 'Descer rápido.'],
   'Evite balançar se tiver dor lombar.', ['rosca direta', 'bíceps', 'barra'],
   ['cable_curl', 'alternating_dumbbell_curl', 'preacher_curl', 'hammer_curl'])
ex('cable_curl', ['Afastar os cotovelos do corpo.', 'Inclinar o tronco para trás.', 'Soltar o peso rápido.'],
   'Mantenha os punhos retos.', ['rosca', 'polia', 'bíceps', 'rosca na polia'], ['bicep_curl', 'preacher_curl', 'alternating_dumbbell_curl'])
ex('hammer_curl', ['Balançar o tronco.', 'Girar o punho durante o movimento.', 'Levar os cotovelos à frente.'],
   'Boa opção se a rosca direta incomoda o punho.', ['rosca martelo', 'braquial', 'antebraço', 'halteres'],
   ['reverse_curl', 'alternating_dumbbell_curl', 'bicep_curl'])
ex('dead_hang', ['Ombros encolhidos perto das orelhas.', 'Balançar o corpo.', 'Soltar de uma vez.'],
   'Comece com poucos segundos. ' + SEM_DOR_OMBRO, ['suspensão', 'pegada', 'antebraço', 'barra fixa'],
   ['farmer_walk', 'pull_up'])

# Tríceps
ex('tricep_extension', ['Abrir os cotovelos.', 'Descer o peso rápido em direção à testa.', 'Mover os ombros.'],
   'Use carga que você controle bem: o peso passa perto do rosto.', ['tríceps testa', 'tríceps', 'halteres'],
   ['barbell_overhead_triceps_extension', 'triceps_pushdown', 'triceps_bar_pushdown'])
ex('triceps_pushdown', ['Afastar os cotovelos do corpo.', 'Jogar o peso do corpo sobre a corda.', 'Não abrir a corda embaixo.'],
   'Mantenha os punhos firmes e os cotovelos parados.', ['tríceps corda', 'tríceps', 'polia', 'pulley', 'corda'],
   ['triceps_bar_pushdown', 'tricep_extension', 'triceps_kickback'])

# Pernas
ex('squat', ['Joelhos caindo para dentro.', 'Arredondar a lombar no fundo.', 'Tirar os calcanhares do chão.'],
   'Aprenda com carga leve e acompanhamento. ' + JOELHO, ['agachamento', 'agachamento livre', 'quadríceps', 'barra'],
   ['front_squat', 'smith_squat', 'hack_squat', 'leg_press'])
ex('hack_squat', ['Tirar os calcanhares da plataforma.', 'Joelhos caindo para dentro.', 'Travar os joelhos no topo.'],
   JOELHO, ['hack', 'agachamento', 'quadríceps', 'máquina'], ['leg_press', 'smith_squat', 'pendulum_squat', 'squat'])
ex('leg_press', ['Tirar o quadril do banco no fundo.', 'Travar os joelhos no topo.', 'Joelhos caindo para dentro.'],
   'Não desça além do ponto em que o quadril sai do encosto. ' + JOELHO, ['leg press', 'quadríceps', 'pernas', 'máquina'],
   ['hack_squat', 'pendulum_squat', 'smith_squat', 'squat'])
ex('leg_extension', ['Chutar o peso.', 'Tirar o quadril do banco.', 'Descer rápido.'],
   'Ajuste o eixo da máquina ao joelho. ' + JOELHO, ['extensora', 'cadeira extensora', 'quadríceps', 'máquina'],
   ['single_leg_extension', 'leg_press', 'bulgarian_split_squat'])
ex('bulgarian_split_squat', ['Pé da frente perto demais do banco.', 'Joelho caindo para dentro.', 'Tronco desabando à frente.'],
   'Comece sem carga para achar a distância do banco. Segure-se em algo se faltar equilíbrio.',
   ['búlgaro', 'agachamento búlgaro', 'unilateral', 'pernas'], ['lunge', 'smith_lunge', 'step_up'])
ex('lunge', ['Passo curto demais.', 'Joelho da frente caindo para dentro.', 'Tronco inclinado à frente.'],
   JOELHO, ['afundo', 'avanço', 'passada', 'unilateral'], ['bulgarian_split_squat', 'smith_lunge', 'step_up'])
ex('side_lunge', ['Joelho passando muito da ponta do pé.', 'Pé da perna dobrada girando para fora.', 'Costas arredondadas.'],
   'Amplitude confortável para a parte interna da coxa.', ['afundo lateral', 'adutores', 'unilateral'],
   ['lunge', 'bulgarian_split_squat', 'hip_adduction'])
ex('step_up', ['Empurrar com o pé de baixo.', 'Joelho caindo para dentro.', 'Degrau alto demais.'],
   'Use um degrau firme. Comece baixo.', ['subida no degrau', 'step', 'unilateral', 'pernas'],
   ['lunge', 'bulgarian_split_squat', 'smith_lunge'])
ex('sit_to_stand', ['Usar as mãos para levantar.', 'Joelhos para dentro.', 'Cair sentado sem controle.'],
   'Use uma cadeira firme encostada na parede.', ['sentar e levantar', 'idoso', 'iniciante', 'funcional'],
   ['leg_press', 'step_up', 'smith_squat'])
ex('box_jump', ['Aterrissar com os joelhos para dentro.', 'Caixa alta demais.', 'Descer pulando para trás.'],
   'Desça da caixa andando. Evite com dor no joelho ou no tornozelo.', ['salto na caixa', 'pliometria', 'potência'],
   ['squat_jump', 'lateral_bound'])
ex('squat_jump', ['Aterrissar com as pernas esticadas.', 'Joelhos para dentro na aterrissagem.', 'Sem pausa entre os saltos.'],
   'Aterrisse macio, dobrando os joelhos. Evite com dor no joelho.', ['agachamento com salto', 'pliometria', 'salto'],
   ['box_jump', 'lateral_bound'])
ex('lateral_bound', ['Aterrissar sem controle.', 'Joelho caindo para dentro.', 'Saltos longos demais no começo.'],
   'Comece com saltos curtos. Evite com instabilidade no tornozelo.', ['salto lateral', 'pliometria', 'agilidade'],
   ['box_jump', 'squat_jump', 'side_lunge'])
ex('leg_curl', ['Levantar o quadril do banco.', 'Soltar o peso na descida.', 'Amplitude curta.'],
   'Mantenha o quadril no banco.', ['mesa flexora', 'flexora', 'posterior de coxa', 'máquina'],
   ['seated_leg_curl', 'single_leg_curl', 'nordic_curl'])
ex('nordic_curl', ['Cair de uma vez.', 'Dobrar o quadril.', 'Fazer sem ajuda antes da hora.'],
   'Exercício intenso: use apoio ou elástico e poucas repetições no começo.', ['flexão nórdica', 'nordic', 'posterior de coxa'],
   ['leg_curl', 'seated_leg_curl', 'romanian_deadlift'])
ex('romanian_deadlift', ['Arredondar as costas.', 'Dobrar demais os joelhos.', 'Afastar a barra das pernas.'],
   LOMBAR, ['stiff', 'terra romeno', 'posterior de coxa', 'barra'], ['dumbbell_romanian_deadlift', 'good_morning', 'deadlift'])
ex('deadlift', ['Arredondar as costas.', 'Barra longe das pernas.', 'Hiperestender a lombar no topo.'],
   'Aprenda com acompanhamento e carga leve. ' + LOMBAR, ['levantamento terra', 'terra', 'deadlift', 'barra'],
   ['romanian_deadlift', 'dumbbell_romanian_deadlift', 'back_extension_45'])
ex('kettlebell_swing', ['Agachar em vez de dobrar o quadril.', 'Levantar com os braços.', 'Arredondar as costas.'],
   'O impulso vem do quadril. ' + LOMBAR, ['kettlebell', 'swing', 'balanço', 'quadril'],
   ['hip_thrust', 'back_extension_45', 'romanian_deadlift'])
ex('hip_thrust', ['Arquear a lombar no topo.', 'Empurrar com a ponta dos pés.', 'Apoio do banco alto demais nas costas.'],
   'Use proteção na barra sobre o quadril.', ['elevação pélvica', 'hip thrust', 'glúteos', 'barra'],
   ['glute_bridge', 'single_leg_hip_thrust', 'cable_kickback'])
ex('glute_bridge', ['Arquear a lombar no topo.', 'Pés longe demais do quadril.', 'Joelhos abrindo ou fechando.'],
   'Boa opção para iniciantes e para aquecer.', ['ponte', 'ponte de glúteos', 'glúteos', 'peso corporal'],
   ['hip_thrust', 'single_leg_hip_thrust'])
ex('cable_kickback', ['Arquear a lombar.', 'Girar o quadril.', 'Balançar a perna.'],
   'Abdômen firme; faça o mesmo número de repetições dos dois lados.', ['coice', 'polia', 'glúteos', 'unilateral'],
   ['ankle_weight_kickback', 'hip_thrust', 'glute_bridge'])
ex('hip_abduction', ['Soltar o peso na volta.', 'Inclinar o tronco à frente sem querer.', 'Amplitude curta.'],
   'Controle a volta das pernas.', ['abdutora', 'cadeira abdutora', 'glúteo médio', 'máquina'],
   ['cable_hip_abduction', 'band_hip_abduction'])
ex('calf_raise', ['Amplitude curta.', 'Dobrar os joelhos.', 'Subir rápido sem pausa.'],
   'Desça devagar até alongar bem a panturrilha.', ['panturrilha', 'gêmeos', 'em pé'],
   ['smith_calf_raise', 'leg_press_calf_raise', 'single_leg_calf_raise'])
ex('seated_calf_raise', ['Amplitude curta.', 'Quicar no fundo.', 'Subir rápido.'],
   'Trabalha mais o sóleo (joelho dobrado).', ['panturrilha sentado', 'sóleo', 'máquina'],
   ['calf_raise', 'leg_press_calf_raise'])
ex('ankle_mobility', ['Tirar o calcanhar do chão.', 'Joelho caindo para dentro.', 'Forçar a amplitude.'],
   'Sem dor; aumente a distância da parede aos poucos.', ['mobilidade de tornozelo', 'tornozelo', 'aquecimento'],
   ['single_leg_balance', 'heel_toe_walk'])
ex('hip_90_90', ['Arredondar as costas.', 'Forçar o joelho.', 'Usar as mãos para compensar o tempo todo.'],
   'Sem dor no joelho ou no quadril.', ['90/90', 'mobilidade de quadril', 'quadril', 'aquecimento'],
   ['cat_cow', 'hip_escape'])

# Abdômen
ex('crunch', ['Puxar o pescoço com as mãos.', 'Subir o tronco inteiro.', 'Fazer rápido.'],
   'Mãos só apoiando a cabeça.', ['abdominal', 'abdominal supra', 'reto abdominal'], ['cable_crunch', 'dead_bug', 'leg_raise'])
ex('leg_raise', ['Lombar saindo do chão.', 'Descer as pernas rápido.', 'Usar impulso.'],
   'Se a lombar sair do chão, dobre os joelhos.', ['elevação de pernas', 'abdominal infra', 'infra', 'abdômen'],
   ['dead_bug', 'crunch', 'hollow_hold'])
ex('plank', ['Quadril caindo.', 'Quadril alto demais.', 'Prender a respiração.'],
   'Comece com tempos curtos e aumente aos poucos.', ['prancha', 'core', 'isometria', 'abdômen'],
   ['side_plank', 'hollow_hold', 'dead_bug', 'ab_wheel_rollout'])
ex('side_plank', ['Quadril caindo.', 'Ombro longe do cotovelo de apoio.', 'Girar o tronco.'],
   'Apoie o joelho de baixo para facilitar. ' + SEM_DOR_OMBRO, ['prancha lateral', 'oblíquos', 'core'],
   ['plank', 'russian_twist', 'bird_dog'])
ex('russian_twist', ['Girar só os braços.', 'Arredondar as costas.', 'Fazer rápido.'],
   'Evite com dor lombar; pode fazer com os pés no chão.', ['rotação russa', 'oblíquos', 'abdômen'],
   ['side_plank', 'cable_crunch'])
ex('mountain_climber', ['Quadril alto.', 'Ombros atrás das mãos.', 'Perder o ritmo e a postura.'],
   'Mãos abaixo dos ombros. Evite com dor no punho.', ['escalador', 'mountain climber', 'hiit', 'core'],
   ['burpee', 'plank', 'bear_crawl'])

# Corpo todo / funcionais
ex('burpee', ['Cair no chão sem controle.', 'Quadril caindo na prancha.', 'Aterrissar com as pernas esticadas.'],
   'Pode tirar o salto ou a flexão para facilitar.', ['burpee', 'hiit', 'corpo todo', 'cardio'],
   ['mountain_climber', 'squat_jump', 'jump_rope'])
ex('bear_crawl', ['Quadril alto.', 'Joelhos encostando no chão.', 'Passos longos demais.'],
   'Joelhos baixos e coluna neutra.', ['caminhada do urso', 'core', 'locomoção'], ['mountain_climber', 'plank'])
ex('farmer_walk', ['Inclinar o corpo para um lado.', 'Ombros encolhidos.', 'Passos rápidos e curtos.'],
   'Comece com carga moderada e distância curta.', ['caminhada do fazendeiro', 'pegada', 'carregar', 'core'],
   ['dead_hang', 'dumbbell_shrug'])
ex('jump_rope', ['Saltar alto demais.', 'Girar a corda com os braços inteiros.', 'Aterrissar nos calcanhares.'],
   'Comece com blocos curtos. Evite com dor no tornozelo ou na canela.', ['pular corda', 'corda', 'cardio'],
   ['burpee', 'shadow_boxing', 'stationary_bike'])
ex('shadow_boxing', ['Esticar o cotovelo até travar.', 'Abaixar a guarda.', 'Ficar parado nos pés.'],
   'Não trave os cotovelos nos golpes.', ['sombra', 'boxe', 'cardio'], ['jump_rope', 'elliptical'])
ex('med_ball_slam', ['Arredondar as costas para pegar a bola.', 'Usar só os braços.', 'Bola que quica muito.'],
   'Use bola própria para arremesso (que não quica). ' + LOMBAR, ['arremesso', 'bola medicinal', 'slam', 'potência'],
   ['kettlebell_swing', 'burpee'])
ex('heel_toe_walk', ['Olhar para os pés.', 'Passos rápidos.', 'Sem apoio por perto.'],
   'Faça perto de uma parede para se apoiar se precisar.', ['equilíbrio', 'caminhada', 'idoso'],
   ['single_leg_balance', 'ankle_mobility'])
ex('single_leg_balance', ['Travar o joelho de apoio.', 'Prender a respiração.', 'Sem apoio por perto.'],
   'Faça perto de um apoio firme.', ['equilíbrio', 'unilateral', 'idoso', 'tornozelo'],
   ['heel_toe_walk', 'step_up'])
ex('hip_escape', ['Fazer rápido sem controle.', 'Não usar os pés para empurrar.', 'Tirar os ombros do chão.'],
   'Movimento de mobilidade: sem dor.', ['fuga de quadril', 'mobilidade', 'chão', 'quadril'],
   ['hip_90_90', 'bear_crawl'])

# Exercício existente que passa a ser só "com corda" (a versão com barra vira
# exercício próprio: triceps_bar_pushdown). O vídeo atual já mostra a corda.
RENOMEAR = {
    'triceps_pushdown': {
        'name': 'Tríceps na polia com corda',
        'alternateName': 'Tríceps corda',
        'description': 'Isola o tríceps com a corda na polia alta.',
    },
}

EQUIPAMENTOS_NOVOS = {'roda_abdominal': 'Roda abdominal'}

if __name__ == '__main__':
    novos = {k: {kk: vv for kk, vv in v.items() if kk != '_bloco'} for k, v in NOVOS.items()}
    blocos = {k: v['_bloco'] for k, v in NOVOS.items()}
    data = {
        'novos': novos,
        'blocoDosNovos': blocos,
        'existentes': EXIST,
        'renomear': RENOMEAR,
        'equipamentosNovos': EQUIPAMENTOS_NOVOS,
    }
    path = os.path.join(here, 'etapa3_fichas.json')
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
    print(f'novos {len(novos)} (A {list(blocos.values()).count("A")}, B {list(blocos.values()).count("B")}) · existentes {len(EXIST)} -> {path}')
