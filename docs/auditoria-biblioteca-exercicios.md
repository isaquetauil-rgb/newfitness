# Auditoria da biblioteca de exercícios — Etapa 1

Data: 23/11/2026. Fonte: Firestore **real** (projeto `newfitnessappbr`), lido com
`tool/auditoria_exercicios.js` (só leitura). Nada foi alterado nesta etapa.

## 1. Quantos exercícios existem de fato

| Onde | Quantidade |
|---|---|
| Biblioteca geral (`exercises`) | **67** (0 arquivados) |
| Exercícios do personal (`users/{uid}/custom_exercises`) | **11**, todos de isaquetrabalho005@gmail.com (papel: personal) |
| **Total** | **78** |

**Por que o documento fala em 67 + 11:**

- **20** exercícios gerais já estavam no banco desde a criação do projeto.
- **47** gerais foram copiados por mim em 23/11, com sua autorização: eram os
  exercícios padrão do app que nunca tinham ido para o banco.
- **11** são exercícios do personal, criados em 23/11 para o "Treino Matheus".

## 2. Problemas encontrados

### 2.1 Duplicados
- **Nenhum duplicado exato** (mesmo nome ou nome alternativo).
- **Variações que existem só como exercício do personal** e deveriam estar
  na biblioteca geral (Etapa 3):
  - Puxada alta triângulo (variação da Puxada frontal);
  - Rosca direta na polia (variação da Rosca direta);
  - Crucifixo inverso na máquina (variação do Crucifixo inverso);
  - Elevação lateral unilateral na polia (variação da Elevação lateral).

  Esses 4 exercícios do personal ficam como estão, porque a regra é não mexer
  nos personalizados.

### 2.2 Os 20 exercícios antigos estão desatualizados em relação ao app
Os 20 primeiros foram gravados antes de o app ganhar mais campos e nunca foram
atualizados. Por isso, no banco, eles estão:
- **sem músculos secundários** (no código do app, 15 deles têm);
- **sem categoria, padrão de movimento e dificuldade**.

Consequência: o mapa muscular e a busca de substitutos ficam mais fracos
justamente nos exercícios mais usados: agachamento, supino, terra, barra
fixa, puxada, remada, leg press etc.

### 2.3 Equipamento errado ou impreciso
| Exercício | Hoje | Proposto |
|---|---|---|
| Barra fixa | Peso do corpo | Barra fixa |
| Arremesso de bola no chão | Peso do corpo | Bola medicinal |
| Pular corda | Peso do corpo | Corda (a lista proposta não tem; sugiro incluir "corda") |
| Corrida/caminhada (personal) | Esteira | Esteira (correto), mas o **grupo "Pernas" está errado**: é cardio |
| Panturrilha em pé | Máquina | Máquina ou Smith (depende da academia; manter Máquina) |

### 2.4 Grupo muscular genérico ou trocado
- **"Pernas"** cobre 19 exercícios de funções diferentes: extensora é
  quadríceps, flexora é posteriores, panturrilhas são panturrilha.
- **"Braço"** mistura bíceps e tríceps (4 exercícios).
- **"Corpo todo"** tem 11 exercícios que são, na verdade, de outros tipos:
  - cardio: pular corda, sombra, burpee;
  - mobilidade: quadril 90/90, fuga de quadril;
  - equilíbrio: equilíbrio em um pé, caminhada calcanhar e ponta.
- **Mobilidade classificada como grupo muscular:**
  - Gato e camelo e Rotação de tronco aparecem em "Costas";
  - Mobilidade de tornozelo aparece em "Pernas".
- **Panturrilhas** estão em "Pernas", embora exista o grupo "Panturrilha".
- **Grupos usados que não existem na coleção `muscle_groups`:** Bíceps,
  Tríceps, Quadríceps, Adutores e Trapézio. Fui eu que os usei nos exercícios
  do personal. O filtro do app só oferece os 9 grupos da coleção.

### 2.5 Campos vazios (de 78)
| Campo | Vazios |
|---|---|
| Músculos secundários | **69** |
| Erros comuns | **78** |
| Cuidados | **78** |
| Observações de execução | **78** |
| Tags de busca | **78** |
| Alternativas | **75** (só os 3 supinos têm) |
| Categoria | 30 |
| Padrão de movimento | 31 |
| Dificuldade | 31 |
| Instruções | 11 (todos os do personal) |
| Vídeo | 11 (todos os do personal; os 67 gerais têm vídeo) |

### 2.6 Marcações erradas
- **Unilateral: nenhum exercício está marcado.** Os que deveriam estar:
  - Remada unilateral com halter;
  - Agachamento búlgaro;
  - Afundo;
  - Afundo lateral;
  - Subida no degrau;
  - Equilíbrio em um pé;
  - Elevação lateral unilateral na polia e Tríceps francês unilateral (do
    personal).
- **Prancha abdominal não está marcada como "por tempo"**, embora a Prancha
  lateral e a Suspensão na barra estejam.
- **Categorias fora da lista do app.** O app conhece forca, cardio,
  mobilidade, alongamento e hiit. Fora dela, estão em uso:
  - "funcional" (18), "condicionamento" (5) e "potencia" (2);
  - "Cardio" com maiúscula (1, na Corrida do personal, erro meu).

  O app mostra todas essas como "Não informado".

### 2.7 Alternativas apontando para IDs inexistentes
- **Nenhuma.** As 13 referências que existem (nos 3 supinos) apontam para
  exercícios reais.

## 3. Taxonomia atual

- **Grupos (coleção `muscle_groups`):**
  - Abdômen, Braço, Corpo todo, Costas, Glúteos, Ombro, Panturrilha, Peito e
    Pernas.
  - Fora da coleção, também estão em uso: Bíceps, Tríceps, Quadríceps,
    Adutores e Trapézio.
- **Músculos secundários em uso:** Tríceps, Ombro, Antebraço, Glúteos,
  Trapézio e Bíceps. No código também existem Core, Posterior de coxa e
  Lombar.
- **Equipamentos (coleção `equipment`):**
  - Banco, Barra, Elástico, Esteira/bike, Halteres, Kettlebell, Máquina, Peso
    do corpo e Polia.
  - Fora da coleção, também estão em uso: Barra fixa, Smith e Esteira.
- **Categorias:** veja o item 2.6.

## 4. Taxonomia proposta (padronizada)

### 4.1 Grupo principal (para filtros e para o mapa)
Peito · Costas · Ombros · Bíceps · Tríceps · Antebraço · Quadríceps ·
Posteriores de coxa · Glúteos · Adutores · Abdutores · Panturrilha · Abdômen
(core) · Corpo todo (só para movimentos realmente globais).

### 4.2 Músculos (principal detalhado e secundários)
peitoral maior · latíssimo do dorso · trapézio · romboides · eretor da
espinha · deltoide anterior · deltoide lateral · deltoide posterior · bíceps
braquial · braquial · braquiorradial · tríceps braquial · quadríceps ·
posteriores de coxa · adutores · abdutores · glúteos · gastrocnêmio · sóleo ·
reto abdominal · oblíquos · transverso.

**Cada músculo precisa ter uma região no desenho do mapa muscular.** Na
Etapa 2, incluo no código do mapa os nomes que ainda não existem lá:

| Músculos | Região no mapa |
|---|---|
| peitoral maior | peito |
| latíssimo do dorso | dorsal |
| trapézio | trapézio |
| romboides | romboides |
| eretor da espinha | lombar |
| deltoides (anterior, lateral, posterior) | ombros |
| bíceps braquial, braquial | bíceps |
| braquiorradial | antebraço |
| tríceps braquial | tríceps |
| quadríceps | quadríceps |
| posteriores de coxa | posterior |
| adutores | adutores |
| abdutores, glúteos | glúteos |
| gastrocnêmio, sóleo | panturrilha |
| reto abdominal, transverso | abdômen |
| oblíquos | oblíquos |

### 4.3 Equipamentos
barra · halteres · anilha · polia · máquina · Smith · kettlebell · elástico ·
peso corporal · banco · caneleira · bola medicinal · barra fixa · esteira ·
bicicleta · elíptico · remo · escada. Sugiro incluir também **corda** (pular
corda).

Correspondência com os valores atuais:
- "Peso do corpo" passa a ser "peso corporal".
- "Esteira/bike" se divide em "esteira" e "bicicleta".

### 4.4 Categorias
Já existem no app: força, cardio, mobilidade, alongamento e HIIT.

- **Mobilidade e Cardio já existem no código.** O problema é que os dados
  usam outros nomes.
- **Proposta para os dados:** "funcional" e "potencia" passam a ser
  "força"; "condicionamento" passa a ser "cardio" ou "HIIT", conforme o
  exercício.
- **Exercícios de mobilidade:** passam a ter grupo "Corpo todo" ou a região
  trabalhada, e categoria **mobilidade**.

## 5. O que depende de decisão sua antes da Etapa 2
1. Aprovar os grupos (4.1), os músculos (4.2) e os equipamentos (4.3),
   inclusive "corda".
2. Os valores gravados mudam de nome (por exemplo, "Peso do corpo" vira
   "peso corporal"). Os IDs dos exercícios não mudam. Treinos salvos guardam
   uma cópia do nome e do grupo e não são alterados.
3. Os 11 exercícios do personal ficam intocados. Na Etapa 3, as versões
   gerais entram na biblioteca com IDs novos.
