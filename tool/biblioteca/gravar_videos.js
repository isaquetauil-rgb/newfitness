// Grava no Firestore real o vídeo (videoUrl) dos exercícios gerais que estão
// sem vídeo, a partir de tool/biblioteca/videos_novos.json (vídeos achados
// na busca do YouTube, conferidos pelo oEmbed e aprovados pelo usuário).
//
// Uso:
//   node tool/biblioteca/gravar_videos.js <chave.json> --conferir
//   node tool/biblioteca/gravar_videos.js <chave.json> --backup <arquivo> --gravar
//
// Só preenche videoUrl VAZIO (nunca troca um vídeo que já existe). Nada mais
// no exercício muda. Idempotente.
'use strict';

const path = require('path');
const fs = require('fs');

const args = process.argv.slice(2);
const keyPath = args[0];
const gravar = args.includes('--gravar');
const backupPath = args.includes('--backup') ? args[args.indexOf('--backup') + 1] : null;
if (!keyPath || (!gravar && !args.includes('--conferir'))) {
  console.error('Uso: <chave.json> --conferir | --backup <arquivo> --gravar');
  process.exit(1);
}
if (gravar && (!backupPath || !fs.existsSync(backupPath))) {
  console.error('Para gravar, passe --backup com o arquivo gerado por backup_exercicios.js.');
  process.exit(1);
}

const admin = require(path.join(__dirname, '..', '..', 'functions', 'node_modules', 'firebase-admin'));
admin.initializeApp({ credential: admin.credential.cert(require(path.resolve(keyPath))) });
const db = admin.firestore();
const videos = require('./videos_novos.json');

(async () => {
  const batch = db.batch();
  let todo = 0;
  let done = 0;
  const conflicts = [];
  for (const [id, { videoUrl }] of Object.entries(videos)) {
    const snap = await db.doc(`exercises/${id}`).get();
    if (!snap.exists) throw new Error(`exercises/${id} não existe. Nada gravado.`);
    const cur = snap.get('videoUrl') || '';
    if (cur === videoUrl) { done++; continue; }
    if (cur) { conflicts.push(`${id}: já tem ${cur}`); continue; }
    todo++;
    batch.update(snap.ref, { videoUrl });
  }
  console.log(`Vídeos a gravar: ${todo} · já gravados: ${done} · com outro vídeo (não mexo): ${conflicts.length}`);
  conflicts.forEach((c) => console.log('  ' + c));
  if (!gravar) { console.log('[conferir] Nada foi gravado.'); process.exit(0); }
  if (todo) await batch.commit();
  console.log(todo ? 'Gravado.' : 'Nada a gravar.');
  process.exit(0);
})().catch((e) => { console.error(e.message); process.exit(1); });
