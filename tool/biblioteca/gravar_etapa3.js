// Etapa 3 da biblioteca: grava no Firestore real as fichas aprovadas.
//
// Uso:
//   node tool/biblioteca/gravar_etapa3.js <chave.json> --conferir
//   node tool/biblioteca/gravar_etapa3.js <chave.json> --backup <arquivo-de-backup.json> --gravar
//
// --conferir só lê e mostra o que mudaria. --gravar exige o arquivo de backup
// feito antes (backup_exercicios.js).
//
// O que grava (idempotente — rodar de novo não muda mais nada):
//   * exercises existentes: preenche SÓ os campos vazios de erros comuns,
//     cuidados, tags e alternativas; renomeia triceps_pushdown para "com
//     corda"; marca professionalReviewPending. Corrige o campo da Etapa 2
//     gravado com o nome errado (revisaoProfissionalPendente).
//   * exercises novos: cria os que ainda não existem (vídeo e imagem vazios).
//   * equipment: cria "Roda abdominal" se faltar.
// Nunca toca em exercícios do personal (users/*/custom_exercises), treinos
// ou planos. IDs existentes não mudam.
'use strict';

const path = require('path');
const fs = require('fs');

const args = process.argv.slice(2);
const keyPath = args[0];
const gravar = args.includes('--gravar');
const backupPath = args.includes('--backup') ? args[args.indexOf('--backup') + 1] : null;
if (!keyPath || (!gravar && !args.includes('--conferir'))) {
  console.error('Uso: node tool/biblioteca/gravar_etapa3.js <chave.json> --conferir | --backup <arquivo> --gravar');
  process.exit(1);
}
if (gravar && (!backupPath || !fs.existsSync(backupPath))) {
  console.error('Para gravar, passe --backup com o arquivo gerado por backup_exercicios.js.');
  process.exit(1);
}

const admin = require(path.join(__dirname, '..', '..', 'functions', 'node_modules', 'firebase-admin'));
admin.initializeApp({ credential: admin.credential.cert(require(path.resolve(keyPath))) });
const db = admin.firestore();
const data = require('./etapa3_fichas.json');

const isEmpty = (v) => v == null || v === '' || (Array.isArray(v) && v.length === 0);
const OLD_FLAG = 'revisaoProfissionalPendente';

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

  // Confere antes de qualquer escrita: todo existente precisa existir e
  // nenhum novo pode apontar alternativa para exercício inexistente.
  const allIds = new Set((await db.collection('exercises').get()).docs.map((d) => d.id));
  for (const id of Object.keys(data.existentes)) {
    if (!allIds.has(id)) throw new Error(`Exercício ${id} não existe no Firestore. Nada gravado.`);
  }
  const finalIds = new Set([...allIds, ...Object.keys(data.novos)]);
  for (const [id, d] of [...Object.entries(data.existentes), ...Object.entries(data.novos)]) {
    for (const alt of d.alternativeExerciseIds || []) {
      if (!finalIds.has(alt)) throw new Error(`${id}: alternativa ${alt} não existe. Nada gravado.`);
    }
  }

  // 1. Existentes.
  let changed = 0;
  let unchanged = 0;
  const fieldCount = {};
  for (const [id, fill] of Object.entries(data.existentes)) {
    const snap = await db.doc(`exercises/${id}`).get();
    const cur = snap.data();
    const diff = {};
    for (const [k, v] of Object.entries(fill)) {
      if (isEmpty(v) || !isEmpty(cur[k])) continue;
      diff[k] = v;
      fieldCount[k] = (fieldCount[k] || 0) + 1;
    }
    for (const [k, v] of Object.entries(data.renomear[id] || {})) {
      if (cur[k] !== v) diff[k] = v;
    }
    if (cur.professionalReviewPending !== true) diff.professionalReviewPending = true;
    if (OLD_FLAG in cur) diff[OLD_FLAG] = admin.firestore.FieldValue.delete();
    if (!Object.keys(diff).length) { unchanged++; continue; }
    changed++;
    if (data.renomear[id] && diff.name) log(`Renomeado: ${id} "${cur.name}" → "${diff.name}"`);
    if (diff[OLD_FLAG]) log(`Campo da Etapa 2 corrigido em ${id} (${OLD_FLAG} → professionalReviewPending).`);
    await write((b) => b.set(snap.ref, diff, { merge: true }));
  }
  log(`Exercícios existentes atualizados: ${changed} (já completos: ${unchanged}).`);
  log(`Campos preenchidos: ${Object.entries(fieldCount).map(([k, n]) => `${k} ${n}`).join(' · ') || 'nenhum'}`);

  // 2. Novos.
  let created = 0;
  for (const [id, doc] of Object.entries(data.novos)) {
    if (allIds.has(id)) continue;
    created++;
    await write((b) => b.set(db.doc(`exercises/${id}`), doc));
  }
  log(`Exercícios novos criados: ${created} (já existiam: ${Object.keys(data.novos).length - created}).`);

  // 3. Equipamentos.
  for (const [id, name] of Object.entries(data.equipamentosNovos)) {
    const ref = db.doc(`equipment/${id}`);
    const snap = await ref.get();
    if (snap.exists && snap.get('name') === name) continue;
    await write((b) => b.set(ref, { name }, { merge: true }));
    log(`equipment/${id}: "${name}"`);
  }

  await flush();
  log(gravar ? 'Gravado.' : 'Nada foi gravado.');
  process.exit(0);
})().catch((e) => { console.error(e.message); process.exit(1); });
