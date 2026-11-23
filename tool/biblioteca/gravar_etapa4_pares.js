// Etapa 4 da biblioteca: liga cada exercício do personal à versão geral
// equivalente (campo opcional baseExerciseId). Na biblioteca e no seletor do
// próprio personal, a versão geral passa a ficar escondida.
//
// Uso:
//   node tool/biblioteca/gravar_etapa4_pares.js <chave.json> --conferir
//   node tool/biblioteca/gravar_etapa4_pares.js <chave.json> --backup-dir <pasta> --gravar
//
// Só grava o campo baseExerciseId (set com merge) nos exercícios do
// personal listados abaixo; nada mais neles muda. Idempotente. Faz backup
// dos exercícios do personal antes de gravar.
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

const OWNER = 'xRer1H54jPP5qUFatFzzeHiV0Va2';
const PARES = {
  pt_agachamento_pendulo: 'pendulum_squat',
  pt_cadeira_adutora: 'hip_adduction',
  pt_corrida_caminhada: 'treadmill_run_walk',
  pt_crucifixo_inverso_maquina: 'machine_rear_delt_fly',
  pt_elevacao_lateral_polia: 'cable_lateral_raise',
  pt_encolhimento: 'dumbbell_shrug',
  pt_panturrilha_smith: 'smith_calf_raise',
  pt_puxada_triangulo: 'close_grip_lat_pulldown',
  pt_rosca_45: 'incline_dumbbell_curl',
  pt_rosca_direta_polia: 'cable_curl',
  pt_triceps_frances_unilateral: 'single_arm_overhead_triceps_extension',
};

const admin = require(path.join(__dirname, '..', '..', 'functions', 'node_modules', 'firebase-admin'));
admin.initializeApp({ credential: admin.credential.cert(require(path.resolve(keyPath))) });
const db = admin.firestore();

(async () => {
  const col = db.collection(`users/${OWNER}/custom_exercises`);
  const custom = Object.fromEntries((await col.get()).docs.map((d) => [d.id, d.data()]));
  const rows = [];
  for (const [ptId, baseId] of Object.entries(PARES)) {
    if (!custom[ptId]) throw new Error(`${ptId} não existe na biblioteca do personal. Nada gravado.`);
    const base = await db.doc(`exercises/${baseId}`).get();
    if (!base.exists) throw new Error(`${baseId} não existe na biblioteca geral. Nada gravado.`);
    rows.push({ ptId, ptName: custom[ptId].name, baseId, baseName: base.get('name'), atual: custom[ptId].baseExerciseId || '' });
  }
  for (const r of rows) {
    const status = r.atual === r.baseId ? 'já ligado' : r.atual ? `troca (${r.atual})` : 'novo';
    console.log(`${r.ptName} (${r.ptId}) → ${r.baseName} (${r.baseId}) · ${status}`);
  }
  const todo = rows.filter((r) => r.atual !== r.baseId);
  console.log(`Pares: ${rows.length} · a gravar: ${todo.length}`);
  if (!gravar) { console.log('[conferir] Nada foi gravado.'); process.exit(0); }
  if (!todo.length) { console.log('Nada a gravar.'); process.exit(0); }

  fs.mkdirSync(backupDir, { recursive: true });
  const file = path.join(backupDir, `custom-exercises-backup-${new Date().toISOString().replace(/[:.]/g, '-')}.json`);
  fs.writeFileSync(file, JSON.stringify({ path: col.path, docs: custom }, null, 2));
  console.log(`Backup: ${file}`);
  const batch = db.batch();
  for (const r of todo) batch.set(col.doc(r.ptId), { baseExerciseId: r.baseId }, { merge: true });
  await batch.commit();
  console.log('Gravado.');
  process.exit(0);
})().catch((e) => { console.error(e.message); process.exit(1); });
