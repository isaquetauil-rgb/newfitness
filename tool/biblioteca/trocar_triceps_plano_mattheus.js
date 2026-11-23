// Plano "Treino Matheus": o tríceps de quarta-feira, que é feito com barra,
// passa a apontar para o exercício geral triceps_bar_pushdown (Etapa 3).
// Só muda exerciseId e exerciseName desse item; prescrição, observação e o
// resto do plano ficam iguais.
//
// Uso:
//   node tool/biblioteca/trocar_triceps_plano_mattheus.js <chave.json> --conferir
//   node tool/biblioteca/trocar_triceps_plano_mattheus.js <chave.json> --backup-dir <pasta> --gravar
//
// Idempotente: se o item já aponta para triceps_bar_pushdown, não grava nada.
'use strict';

const path = require('path');
const fs = require('fs');

const args = process.argv.slice(2);
const keyPath = args[0];
const gravar = args.includes('--gravar');
const backupDir = args.includes('--backup-dir') ? args[args.indexOf('--backup-dir') + 1] : null;
if (!keyPath || (!gravar && !args.includes('--conferir')) || (gravar && !backupDir)) {
  console.error('Uso: <chave.json> --conferir | --backup-dir <pasta> --gravar');
  process.exit(1);
}

const PLAN = 'users/ERP0apcdvyYJ3FqR5H6lQ1tUKMZ2/training_plans/2VqDpxM47sGrJ0yq80yX';
const DAY_LABEL = 'Quarta – Peitoral e tríceps';
const FROM = 'triceps_pushdown';
const TO = { exerciseId: 'triceps_bar_pushdown', exerciseName: 'Tríceps na polia com barra' };

const admin = require(path.join(__dirname, '..', '..', 'functions', 'node_modules', 'firebase-admin'));
admin.initializeApp({ credential: admin.credential.cert(require(path.resolve(keyPath))) });
const db = admin.firestore();

(async () => {
  const ref = db.doc(PLAN);
  const plan = (await ref.get()).data();
  const day = plan.workouts.findIndex((w) => w.label === DAY_LABEL);
  if (day < 0) throw new Error(`Dia "${DAY_LABEL}" não encontrado. Nada gravado.`);
  const exs = plan.workouts[day].exercises;
  const done = exs.findIndex((e) => e.exerciseId === TO.exerciseId);
  if (done >= 0) {
    console.log(`Já aponta para ${TO.exerciseId} (item ${done + 1} de "${DAY_LABEL}"). Nada a gravar.`);
    process.exit(0);
  }
  const hits = exs
    .map((e, i) => [e, i])
    .filter(([e]) => e.exerciseId === FROM && /barra/i.test(e.notes || ''));
  if (hits.length !== 1) throw new Error(`Esperava 1 tríceps com barra em "${DAY_LABEL}", achei ${hits.length}. Nada gravado.`);
  const [before, idx] = hits[0];
  if (!(await db.doc(`exercises/${TO.exerciseId}`).get()).exists) {
    throw new Error(`${TO.exerciseId} ainda não existe na biblioteca (grave a Etapa 3 antes). Nada gravado.`);
  }
  const after = { ...before, ...TO };
  const workouts = plan.workouts.map((w, d) => (d !== day ? w : {
    ...w,
    exercises: w.exercises.map((e, i) => (i === idx ? after : e)),
  }));
  console.log(`Item ${idx + 1} de "${DAY_LABEL}":`);
  console.log('  antes:', JSON.stringify(before));
  console.log('  depois:', JSON.stringify(after));
  if (!gravar) { console.log('[conferir] Nada foi gravado.'); process.exit(0); }
  fs.mkdirSync(backupDir, { recursive: true });
  const file = path.join(backupDir, `plano-mattheus-backup-${new Date().toISOString().replace(/[:.]/g, '-')}.json`);
  fs.writeFileSync(file, JSON.stringify({ path: PLAN, workouts: plan.workouts }, null, 2));
  console.log(`Backup do plano: ${file}`);
  await ref.update({ workouts });
  console.log('Gravado.');
  process.exit(0);
})().catch((e) => { console.error(e.message); process.exit(1); });
