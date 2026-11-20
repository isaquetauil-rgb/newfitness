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
} = require('../functions/lib/export.js');
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
  await adminDb.doc('users/aluno/meal_photos/m1').set({ mealType: 'lunch', imageUrl: 'https://x/m1.jpg' });
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

async function readExport(uid, name) {
  const [files] = await bucket.getFiles({ prefix: `users/${uid}/exports/` });
  const file = files.find((f) => f.name.endsWith(name));
  assert.ok(file, `arquivo ${name} não encontrado`);
  const [buf] = await file.download();
  return buf.toString('utf8');
}

describe('exportMyData', () => {
  test('sem login: recusado', async () => {
    await rejectsWith(call(null), 'unauthenticated');
  });

  test('exporta só os dados do próprio usuário, com links de 1 hora', async () => {
    const before = Date.now();
    const res = await call('aluno');
    assert.equal(res.workouts, 2);
    assert.match(res.jsonUrl, /^https:\/\/assinado\.test\/users\/aluno\/exports\/.+\/dados\.json/);
    assert.match(res.csvUrl, /treinos\.csv/);
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
    assert.equal(json.refeicoes[0].imageUrl, 'https://x/m1.jpg');
    assert.equal(json.planosDeTreino[0].title, 'Plano A');
    assert.equal(json.planosDeNutricao[0].title, 'Dieta');
    assert.match(json.fotosCorporais[0].link, /body_photos\/b1\.jpg/);
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

  test('guarda só a exportação mais recente', async () => {
    await bucket.file('users/aluno/exports/2026-01-01/dados.json').save('{}');
    await call('aluno');
    const [files] = await bucket.getFiles({ prefix: 'users/aluno/exports/' });
    assert.equal(files.length, 2);
    assert.ok(files.every((f) => f.name.includes(periodKey('day'))));
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
