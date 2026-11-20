// Segurança do treino livre no perfil do aluno (`users/{uid}`): PAR-Q, aceite
// do aviso e `freeWorkoutDisabled` (só o personal vinculado muda). Contra o
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
const { doc, getDoc, setDoc, updateDoc } = require('firebase/firestore');

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
    await setDoc(doc(db, 'users/aluno'), {
      role: 'student',
      name: 'Aluno',
      instructorId: 'personal',
    });
    await setDoc(doc(db, 'users/sem-personal'), { role: 'student', name: 'X' });
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
const aluno = (db) => doc(db, 'users/aluno');

test('aluno grava o PAR-Q e o aceite do treino livre no próprio perfil', async () => {
  await assertSucceeds(
    setDoc(
      aluno(asUser('aluno')),
      {
        parq: { answers: [false, true, false, false, false, false, false], answeredAt: 1, version: 1 },
        freeWorkoutTermsAcceptedAt: 2,
      },
      { merge: true },
    ),
  );
});

test('personal vinculado lê o PAR-Q do aluno; outro personal não', async () => {
  await assertSucceeds(getDoc(aluno(asUser('personal'))));
  await assertFails(getDoc(aluno(asUser('outro-personal'))));
});

test('o próprio aluno NÃO muda freeWorkoutDisabled', async () => {
  await assertFails(updateDoc(aluno(asUser('aluno')), { freeWorkoutDisabled: false }));
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await updateDoc(aluno(ctx.firestore()), { freeWorkoutDisabled: true });
  });
  // Bloqueado pelo personal: o aluno não consegue se desbloquear...
  await assertFails(updateDoc(aluno(asUser('aluno')), { freeWorkoutDisabled: false }));
  // ...mas continua editando o resto do perfil.
  await assertSucceeds(updateDoc(aluno(asUser('aluno')), { name: 'Novo nome' }));
});

test('personal vinculado liga/desliga o treino livre (só esse campo)', async () => {
  await assertSucceeds(updateDoc(aluno(asUser('personal')), { freeWorkoutDisabled: true }));
  await assertSucceeds(updateDoc(aluno(asUser('personal')), { freeWorkoutDisabled: false }));
  await assertFails(updateDoc(aluno(asUser('personal')), { freeWorkoutDisabled: 'sim' }));
  await assertFails(
    updateDoc(aluno(asUser('personal')), { freeWorkoutDisabled: true, name: 'Hack' }),
  );
  await assertFails(updateDoc(aluno(asUser('personal')), { name: 'Hack' }));
});

test('outro personal não mexe; o admin pode', async () => {
  await assertFails(updateDoc(aluno(asUser('outro-personal')), { freeWorkoutDisabled: true }));
  await assertFails(
    updateDoc(doc(asUser('personal'), 'users/sem-personal'), { freeWorkoutDisabled: true }),
  );
  await assertSucceeds(updateDoc(aluno(asAdmin()), { freeWorkoutDisabled: true }));
});

test('perfil não nasce com freeWorkoutDisabled', async () => {
  await assertFails(
    setDoc(doc(asUser('novo'), 'users/novo'), { role: 'student', freeWorkoutDisabled: false }),
  );
  await assertSucceeds(setDoc(doc(asUser('novo2'), 'users/novo2'), { role: 'student' }));
});

// Prompt 3 etapa 3: meta semanal e resumo de conquistas no perfil.
test('aluno grava a meta semanal e as conquistas no próprio perfil', async () => {
  await assertSucceeds(
    setDoc(
      aluno(asUser('aluno')),
      { weeklyGoal: 4, achievements: { firstWorkout: 1, workouts10: 2 } },
      { merge: true },
    ),
  );
});

test('personal NÃO grava meta nem conquistas no perfil do aluno', async () => {
  await assertFails(updateDoc(aluno(asUser('personal')), { weeklyGoal: 7 }));
  await assertFails(
    updateDoc(aluno(asUser('personal')), { achievements: { weeks26: 1 } }),
  );
  await assertFails(updateDoc(aluno(asUser('outro-personal')), { weeklyGoal: 1 }));
});
