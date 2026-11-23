// Etapa 2 da biblioteca: grava no Firestore real as correções aprovadas.
//
// Uso:
//   node tool/biblioteca/gravar_etapa2.js <chave.json> --conferir
//   node tool/biblioteca/gravar_etapa2.js <chave.json> --backup <arquivo-de-backup.json> --gravar
//
// --conferir só lê e mostra o que mudaria. --gravar exige um backup feito
// antes (backup_exercicios.js) e o próprio arquivo de backup.
//
// O que grava (idempotente — rodar de novo não muda mais nada):
//   * exercises: SÓ os campos grupo, músculos secundários, equipamento,
//     categoria, padrão de movimento, dificuldade, unilateral e "por tempo"
//     dos exercícios gerais corrigidos (set com merge; nome, vídeo e
//     instruções ficam como estão). IDs não mudam.
//   * exercises: cria as 4 versões gerais novas, se ainda não existirem.
//   * muscle_groups e equipment: nomes padronizados (mesmos IDs; cria os que
//     faltam) e remove só "pernas" e "braco" da coleção de grupos.
// Nunca toca em exercícios do personal (users/*/custom_exercises) nem em
// treinos ou planos.
'use strict';

const path = require('path');
const fs = require('fs');

const args = process.argv.slice(2);
const keyPath = args[0];
const gravar = args.includes('--gravar');
const backupPath = args.includes('--backup') ? args[args.indexOf('--backup') + 1] : null;
if (!keyPath || (!gravar && !args.includes('--conferir'))) {
  console.error('Uso: node tool/biblioteca/gravar_etapa2.js <chave.json> --conferir | --backup <arquivo> --gravar');
  process.exit(1);
}
if (gravar && (!backupPath || !fs.existsSync(backupPath))) {
  console.error('Para gravar, passe --backup com o arquivo gerado por backup_exercicios.js.');
  process.exit(1);
}

const admin = require(path.join(__dirname, '..', '..', 'functions', 'node_modules', 'firebase-admin'));
admin.initializeApp({ credential: admin.credential.cert(require(path.resolve(keyPath))) });
const db = admin.firestore();
const data = require('./etapa2_correcoes.json');

const GROUPS = {
  peito: 'Peito', costas: 'Costas', ombro: 'Ombros', biceps: 'Bíceps', triceps: 'Tríceps',
  antebraco: 'Antebraço', quadriceps: 'Quadríceps', posteriores_de_coxa: 'Posteriores de coxa',
  gluteos: 'Glúteos', adutores: 'Adutores', abdutores: 'Abdutores', panturrilha: 'Panturrilha',
  abdomen: 'Abdômen', corpo_todo: 'Corpo todo',
};
const GROUPS_TO_REMOVE = ['pernas', 'braco'];
const EQUIPMENT = {
  barra: 'Barra', halteres: 'Halteres', anilha: 'Anilha', polia: 'Polia', maquina: 'Máquina',
  smith: 'Smith', kettlebell: 'Kettlebell', elastico: 'Elástico', peso_do_corpo: 'Peso corporal',
  banco: 'Banco', caneleira: 'Caneleira', bola_medicinal: 'Bola medicinal', barra_fixa: 'Barra fixa',
  esteira_bike: 'Esteira', bicicleta: 'Bicicleta', eliptico: 'Elíptico', remo: 'Remo',
  escada: 'Escada', corda: 'Corda',
};

const same = (a, b) => JSON.stringify(a ?? null) === JSON.stringify(b ?? null);

(async () => {
  const log = (m) => console.log(gravar ? m : `[conferir] ${m}`);
  let batch = db.batch();
  let ops = 0;
  const flush = async () => {
    if (gravar && ops) await batch.commit();
    batch = db.batch();
    ops = 0;
  };
  const write = async (fn) => {
    if (gravar) fn(batch);
    if (++ops >= 400) await flush();
  };

  // 1. Correções dos exercícios gerais.
  let changed = 0;
  let unchanged = 0;
  for (const [id, fix] of Object.entries(data.correcoes)) {
    const snap = await db.doc(`exercises/${id}`).get();
    if (!snap.exists) throw new Error(`Exercício ${id} não existe no Firestore. Nada gravado.`);
    const cur = snap.data();
    const diff = Object.fromEntries(Object.entries(fix).filter(([k, v]) => !same(cur[k], v)));
    if (!Object.keys(diff).length) { unchanged++; continue; }
    changed++;
    await write((b) => b.set(snap.ref, diff, { merge: true }));
  }
  log(`Exercícios gerais corrigidos: ${changed} (já corretos: ${unchanged}).`);

  // 2. Versões gerais novas.
  let created = 0;
  for (const [id, doc] of Object.entries(data.novos)) {
    const ref = db.doc(`exercises/${id}`);
    if ((await ref.get()).exists) continue;
    created++;
    await write((b) => b.set(ref, doc));
    log(`Novo exercício geral: ${doc.name} (${id})`);
  }

  // 3. Taxonomia.
  for (const [col, wanted] of [['muscle_groups', GROUPS], ['equipment', EQUIPMENT]]) {
    for (const [id, name] of Object.entries(wanted)) {
      const ref = db.doc(`${col}/${id}`);
      const snap = await ref.get();
      if (snap.exists && snap.get('name') === name) continue;
      await write((b) => b.set(ref, { name }, { merge: true }));
      log(`${col}/${id}: ${snap.exists ? `"${snap.get('name')}" → ` : 'novo: '}"${name}"`);
    }
  }
  for (const id of GROUPS_TO_REMOVE) {
    const ref = db.doc(`muscle_groups/${id}`);
    const snap = await ref.get();
    if (!snap.exists) continue;
    await write((b) => b.delete(ref));
    log(`muscle_groups/${id} ("${snap.get('name')}") removido da lista (continua entendido na leitura).`);
  }
  await flush();
  log(gravar ? 'Gravado.' : 'Nada foi gravado.');
  process.exit(0);
})().catch((e) => { console.error(e.message); process.exit(1); });
