# Etapa 3 · Parte A — exercícios novos propostos (só lista, nada gravado)

Base: lista do pedido original da Etapa 3 + exercícios do plano do Mattheus que só
existem como exercício do personal. Comparado com os **71 gerais** e os **11 do
personal** que estão hoje no Firestore real, por nome **e** por movimento.

Os IDs são sugestões (novos, não colidem com nenhum existente). Nada aqui foi
gravado. Instruções, secundários, padrão, dificuldade, séries/reps/descanso,
erros comuns, cuidados, tags e alternativas entram na Parte B, depois da sua
aprovação. Vídeo e imagem ficam vazios.

## Resumo por grupo (Bloco A — novos de fato)

| Grupo | Quantos |
|---|---|
| Peito | 4 |
| Costas | 4 |
| Ombros | 5 (4 de força + 1 de mobilidade) |
| Bíceps | 3 |
| Antebraço | 1 |
| Tríceps | 3 |
| Quadríceps | 4 |
| Posteriores de coxa | 4 |
| Glúteos | 3 |
| Abdutores | 2 |
| Panturrilha | 2 |
| Abdômen | 5 |
| Corpo todo (cardio) | 4 |
| **Total** | **44** |

Mais o **Bloco B** (7, opcional — precisa da sua decisão, ver abaixo).

## Bloco A — novos

Categoria: `forca`, `mobilidade` ou `cardio`. Uni = unilateral.

### Peito (4)
| ID | Nome | Equipamento | Categoria | Uni |
|---|---|---|---|---|
| decline_bench_press | Supino declinado | Barra | força | não |
| dumbbell_fly | Crucifixo reto com halteres | Halteres | força | não |
| incline_dumbbell_fly | Crucifixo inclinado com halteres | Halteres | força | não |
| low_cable_crossover | Crossover baixo (polia baixa) | Polia | força | não |

### Costas (4)
| ID | Nome | Equipamento | Categoria | Uni |
|---|---|---|---|---|
| t_bar_row | Remada cavalinho | Barra | força | não |
| single_arm_cable_row | Remada unilateral na polia | Polia | força | **sim** |
| reverse_grip_lat_pulldown | Puxada supinada | Polia | força | não |
| cable_pullover | Pullover na polia | Polia | força | não |

### Ombros (5)
| ID | Nome | Equipamento | Categoria | Uni |
|---|---|---|---|---|
| front_raise | Elevação frontal com halteres | Halteres | força | não |
| machine_shoulder_press | Desenvolvimento na máquina | Máquina | força | não |
| machine_lateral_raise | Elevação lateral na máquina | Máquina | força | não |
| cable_external_rotation | Rotação externa na polia | Polia | força | **sim** |
| band_shoulder_dislocate | Mobilidade de ombros com elástico (passagem) | Elástico | mobilidade | não |

### Bíceps (3)
| ID | Nome | Equipamento | Categoria | Uni |
|---|---|---|---|---|
| preacher_curl | Rosca Scott | Barra | força | não |
| concentration_curl | Rosca concentrada | Halteres | força | **sim** |
| alternating_dumbbell_curl | Rosca alternada com halteres | Halteres | força | não ¹ |

### Antebraço (1)
| ID | Nome | Equipamento | Categoria | Uni |
|---|---|---|---|---|
| reverse_curl | Rosca inversa | Barra | força | não |

Grupo Antebraço porque o músculo principal da rosca inversa é o braquiorradial.

### Tríceps (3)
| ID | Nome | Equipamento | Categoria | Uni |
|---|---|---|---|---|
| triceps_kickback | Tríceps coice com halter | Halteres | força | **sim** |
| barbell_overhead_triceps_extension | Tríceps francês com barra | Barra | força | não |
| dips | Mergulho nas paralelas | Peso corporal | força | não |

### Quadríceps (4)
| ID | Nome | Equipamento | Categoria | Uni |
|---|---|---|---|---|
| front_squat | Agachamento frontal | Barra | força | não |
| smith_squat | Agachamento no Smith | Smith | força | não |
| single_leg_extension | Cadeira extensora unilateral | Máquina | força | **sim** |
| smith_lunge | Afundo no Smith | Smith | força | **sim** |

### Posteriores de coxa (4)
| ID | Nome | Equipamento | Categoria | Uni |
|---|---|---|---|---|
| single_leg_curl | Mesa flexora unilateral | Máquina | força | **sim** |
| seated_leg_curl | Cadeira flexora | Máquina | força | não |
| dumbbell_romanian_deadlift | Stiff com halteres | Halteres | força | não |
| good_morning | Good morning (bom dia) | Barra | força | não |

### Glúteos (3)
| ID | Nome | Equipamento | Categoria | Uni |
|---|---|---|---|---|
| back_extension_45 | Extensão de quadril no banco 45° | Banco | força | não |
| single_leg_hip_thrust | Elevação pélvica unilateral | Peso corporal | força | **sim** |
| ankle_weight_kickback | Coice com caneleira (quatro apoios) | Caneleira | força | **sim** |

"Extensão de quadril" do pedido foi interpretada como a do banco 45° (lombar/glúteo),
porque o coice na polia e o coice com caneleira já cobrem a extensão em quatro apoios.

### Abdutores (2)
| ID | Nome | Equipamento | Categoria | Uni |
|---|---|---|---|---|
| cable_hip_abduction | Abdução de quadril na polia | Polia | força | **sim** |
| band_hip_abduction | Abdução de quadril com elástico | Elástico | força | não |

### Panturrilha (2)
| ID | Nome | Equipamento | Categoria | Uni |
|---|---|---|---|---|
| leg_press_calf_raise | Panturrilha no leg press | Máquina | força | não |
| single_leg_calf_raise | Panturrilha unilateral no degrau | Halteres | força | **sim** |

### Abdômen (5)
| ID | Nome | Equipamento | Categoria | Uni |
|---|---|---|---|---|
| cable_crunch | Abdominal na polia (ajoelhado) | Polia | força | não |
| ab_wheel_rollout | Roda abdominal | Peso corporal ² | força | não |
| dead_bug | Dead bug (inseto morto) | Peso corporal | força | não |
| bird_dog | Perdigueiro (bird dog) | Peso corporal | força | não |
| hollow_hold | Canoa (hollow hold) — por tempo | Peso corporal | força | não |

### Corpo todo — cardio (4)
| ID | Nome | Equipamento | Categoria | Uni |
|---|---|---|---|---|
| stationary_bike | Bicicleta ergométrica | Bicicleta | cardio | não |
| elliptical | Elíptico | Elíptico | cardio | não |
| rowing_machine | Remo ergômetro | Remo | cardio | não |
| stair_climber | Escada (simulador) | Escada | cardio | não |

Os 4 de cardio ficam "por tempo". Cardio não conta séries no mapa muscular
(regra da Etapa 2).

¹ Alternada: os dois braços trabalham na mesma série, um de cada vez. Marquei como
**não** unilateral (no app, "unilateral" é para registrar cada lado separado).
Se preferir "sim", eu troco.
² "Roda abdominal" não está na taxonomia de equipamentos aprovada. Deixei como
"Peso corporal". Alternativa: incluir "Roda abdominal" como equipamento novo.

## Bloco B — exercícios do plano do Mattheus que só existem no personal (7)

O pedido original da Etapa 3 manda incluir "todos os exercícios do plano do
Mattheus que não existirem na biblioteca geral". Sua mensagem de agora diz para
não duplicar os 11 do personal. Estes 7 seriam **versões gerais** (como as 4 da
Etapa 2): o plano do Mattheus continua usando os IDs `pt_*` do personal, nada nele
muda, e a auditoria passaria a mostrar 10 "duplicados" esperados (3 de hoje + 7).

| ID novo | Nome | Grupo | Equipamento | Categoria | Uni | Versão do personal |
|---|---|---|---|---|---|---|
| pendulum_squat | Agachamento pêndulo | Quadríceps | Máquina | força | não | pt_agachamento_pendulo |
| hip_adduction | Cadeira adutora | Adutores | Máquina | força | não | pt_cadeira_adutora |
| treadmill_run_walk | Corrida/caminhada na esteira | Corpo todo | Esteira | cardio | não | pt_corrida_caminhada |
| dumbbell_shrug | Encolhimento com halteres | Costas | Halteres | força | não | pt_encolhimento |
| smith_calf_raise | Panturrilha no Smith | Panturrilha | Smith | força | não | pt_panturrilha_smith |
| incline_dumbbell_curl | Rosca inclinada com halteres (banco 45°) | Bíceps | Halteres | força | não | pt_rosca_45 |
| single_arm_overhead_triceps_extension | Tríceps francês unilateral com halter | Tríceps | Halteres | força | **sim** | pt_triceps_frances_unilateral |

Três itens da lista base caem aqui (rosca inclinada, panturrilha no Smith, esteira),
então só entram se o Bloco B for aprovado. Encolhimento fica em Costas porque
"Trapézio" é músculo, não grupo, na taxonomia aprovada.

## Da lista base, ficaram de fora porque já existem

| Pedido | Já existe como | Motivo |
|---|---|---|
| Crossover alto | cable_crossover "Crossover na polia" | mesmo movimento (polia alta) |
| Puxada neutra | close_grip_lat_pulldown "Puxada alta com triângulo" | triângulo = pegada neutra |
| Rosca na polia | cable_curl "Rosca direta na polia" | mesmo exercício |
| Tríceps corda / tríceps barra reta | triceps_pushdown "Tríceps na polia" | a ficha já é "com corda ou barra" |
| Abdominal infra | leg_raise "Elevação de pernas" | a ficha já é "foco na parte de baixo" |
| Mobilidade de quadril | hip_90_90 "Mobilidade de quadril 90/90" | mesmo objetivo |
| Mobilidade torácica | thoracic_rotation, cat_cow | mesmo objetivo |

Na Parte B, esses nomes entram como **nome alternativo/tags** dos existentes
(ex.: "tríceps corda", "puxada neutra", "abdominal infra"), para a busca achar.

## Pontos para você decidir

1. **Bloco B**: incluir as 7 versões gerais (fica 51 no total) ou deixar de fora (44)?
2. **Rosca alternada**: unilateral não (proposto) ou sim?
3. **Roda abdominal**: "Peso corporal" (proposto) ou equipamento novo "Roda abdominal"?
4. Variações unilaterais de exercícios que já existem (extensora, flexora, elevação
   pélvica, panturrilha, coice com caneleira, rotação externa na polia) entraram como
   exercícios próprios, porque o pedido lista cada uma e o equipamento ou o lado mudam.
   Se preferir cortar alguma, me diga qual.
