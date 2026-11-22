// Prompt 3 etapa 4 — "Exportar meus dados" (`functions/src/export.ts`).
// Testes COMPORTAMENTAIS da Function `exportMyData` e das regras novas
// (`data_exports` no Firestore e `exports/` no Storage), contra os
// emuladores. O link assinado é trocado por um falso (o emulador não assina).
// Dados fictícios.
//
// Pré-requisito: `npm run build` em functions/.
'use strict';

const { test, before, after, beforeEach, describe } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const PROJECT_ID = 'demo-newfitness-rules-test';
const BUCKET = `${PROJECT_ID}.appspot.com`;
process.env.GCLOUD_PROJECT = PROJECT_ID;
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.FIREBASE_STORAGE_EMULATOR_HOST = '127.0.0.1:9199';

const admin = require('../functions/node_modules/firebase-admin');
admin.initializeApp({ projectId: PROJECT_ID, storageBucket: BUCKET });
const adminDb = admin.firestore();
const bucket = admin.storage().bucket();

const {
  exportMyData,
  setExportUrlSigner,
  workoutsCsv,
  CSV_HEADER,
  EXPORT_LINK_MS,
  effectiveDurationSeconds,
  LEGACY_MAX_DURATION_SECONDS,
  setExportPhotosLimit,
  photoStoragePath,
} = require('../functions/lib/export.js');
const JSZip = require('../functions/node_modules/jszip');
const { periodKey } = require('../functions/lib/ai_guard.js');

const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, deleteDoc } = require('firebase/firestore');
const { ref, uploadBytes, getBytes, deleteObject } = require('firebase/storage');

const ROOT = path.join(__dirname, '..');
let testEnv;
let signed;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(path.join(ROOT, 'firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
    storage: {
      rules: fs.readFileSync(path.join(ROOT, 'storage.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 9199,
    },
  });
  setExportUrlSigner(async (file, expiresAt) => {
    signed.push({ name: file.name, expiresAt });
    return `https://assinado.test/${file.name}?expira=${expiresAt}`;
  });
});

after(async () => {
  setExportUrlSigner();
  await testEnv.cleanup();
});

const W1 = {
  userId: 'aluno',
  date: Date.UTC(2026, 10, 2, 21, 30), // 18:30 em São Paulo
  name: 'Treino A; peito',
  durationSeconds: 3600,
  exercises: [
    {
      exerciseId: 'supino',
      exerciseName: 'Supino "reto"',
      sets: [
        { reps: 12, weightKg: 20, completed: true, type: 'warmup' },
        { reps: 8, weightKg: 62.5, completed: true },
      ],
    },
    {
      exerciseId: 'prancha',
      exerciseName: 'Prancha',
      sets: [{ reps: 0, weightKg: 0, completed: true, seconds: 45 }],
    },
  ],
};
const W0 = {
  userId: 'aluno',
  date: Date.UTC(2026, 9, 30, 12),
  name: 'Treino antigo',
  exercises: [{ exerciseId: 'agacha', exerciseName: 'Agachamento', sets: [{ reps: 5, weightKg: 100, completed: false }] }],
};

beforeEach(async () => {
  signed = [];
  await testEnv.clearFirestore();
  await testEnv.clearStorage();
  await adminDb.doc('users/aluno').set({
    name: 'Ana',
    role: 'student',
    instructorId: 'prof',
    parq: { answers: [false, false, false, false, false, false, false], answeredAt: 1, version: 1 },
    freeWorkoutTermsAcceptedAt: 2,
    weeklyGoal: 4,
  });
  await adminDb.doc('users/prof').set({ name: 'Paulo', role: 'instructor' });
  await adminDb.doc('users/outro').set({ name: 'Outro', role: 'student' });
  await adminDb.doc('users/aluno/workouts/w1').set(W1);
  await adminDb.doc('users/aluno/workouts/w0').set(W0);
  await adminDb.doc('users/aluno/progress_records/supino').set({ exerciseName: 'Supino', bestLoadKg: 62.5 });
  await adminDb.doc('users/aluno/physical_assessments/a1').set({
    weightKg: 70,
    createdAt: admin.firestore.Timestamp.fromMillis(Date.UTC(2026, 0, 1)),
  });
  await adminDb.doc('users/aluno/health_screenings/h1').set({ answers: [false] });
  // Foto de refeição: o caminho vem do link de download do Storage.
  await adminDb.doc('users/aluno/meal_photos/m1').set({
    mealType: 'lunch',
    imageUrl: `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/users%2Faluno%2Fmeal_photos%2Fm1.jpg?alt=media&token=t`,
  });
  await bucket.file('users/aluno/meal_photos/m1.jpg').save(Buffer.from('FOTO-REFEICAO'), { contentType: 'image/jpeg' });
  await bucket.file('users/aluno/body_photos/b1.jpg').save(Buffer.from('FOTO-CORPO'), { contentType: 'image/jpeg' });
  // Foto de OUTRO usuário citada no documento: não pode entrar no ZIP.
  await bucket.file('users/outro/body_photos/x.jpg').save(Buffer.from('FOTO-DO-OUTRO'), { contentType: 'image/jpeg' });
  await adminDb.doc('users/aluno/body_photos/b2').set({ storagePath: 'users/outro/body_photos/x.jpg' });
  await adminDb.doc('users/aluno/training_plans/p1').set({ title: 'Plano A' });
  await adminDb.doc('users/aluno/nutrition_plans/n1').set({ title: 'Dieta' });
  await adminDb.doc('users/aluno/body_photos/b1').set({ storagePath: 'users/aluno/body_photos/b1.jpg', position: 'front' });
  // Dados de OUTRO usuário: não podem vazar.
  await adminDb.doc('users/outro/workouts/x').set({ ...W1, userId: 'outro', name: 'SEGREDO' });
  await adminDb.doc('users/aluno/chat_messages/c1').set({ text: 'não exporta' });
});

const call = (uid) => exportMyData.run({ data: {}, auth: uid ? { uid, token: { email: `${uid}@x.test` } } : undefined });

async function rejectsWith(promise, code, messagePart) {
  await assert.rejects(promise, (err) => {
    assert.equal(err.code, code, `esperado "${code}", veio "${err.code}" (${err.message})`);
    if (messagePart) assert.match(err.message, messagePart);
    return true;
  });
}

async function openZip(uid) {
  const [files] = await bucket.getFiles({ prefix: `users/${uid}/exports/` });
  const file = files.find((f) => f.name.endsWith('.zip'));
  assert.ok(file, 'ZIP não encontrado');
  const [buf] = await file.download();
  return JSZip.loadAsync(buf);
}

async function readExport(uid, name) {
  const zip = await openZip(uid);
  const entry = zip.file(name);
  assert.ok(entry, `arquivo ${name} não está no ZIP`);
  return entry.async('string');
}

describe('exportMyData', () => {
  test('sem login: recusado', async () => {
    await rejectsWith(call(null), 'unauthenticated');
  });

  test('exporta só os dados do próprio usuário num ZIP, link de 1 hora', async () => {
    const before = Date.now();
    const res = await call('aluno');
    assert.equal(res.workouts, 2);
    assert.match(res.zipUrl, /^https:\/\/assinado\.test\/users\/aluno\/exports\/.+\/meus-dados-newfitness\.zip/);
    assert.equal(res.photos, 2);
    assert.equal(res.photosOmitted, 0);
    assert.ok(res.sizeBytes > 0);
    // Só UM link assinado (o do ZIP): as fotos vão dentro dele.
    assert.equal(signed.length, 1);
    assert.ok(res.expiresAt - before >= EXPORT_LINK_MS - 5_000);
    assert.ok(res.expiresAt - before <= EXPORT_LINK_MS + 60_000);

    const json = JSON.parse(await readExport('aluno', 'dados.json'));
    assert.equal(json.usuario, 'aluno');
    assert.equal(json.perfil.name, 'Ana');
    assert.equal(json.perfil.weeklyGoal, 4);
    assert.ok(json.perfil.parq, 'PAR-Q no perfil');
    assert.equal(json.perfil.freeWorkoutTermsAcceptedAt, 2);
    assert.deepEqual(json.treinos.map((w) => w.id).sort(), ['w0', 'w1']);
    assert.equal(json.recordes[0].bestLoadKg, 62.5);
    assert.equal(json.avaliacoesFisicas[0].createdAt, '2026-01-01T00:00:00.000Z');
    assert.equal(json.triagensDeSaude.length, 1);
    assert.equal(json.refeicoes[0].arquivo, 'fotos/refeicoes/m1.jpg');
    assert.equal(json.planosDeTreino[0].title, 'Plano A');
    assert.equal(json.planosDeNutricao[0].title, 'Dieta');
    const b1 = json.fotosCorporais.find((f) => f.id === 'b1');
    assert.equal(b1.arquivo, 'fotos/corporais/b1.jpg');
    assert.equal(b1.link, undefined, 'sem link que expira');
    const b2 = json.fotosCorporais.find((f) => f.id === 'b2');
    assert.equal(b2.arquivo, undefined, 'foto de outro usuário não entra');
    const zip = await openZip('aluno');
    assert.equal(await zip.file('fotos/corporais/b1.jpg').async('string'), 'FOTO-CORPO');
    assert.equal(await zip.file('fotos/refeicoes/m1.jpg').async('string'), 'FOTO-REFEICAO');
    for (const name of Object.keys(zip.files)) {
      const content = zip.files[name].dir ? '' : await zip.files[name].async('string');
      assert.ok(!content.includes('FOTO-DO-OUTRO'), `vazou foto de outro usuário em ${name}`);
    }
    const text = JSON.stringify(json);
    assert.ok(!text.includes('SEGREDO'), 'vazou treino de outro usuário');
    assert.ok(!text.includes('não exporta'), 'conversa não faz parte da exportação');
  });

  test('CSV: uma linha por série, ponto e vírgula, vírgula decimal', async () => {
    await call('aluno');
    const csv = await readExport('aluno', 'treinos.csv');
    assert.equal(csv.charCodeAt(0), 0xfeff, 'BOM para o Excel');
    const lines = csv.slice(1).trim().split('\r\n');
    assert.equal(lines[0], CSV_HEADER.join(';'));
    assert.equal(lines.length, 1 + 1 + 3); // cabeçalho + w0 (1 série) + w1 (3 séries)
    // Mais antigo primeiro.
    assert.match(lines[1], /^2026-10-30 09:00;Treino antigo;;Agachamento;1;Normal;5;100;;não;w0;agacha$/);
    assert.equal(
      lines[2],
      '2026-11-02 18:30;"Treino A; peito";60;"Supino ""reto""";1;Aquecimento;12;20;;sim;w1;supino'
    );
    assert.match(lines[3], /;2;Normal;8;62,5;;sim;w1;supino$/);
    assert.match(lines[4], /;Prancha;1;Normal;0;0;45;sim;w1;prancha$/);
  });

  test('uma exportação por dia; falha libera o dia', async () => {
    await call('aluno');
    await rejectsWith(call('aluno'), 'resource-exhausted', /hoje/);
    const day = await adminDb.doc(`users/aluno/data_exports/${periodKey('day')}`).get();
    assert.equal(day.get('status'), 'done');
    // Outro usuário não é afetado.
    await call('outro');

    // Falha ao assinar: nada fica reservado, dá para tentar de novo.
    await adminDb.doc(`users/outro/data_exports/${periodKey('day')}`).delete();
    setExportUrlSigner(async () => {
      throw new Error('sem permissão de assinar');
    });
    try {
      await rejectsWith(call('outro'), 'internal');
    } finally {
      setExportUrlSigner(async (file, expiresAt) => `https://assinado.test/${file.name}?e=${expiresAt}`);
    }
    assert.equal((await adminDb.doc(`users/outro/data_exports/${periodKey('day')}`).get()).exists, false);
    await call('outro');
  });

  test('fotos acima do limite ficam de fora, com aviso', async () => {
    setExportPhotosLimit(12); // cabe só a foto do corpo (10 bytes)
    try {
      const res = await call('aluno');
      assert.equal(res.photos, 1);
      assert.equal(res.photosOmitted, 1);
      const json = JSON.parse(await readExport('aluno', 'dados.json'));
      assert.equal(json.fotosCorporais.find((f) => f.id === 'b1').arquivo, 'fotos/corporais/b1.jpg');
      assert.equal(json.refeicoes[0].foraDoZip, true);
    } finally {
      setExportPhotosLimit();
    }
  });

  test('photoStoragePath só aceita a pasta do próprio usuário', () => {
    assert.equal(photoStoragePath('a', { storagePath: 'users/a/body_photos/1.jpg' }), 'users/a/body_photos/1.jpg');
    assert.equal(photoStoragePath('a', { storagePath: 'users/b/body_photos/1.jpg' }), null);
    assert.equal(photoStoragePath('a', { storagePath: 'users/a/../b/x.jpg' }), null);
    assert.equal(
      photoStoragePath('a', { imageUrl: 'https://x/v0/b/bk/o/users%2Fa%2Fmeal_photos%2Fm.png?alt=media' }),
      'users/a/meal_photos/m.png'
    );
    assert.equal(photoStoragePath('a', { imageUrl: 'https://outro-site/foto.jpg' }), null);
  });

  test('guarda só a exportação mais recente', async () => {
    await bucket.file('users/aluno/exports/2026-01-01/meus-dados-newfitness.zip').save('velho');
    await call('aluno');
    const [files] = await bucket.getFiles({ prefix: 'users/aluno/exports/' });
    assert.equal(files.length, 1);
    assert.ok(files.every((f) => f.name.includes(periodKey('day'))));
  });

  test('duração: mesma regra do app (fim real; antigos até 3 h)', () => {
    const set = (extra = {}) => ({ reps: 8, weightKg: 60, completed: true, ...extra });
    const legacy10days = { date: 0, name: 'Antigo esquecido', durationSeconds: 10 * 24 * 3600, exercises: [{ exerciseName: 'Supino', sets: [set()] }] };
    const legacy1h = { date: 0, name: 'Antigo normal', durationSeconds: 3600, exercises: [{ exerciseName: 'Supino', sets: [set()] }] };
    // Treino novo: a duração gravada já vai até a última série + descanso.
    const withTimes = { date: 0, name: 'Novo', durationSeconds: 4 * 3600, exercises: [{ exerciseName: 'Supino', sets: [set({ completedAt: 123 })] }] };

    assert.equal(LEGACY_MAX_DURATION_SECONDS, 3 * 3600);
    assert.equal(effectiveDurationSeconds(legacy10days), 3 * 3600);
    assert.equal(effectiveDurationSeconds(legacy1h), 3600);
    assert.equal(effectiveDurationSeconds(withTimes), 4 * 3600);
    assert.equal(effectiveDurationSeconds({ durationSeconds: 0 }), 0);
    assert.equal(effectiveDurationSeconds({}), 0);

    const lines = workoutsCsv([
      { id: 'a', data: legacy10days },
      { id: 'b', data: legacy1h },
      { id: 'c', data: withTimes },
    ]).slice(1).trim().split('\r\n');
    const minutes = (line) => line.split(';')[2];
    assert.equal(minutes(lines[1]), '180');
    assert.equal(minutes(lines[2]), '60');
    assert.equal(minutes(lines[3]), '240');
  });

  test('workoutsCsv aguenta treino sem exercícios e campos faltando', () => {
    const csv = workoutsCsv([{ id: 'v', data: { date: 0 } }, { id: 'z', data: { exercises: [{ sets: [{}] }] } }]);
    const lines = csv.slice(1).trim().split('\r\n');
    assert.equal(lines.length, 2);
    assert.match(lines[1], /;Treino;;;1;Normal;;;;não;z;$/);
  });
});

describe('regras: data_exports e pasta exports', () => {
  const db = (uid) => testEnv.authenticatedContext(uid).firestore();
  const st = (uid) => testEnv.authenticatedContext(uid).storage(`gs://${BUCKET}`);

  test('dono lê o controle do dia, mas não grava nem apaga', async () => {
    await adminDb.doc('users/aluno/data_exports/2026-11-20').set({ status: 'done' });
    await assertSucceeds(getDoc(doc(db('aluno'), 'users/aluno/data_exports/2026-11-20')));
    await assertFails(deleteDoc(doc(db('aluno'), 'users/aluno/data_exports/2026-11-20')));
    await assertFails(setDoc(doc(db('aluno'), 'users/aluno/data_exports/2026-11-21'), { status: 'done' }));
    await assertFails(getDoc(doc(db('prof'), 'users/aluno/data_exports/2026-11-20')));
  });

  test('Storage: só o dono lê a exportação; ninguém grava ou apaga pelo app', async () => {
    await bucket.file('users/aluno/exports/2026-11-20/dados.json').save('{"ok":true}');
    await assertSucceeds(getBytes(ref(st('aluno'), 'users/aluno/exports/2026-11-20/dados.json')));
    await assertFails(getBytes(ref(st('prof'), 'users/aluno/exports/2026-11-20/dados.json')));
    await assertFails(getBytes(ref(st('outro'), 'users/aluno/exports/2026-11-20/dados.json')));
    await assertFails(
      uploadBytes(ref(st('aluno'), 'users/aluno/exports/x/dados.json'), Buffer.from('{}'), {
        contentType: 'application/json',
      })
    );
    await assertFails(deleteObject(ref(st('aluno'), 'users/aluno/exports/2026-11-20/dados.json')));
  });
});
