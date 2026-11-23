# Etapa 4 — pares exercício do personal × versão geral

Nada foi gravado ainda. Depois da aprovação, o script
`tool/biblioteca/gravar_etapa4_pares.js` grava **só** o campo opcional
`baseExerciseId` em cada exercício do personal (dono: a conta personal do
usuário), com backup antes. Nome, grupo, vídeo e o resto do exercício do personal
não mudam. Nenhum treino nem plano é alterado.

Efeito: na biblioteca e no seletor **do personal dono**, a versão geral some
(ele usa a dele). Alunos vinculados continuam vendo as duas. O plano do Mattheus
continua usando os exercícios do personal (IDs `pt_*`) e o tríceps com barra.

São **11 pares**, não 8: os 8 com o mesmo nome que a auditoria apontou como
duplicados, mais os 3 com nome diferente. Juntos, cobrem todos os 11 exercícios
do personal.

| # | Exercício do personal | → Versão geral | Nome igual? |
|---|---|---|---|
| 1 | Agachamento pêndulo (`pt_agachamento_pendulo`) | Agachamento pêndulo (`pendulum_squat`) | sim |
| 2 | Cadeira adutora (`pt_cadeira_adutora`) | Cadeira adutora (`hip_adduction`) | sim |
| 3 | Crucifixo inverso na máquina (`pt_crucifixo_inverso_maquina`) | Crucifixo inverso na máquina (`machine_rear_delt_fly`) | sim |
| 4 | Elevação lateral unilateral na polia (`pt_elevacao_lateral_polia`) | Elevação lateral unilateral na polia (`cable_lateral_raise`) | sim |
| 5 | Encolhimento com halteres (`pt_encolhimento`) | Encolhimento com halteres (`dumbbell_shrug`) | sim |
| 6 | Panturrilha no Smith (`pt_panturrilha_smith`) | Panturrilha no Smith (`smith_calf_raise`) | sim |
| 7 | Rosca 45° (banco inclinado) (`pt_rosca_45`) | Rosca inclinada com halteres (banco 45°) (`incline_dumbbell_curl`) | sim ¹ |
| 8 | Rosca direta na polia (`pt_rosca_direta_polia`) | Rosca direta na polia (`cable_curl`) | sim |
| 9 | Puxada alta triângulo (`pt_puxada_triangulo`) | Puxada alta com triângulo (`close_grip_lat_pulldown`) | não |
| 10 | Tríceps francês unilateral (`pt_triceps_frances_unilateral`) | Tríceps francês unilateral com halter (`single_arm_overhead_triceps_extension`) | não |
| 11 | Corrida/caminhada (`pt_corrida_caminhada`) | Corrida/caminhada na esteira (`treadmill_run_walk`) | não |

¹ A auditoria compara também o nome alternativo ("Rosca 45°"), por isso contou
este par entre os 8.
