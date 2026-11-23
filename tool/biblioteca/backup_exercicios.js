// Backup (export JSON) da biblioteca no Firestore real: exercises,
// muscle_groups e equipment. SÓ LEITURA.
//
// Uso: node tool/biblioteca/backup_exercicios.js <chave.json> <pasta-de-saida>
// Gera <pasta>/biblioteca-backup-<data>.json (fora do repositório).
'use strict';

const path = require('path');
const fs = require('fs');

const [keyPath, outDir] = process.argv.slice(2);
if (!keyPath || !outDir) {
  console.error('Uso: node tool/biblioteca/backup_exercicios.js <chave.json> <pasta-de-saida>');
  process.exit(1);
}
const admin = require(path.join(__dirname, '..', '..', 'functions', 'node_modules', 'firebase-admin'));
admin.initializeApp({ credential: admin.credential.cert(require(path.resolve(keyPath))) });
const db = admin.firestore();

const toPlain = (v) => {
  if (v instanceof admin.firestore.Timestamp) return { __timestamp: v.toMillis() };
  if (Array.isArray(v)) return v.map(toPlain);
  if (v && typeof v === 'object') return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, toPlain(x)]));
  return v;
};

(async () => {
  const backup = { projeto: 'newfitnessappbr', geradoEm: new Date().toISOString() };
  for (const col of ['exercises', 'muscle_groups', 'equipment']) {
    const snap = await db.collection(col).get();
    backup[col] = Object.fromEntries(snap.docs.map((d) => [d.id, toPlain(d.data())]));
  }
  fs.mkdirSync(outDir, { recursive: true });
  const stamp = backup.geradoEm.replace(/[:.]/g, '-');
  const file = path.join(outDir, `biblioteca-backup-${stamp}.json`);
  fs.writeFileSync(file, JSON.stringify(backup, null, 2));
  console.log(`Backup: ${file}`);
  console.log(`exercises ${Object.keys(backup.exercises).length} · muscle_groups ${Object.keys(backup.muscle_groups).length} · equipment ${Object.keys(backup.equipment).length}`);
  process.exit(0);
})().catch((e) => { console.error(e.message); process.exit(1); });
