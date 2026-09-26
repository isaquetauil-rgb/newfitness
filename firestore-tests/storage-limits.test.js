// Rodada 5 — limites e permissões do Storage e `meal_photos` imutável pelo
// cliente. Testes COMPORTAMENTAIS de `../storage.rules` e
// `../firestore.rules` contra os emuladores de Storage e Firestore (as
// regras do Storage leem o papel do perfil no Firestore). Dados fictícios.
'use strict';

const { test, before, after, beforeEach, describe } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, updateDoc, deleteDoc } = require('firebase/firestore');

const ROOT = path.join(__dirname, '..');
const MB = 1024 * 1024;

let testEnv;
let contexts;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-newfitness-rules-test',
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
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  contexts = new Map();
  await testEnv.clearFirestore();
  await testEnv.clearStorage();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/aluno'), { name: 'Ana', role: 'student', nutritionistId: 'nutri' });
    await setDoc(doc(db, 'users/outroAluno'), { name: 'Beto', role: 'student' });
    await setDoc(doc(db, 'users/prof'), { name: 'Paulo', role: 'instructor' });
    await setDoc(doc(db, 'users/outroProf'), { name: 'Pedro', role: 'instructor' });
    await setDoc(doc(db, 'users/nutri'), { name: 'Nina', role: 'nutritionist' });
    await setDoc(doc(db, 'users/aluno/meal_photos/m1'), {
      userId: 'aluno',
      date: 1,
      mealType: 'lunch',
      imageUrl: 'https://x/original.jpg',
      aiAnalysis: null,
      aiAnalysisError: null,
    });
  });
});

/** Um contexto (e uma instância de Firestore/Storage) por usuário por teste. */
function ctx(uid) {
  if (!contexts.has(uid)) {
    const context = testEnv.authenticatedContext(uid, { email: `${uid}@x.test`, email_verified: true });
    let firestore;
    let storage;
    contexts.set(uid, {
      firestore: () => (firestore ??= context.firestore()),
      storage: () => (storage ??= context.storage()),
    });
  }
  return contexts.get(uid);
}

const bytes = (n) => new Uint8Array(n);

// ---------------------------------------------------------------------------
describe('meal_photos (Firestore): o cliente não edita', () => {
  const photo = (uid, id = 'm1') => doc(ctx(uid).firestore(), `users/aluno/meal_photos/${id}`);

  test('F1. o dono NÃO edita a foto (nem troca imageUrl, nem mealType)', async () => {
    await assertFails(updateDoc(photo('aluno'), { imageUrl: 'https://x/outra.jpg' }));
    await assertFails(updateDoc(photo('aluno'), { mealType: 'dinner' }));
    await assertFails(setDoc(photo('aluno'), { userId: 'aluno', date: 2, mealType: 'snack', imageUrl: 'y' }));
  });

  test('F2. o dono continua criando (sem análise) e apagando', async () => {
    await assertSucceeds(
      setDoc(photo('aluno', 'nova'), { userId: 'aluno', date: 1, mealType: 'lunch', imageUrl: 'x', aiAnalysis: null }),
    );
    await assertSucceeds(deleteDoc(photo('aluno', 'nova')));
    await assertSucceeds(deleteDoc(photo('aluno')));
  });
});

// ---------------------------------------------------------------------------
describe('Storage: meal_photos', () => {
  const file = (uid, owner = 'aluno', name = 'f.jpg') => ctx(uid).storage().ref(`users/${owner}/meal_photos/${name}`);

  test('M1. imagem válida do dono é aceita (JPEG, PNG e WebP)', async () => {
    await assertSucceeds(file('aluno', 'aluno', 'a.jpg').put(bytes(10), { contentType: 'image/jpeg' }));
    await assertSucceeds(file('aluno', 'aluno', 'b.png').put(bytes(10), { contentType: 'image/png' }));
    await assertSucceeds(file('aluno', 'aluno', 'c.webp').put(bytes(10), { contentType: 'image/webp' }));
    await assertSucceeds(file('aluno', 'aluno', 'limite.jpg').put(bytes(5 * MB), { contentType: 'image/jpeg' }));
  });

  test('M2. tipo errado é negado (gif, heic, pdf, vídeo)', async () => {
    for (const contentType of ['image/gif', 'image/heic', 'application/pdf', 'video/mp4']) {
      await assertFails(file('aluno', 'aluno', 'x').put(bytes(10), { contentType }));
    }
  });

  test('M3. acima de 5 MB é negado', async () => {
    await assertFails(file('aluno', 'aluno', 'big.jpg').put(bytes(5 * MB + 1), { contentType: 'image/jpeg' }));
  });

  test('M4. pasta de outro usuário é negada (inclusive para a nutricionista vinculada)', async () => {
    await assertFails(file('outroAluno', 'aluno', 'i.jpg').put(bytes(10), { contentType: 'image/jpeg' }));
    await assertFails(file('nutri', 'aluno', 'i.jpg').put(bytes(10), { contentType: 'image/jpeg' }));
  });

  test('M5. leitura e remoção continuam como antes', async () => {
    await assertSucceeds(file('aluno', 'aluno', 'a.jpg').put(bytes(10), { contentType: 'image/jpeg' }));
    await assertSucceeds(file('nutri', 'aluno', 'a.jpg').getMetadata());
    await assertFails(file('outroAluno', 'aluno', 'a.jpg').getMetadata());
    await assertFails(file('outroAluno', 'aluno', 'a.jpg').delete());
    await assertSucceeds(file('aluno', 'aluno', 'a.jpg').delete());
  });
});

// ---------------------------------------------------------------------------
describe('Storage: exercise_videos', () => {
  const video = (uid, owner, name = 'v.mp4') => ctx(uid).storage().ref(`users/${owner}/exercise_videos/${name}`);

  test('V1. instrutor na própria pasta: MP4, MOV e WebM aceitos (até 50 MB)', async () => {
    await assertSucceeds(video('prof', 'prof', 'a.mp4').put(bytes(10), { contentType: 'video/mp4' }));
    await assertSucceeds(video('prof', 'prof', 'b.mov').put(bytes(10), { contentType: 'video/quicktime' }));
    await assertSucceeds(video('prof', 'prof', 'c.webm').put(bytes(10), { contentType: 'video/webm' }));
    await assertSucceeds(video('prof', 'prof', 'limite.mp4').put(bytes(50 * MB), { contentType: 'video/mp4' }));
  });

  test('V2. aluno e nutricionista NÃO enviam vídeo (nem na própria pasta)', async () => {
    await assertFails(video('aluno', 'aluno').put(bytes(10), { contentType: 'video/mp4' }));
    await assertFails(video('nutri', 'nutri').put(bytes(10), { contentType: 'video/mp4' }));
  });

  test('V3. tipo errado é negado (m4v, 3gp, mkv, imagem)', async () => {
    for (const contentType of ['video/x-m4v', 'video/3gpp', 'video/x-matroska', 'image/jpeg']) {
      await assertFails(video('prof', 'prof', 'x').put(bytes(10), { contentType }));
    }
  });

  test('V4. acima de 50 MB é negado', async () => {
    await assertFails(video('prof', 'prof', 'big.mp4').put(bytes(50 * MB + 1), { contentType: 'video/mp4' }));
  });

  test('V5. pasta de outro instrutor é negada', async () => {
    await assertFails(video('prof', 'outroProf').put(bytes(10), { contentType: 'video/mp4' }));
    await assertSucceeds(video('outroProf', 'outroProf').put(bytes(10), { contentType: 'video/mp4' }));
    await assertFails(video('prof', 'outroProf').delete());
  });
});
