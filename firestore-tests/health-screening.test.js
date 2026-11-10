// Regras do questionário de saúde (`users/{uid}/health_screenings`), contra o
// Firestore Emulator. Dados fictícios.
'use strict';

const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
} = require('firebase/firestore');

const ADMIN_EMAIL = 'isaquetrabalho005@gmail.com';
let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-newfitness-rules-test',
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/aluno'), { role: 'student', instructorId: 'personal' });
    await setDoc(doc(db, 'users/personal'), { role: 'instructor' });
    await setDoc(doc(db, 'users/outro-personal'), { role: 'instructor' });
  });
});

const asUser = (uid) =>
  testEnv.authenticatedContext(uid, { email: `${uid}@aluno.test` }).firestore();
const asAdmin = () =>
  testEnv
    .authenticatedContext('admin-uid', { email: ADMIN_EMAIL, email_verified: true })
    .firestore();

const ok = { answers: [false, false, false, false, false], cleared: true, createdAt: 1, version: 1 };
const flagged = { answers: [false, true, false, false, false], cleared: false, createdAt: 2, version: 1 };
const ref = (db, id = 's1') => doc(db, `users/aluno/health_screenings/${id}`);

test('aluno grava resposta sem nenhum "sim" como liberada', async () => {
  await assertSucceeds(setDoc(ref(asUser('aluno')), ok));
});

test('aluno grava resposta com "sim" como não liberada', async () => {
  await assertSucceeds(setDoc(ref(asUser('aluno')), flagged));
});

test('não dá para marcar como liberada quando há um "sim"', async () => {
  await assertFails(setDoc(ref(asUser('aluno')), { ...flagged, cleared: true }));
});

test('não aceita campos extras nem faltando', async () => {
  await assertFails(setDoc(ref(asUser('aluno')), { ...ok, extra: 1 }));
  const { version, ...semVersao } = ok;
  await assertFails(setDoc(ref(asUser('aluno')), semVersao));
});

test('ninguém grava em nome do aluno', async () => {
  await assertFails(setDoc(ref(asUser('personal')), ok));
  await assertFails(setDoc(ref(asAdmin()), ok));
});

test('resposta não pode ser editada nem apagada', async () => {
  await assertSucceeds(setDoc(ref(asUser('aluno')), flagged));
  await assertFails(updateDoc(ref(asUser('aluno')), { cleared: true, answers: ok.answers }));
  await assertFails(deleteDoc(ref(asUser('aluno'))));
  await assertFails(deleteDoc(ref(asAdmin())));
});

test('leem: dono, personal vinculado e admin; outro personal não', async () => {
  await assertSucceeds(setDoc(ref(asUser('aluno')), flagged));
  await assertSucceeds(getDoc(ref(asUser('aluno'))));
  await assertSucceeds(getDoc(ref(asUser('personal'))));
  await assertSucceeds(getDoc(ref(asAdmin())));
  await assertFails(getDoc(ref(asUser('outro-personal'))));
});
