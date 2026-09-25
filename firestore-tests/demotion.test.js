// Rebaixamento de instrutor — testes COMPORTAMENTAIS com a Cloud Function
// real `setUserRole` (admin.ts), o helper `revokeInstructorLinks`
// (linking.ts) e as regras reais do Firestore e do Storage, no MESMO
// projeto do emulador (as regras do Storage consultam o Firestore).
//
// Problema coberto: mudar só o `role` de um instrutor deixava os alunos
// com `instructorId` apontando para ele — e as regras continuavam dando
// acesso. Nunca toca produção; dados fictícios.
//
// Pré-requisito: `npm run build` em functions/.
'use strict';

const { test, before, after, beforeEach, describe } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const PROJECT_ID = 'demo-newfitness-rules-test';
process.env.GCLOUD_PROJECT = PROJECT_ID;
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';

const admin = require('../functions/node_modules/firebase-admin');
admin.initializeApp({ projectId: PROJECT_ID });
const adminDb = admin.firestore();

const { ensureInviteCode, linkToProfessional, revokeInstructorLinks } = require('../functions/lib/linking.js');
const { setUserRole } = require('../functions/lib/admin.js');

const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
  collection,
  collectionGroup,
  query,
  where,
} = require('firebase/firestore');

const ADMIN_EMAIL = 'isaquetrabalho005@gmail.com';
let testEnv;
let contexts;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
    storage: {
      rules: fs.readFileSync(path.join(__dirname, '..', 'storage.rules'), 'utf8'),
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
});

// Um contexto por usuário por teste, e cada `.firestore()`/`.storage()`
// criado uma vez só (chamar de novo no mesmo contexto dá "Firestore has
// already been started").
function ctx(uid, email = `${uid}@x.test`) {
  if (!contexts.has(uid)) {
    const context = testEnv.authenticatedContext(uid, { email });
    let fsInstance;
    let storageInstance;
    contexts.set(uid, {
      firestore: () => (fsInstance ??= context.firestore()),
      storage: () => (storageInstance ??= context.storage()),
    });
  }
  return contexts.get(uid);
}
const client = (uid) => ctx(uid).firestore();

const asAdmin = (data) =>
  setUserRole.run({ data, auth: { uid: 'admin-uid', token: { email: ADMIN_EMAIL, email_verified: true } } });
const callAs = (fn, uid, data = {}) => fn.run({ data, auth: { uid, token: { email: `${uid}@x.test` } } });

async function rejectsWith(promise, code) {
  await assert.rejects(promise, (err) => {
    assert.equal(err.code, code, `esperado "${code}", veio "${err.code}" (${err.message})`);
    return true;
  });
}

async function profile(uid) {
  return (await adminDb.doc(`users/${uid}`).get()).data();
}

/**
 * Instrutor A com [n] alunos vinculados, cada um com histórico completo:
 * treino, plano, avaliação, foto (Firestore + Storage), agenda, resumo de
 * progresso e assinatura. Tudo gravado pelo Admin SDK (estado inicial).
 */
async function seedInstructorWithStudents(n, { nutritionistOf = {} } = {}) {
  await adminDb.doc('users/profA').set({
    name: 'Prof. A',
    role: 'instructor',
    inviteCode: 'CODIGOA2',
  });
  await adminDb.doc('invite_codes/CODIGOA2').set({ uid: 'profA', kind: 'instructor' });
  const students = [];
  for (let i = 1; i <= n; i++) {
    const uid = `aluno${i}`;
    students.push(uid);
    await adminDb.doc(`users/${uid}`).set({
      name: `Aluno ${i}`,
      role: 'student',
      instructorId: 'profA',
      nutritionistId: nutritionistOf[uid] ?? null,
    });
    await adminDb.doc(`users/profA/students/${uid}`).set({ name: `Aluno ${i}`, notes: `nota ${i}`, active: true });
    await adminDb.doc(`users/${uid}/workouts/w1`).set({ userId: uid, name: 'Treino' });
    await adminDb.doc(`users/${uid}/progress_records/e1`).set({ exerciseId: 'e1' });
    await adminDb.doc(`users/${uid}/training_plans/p1`).set({ studentUid: uid, instructorUid: 'profA', title: 'Plano' });
    await adminDb.doc(`users/${uid}/physical_assessments/av1`).set({
      userId: uid,
      date: 1720000000000,
      weightKg: 80,
      recordedBy: 'instructor',
      createdByUid: 'profA',
    });
    await adminDb.doc(`users/${uid}/body_photos/f1`).set({
      userId: uid,
      date: 1720000000000,
      storagePath: `users/${uid}/body_photos/f1.jpg`,
    });
    await adminDb.doc(`users/${uid}/appointments/ag1`).set({
      instructorUid: 'profA',
      studentUid: uid,
      title: 'Avaliação',
      start: 1720000000000 + i,
    });
    await adminDb.doc(`users/${uid}/appointments/ag2`).set({
      instructorUid: 'profA',
      studentUid: uid,
      title: 'Treino presencial',
      start: 1730000000000 + i,
    });
    await adminDb.doc(`users/${uid}/finance/subscription`).set({ status: 'authorized' });
    await testEnv.withSecurityRulesDisabled(async (c) => {
      await c.storage().ref(`users/${uid}/body_photos/f1.jpg`).put(new Uint8Array([1, 2, 3]), {
        contentType: 'image/jpeg',
      });
    });
  }
  return students;
}

/** Tudo o que um instrutor vinculado lê de um aluno — deve falhar para A. */
async function assertInstructorHasNoAccess(uid, studentUid) {
  const db = client(uid);
  await assertFails(getDoc(doc(db, `users/${studentUid}`)));
  await assertFails(getDoc(doc(db, `users/${studentUid}/workouts/w1`)));
  await assertFails(getDoc(doc(db, `users/${studentUid}/progress_records/e1`)));
  await assertFails(getDoc(doc(db, `users/${studentUid}/training_plans/p1`)));
  await assertFails(getDoc(doc(db, `users/${studentUid}/physical_assessments/av1`)));
  await assertFails(getDoc(doc(db, `users/${studentUid}/body_photos/f1`)));
  await assertFails(getDoc(doc(db, `users/${studentUid}/appointments/ag1`)));
  await assertFails(getDoc(doc(db, `users/${studentUid}/finance/subscription`)));
  await assertFails(ctx(uid).storage().ref(`users/${studentUid}/body_photos/f1.jpg`).getMetadata());
  // e também não escreve nada protegido por vínculo
  await assertFails(
    setDoc(doc(db, `users/${studentUid}/training_plans/p2`), { studentUid, title: 'x', workouts: [] }),
  );
  await assertFails(
    setDoc(doc(db, `users/${studentUid}/physical_assessments/av2`), {
      userId: studentUid,
      date: 1,
      recordedBy: 'instructor',
      createdByUid: uid,
    }),
  );
}

async function assertHistoryPreserved(studentUid) {
  const db = client(studentUid);
  await assertSucceeds(getDoc(doc(db, `users/${studentUid}/workouts/w1`)));
  await assertSucceeds(getDoc(doc(db, `users/${studentUid}/progress_records/e1`)));
  await assertSucceeds(getDoc(doc(db, `users/${studentUid}/training_plans/p1`)));
  const av = await assertSucceeds(getDoc(doc(db, `users/${studentUid}/physical_assessments/av1`)));
  assert.equal(av.data().createdByUid, 'profA');
  await assertSucceeds(getDoc(doc(db, `users/${studentUid}/body_photos/f1`)));
  await assertSucceeds(ctx(studentUid).storage().ref(`users/${studentUid}/body_photos/f1.jpg`).getMetadata());
  const ag = await assertSucceeds(getDoc(doc(db, `users/${studentUid}/appointments/ag1`)));
  assert.equal(ag.data().title, 'Avaliação');
  assert.equal(ag.data().formerInstructorUid, 'profA');
  assert.equal(ag.data().instructorUid, undefined);
}

const agendaOf = (uid) =>
  getDocs(query(collectionGroup(client(uid), 'appointments'), where('instructorUid', '==', uid)));
const studentsQuery = (uid) =>
  getDocs(query(collection(client(uid), 'users'), where('instructorId', '==', uid)));

// ---------------------------------------------------------------------------
describe('Rebaixamento de instrutor (setUserRole)', () => {
  test('A. instrutor → aluno: perde todo acesso; vínculos encerrados; histórico mantido', async () => {
    await seedInstructorWithStudents(1);
    // antes: acessa
    await assertSucceeds(getDoc(doc(client('profA'), 'users/aluno1/workouts/w1')));

    const result = await asAdmin({ uid: 'profA', role: 'student' });
    assert.equal(result.revokedStudents, 1);

    const a = await profile('profA');
    assert.equal(a.role, 'student');
    assert.equal(a.pendingRoleChange, undefined);
    assert.equal((await profile('aluno1')).instructorId, null);
    const entry = (await adminDb.doc('users/profA/students/aluno1').get()).data();
    assert.equal(entry.active, false);
    assert.equal(entry.notes, 'nota 1', 'notas do instrutor preservadas');

    await assertInstructorHasNoAccess('profA', 'aluno1');
    assert.equal((await assertSucceeds(agendaOf('profA'))).size, 0);
    assert.equal((await assertSucceeds(studentsQuery('profA'))).size, 0);
    await assertHistoryPreserved('aluno1');
  });

  test('B. instrutor → nutricionista: perde acesso de instrutor; vínculos de nutrição intactos', async () => {
    // aluno1 também tem outra nutricionista; aluno9 tem A como nutricionista
    // (dado antigo de quando A era nutricionista) — nada disso pode mudar.
    await seedInstructorWithStudents(2, { nutritionistOf: { aluno1: 'nutriN' } });
    await adminDb.doc('users/nutriN').set({ role: 'nutritionist' });
    await adminDb.doc('users/aluno9').set({ role: 'student', instructorId: null, nutritionistId: 'profA' });
    await adminDb.doc('users/profA/nutrition_students/aluno9').set({ name: 'Aluno 9', active: true });

    await asAdmin({ uid: 'profA', role: 'nutritionist' });

    assert.equal((await profile('profA')).role, 'nutritionist');
    assert.equal((await profile('aluno1')).instructorId, null);
    assert.equal((await profile('aluno2')).instructorId, null);
    assert.equal((await profile('aluno1')).nutritionistId, 'nutriN');
    assert.equal((await profile('aluno9')).nutritionistId, 'profA');
    assert.equal((await adminDb.doc('users/profA/nutrition_students/aluno9').get()).data().active, true);
    await assertInstructorHasNoAccess('profA', 'aluno1');
    await assertInstructorHasNoAccess('profA', 'aluno2');
    // A continua nutricionista do aluno9 (vínculo de nutrição, não mexido).
    await assertSucceeds(getDoc(doc(client('profA'), 'users/aluno9')));
    const remaining = await adminDb.collection('users').where('instructorId', '==', 'profA').get();
    assert.equal(remaining.size, 0);
  });

  test('C. vários alunos: todos desvinculados (inclusive agenda de todos)', async () => {
    const students = await seedInstructorWithStudents(6);
    const result = await asAdmin({ uid: 'profA', role: 'student' });
    assert.equal(result.revokedStudents, 6);
    for (const uid of students) {
      assert.equal((await profile(uid)).instructorId, null);
      await assertInstructorHasNoAccess('profA', uid);
      await assertHistoryPreserved(uid);
    }
    const agenda = await adminDb.collectionGroup('appointments').where('instructorUid', '==', 'profA').get();
    assert.equal(agenda.size, 0);
  });

  test('C2. lotes pequenos (paginação + commits parciais) chegam ao mesmo resultado', async () => {
    const students = await seedInstructorWithStudents(5);
    // 2 alunos por página, commit a cada 3 operações — força vários lotes.
    const revoked = await revokeInstructorLinks(adminDb, 'profA', { pageSize: 2, maxOps: 3 });
    assert.equal(revoked, 5);
    for (const uid of students) assert.equal((await profile(uid)).instructorId, null);
    const agenda = await adminDb.collectionGroup('appointments').where('instructorUid', '==', 'profA').get();
    assert.equal(agenda.size, 0);
    const active = (await adminDb.collection('users/profA/students').get()).docs.filter((d) => d.data().active !== false);
    assert.equal(active.length, 0);
  });

  test('D. instrutor sem alunos: troca de papel funciona normalmente', async () => {
    await adminDb.doc('users/profA').set({ role: 'instructor', inviteCode: 'CODIGOA2' });
    const result = await asAdmin({ uid: 'profA', role: 'student' });
    assert.equal(result.revokedStudents, 0);
    assert.equal((await profile('profA')).role, 'student');
    // promover (não é rebaixamento) também funciona e não desvincula nada
    await adminDb.doc('users/aluno1').set({ role: 'student', instructorId: 'outro' });
    await asAdmin({ uid: 'aluno1', role: 'nutritionist' });
    assert.equal((await profile('aluno1')).role, 'nutritionist');
    assert.equal((await profile('aluno1')).instructorId, 'outro');
  });

  test('E. sem ser admin: negado (aluno, instrutor, nutricionista, sem login); dados inválidos', async () => {
    await seedInstructorWithStudents(1);
    await adminDb.doc('users/nutriN').set({ role: 'nutritionist' });
    await rejectsWith(callAs(setUserRole, 'aluno1', { uid: 'profA', role: 'student' }), 'permission-denied');
    await rejectsWith(callAs(setUserRole, 'profA', { uid: 'aluno1', role: 'instructor' }), 'permission-denied');
    await rejectsWith(callAs(setUserRole, 'nutriN', { uid: 'profA', role: 'student' }), 'permission-denied');
    await rejectsWith(setUserRole.run({ data: { uid: 'profA', role: 'student' }, auth: undefined }), 'unauthenticated');
    await rejectsWith(asAdmin({ uid: 'profA', role: 'admin' }), 'invalid-argument');
    await rejectsWith(asAdmin({ uid: 'naoexiste', role: 'student' }), 'not-found');
    // nada mudou
    assert.equal((await profile('profA')).role, 'instructor');
    assert.equal((await profile('aluno1')).instructorId, 'profA');
  });

  test('F. ninguém altera `role` (nem a trava) direto pelo cliente — nem o admin', async () => {
    await seedInstructorWithStudents(1);
    await assertFails(updateDoc(doc(client('aluno1'), 'users/aluno1'), { role: 'instructor' }));
    await assertFails(updateDoc(doc(client('profA'), 'users/profA'), { role: 'student' }));
    await assertFails(updateDoc(doc(client('profA'), 'users/aluno1'), { role: 'instructor' }));
    const adminClient = testEnv.authenticatedContext('admin-uid', { email: ADMIN_EMAIL, email_verified: true }).firestore();
    await assertFails(updateDoc(doc(adminClient, 'users/profA'), { role: 'student' }));
    await assertFails(updateDoc(doc(client('profA'), 'users/profA'), { pendingRoleChange: 'student' }));
    // admin continua lendo e editando outros campos
    await assertSucceeds(updateDoc(doc(adminClient, 'users/profA'), { name: 'Prof. A (editado)' }));
  });

  test('G. interrupção no meio: papel não muda, vínculos novos bloqueados, rodar de novo conclui', async () => {
    await seedInstructorWithStudents(3);
    // Estado deixado por uma execução que caiu no meio: trava gravada,
    // aluno1 já desligado mas com agenda e entrada ainda apontando para A.
    await adminDb.doc('users/profA').update({ pendingRoleChange: 'student' });
    await adminDb.doc('users/aluno1').update({ instructorId: null });

    // 1) o papel NÃO mudou (continua instrutor, o admin viu o erro)
    assert.equal((await profile('profA')).role, 'instructor');
    // 2) durante a trava, ninguém consegue se vincular a A
    await adminDb.doc('users/novo').set({ role: 'student', instructorId: null });
    await rejectsWith(
      callAs(linkToProfessional, 'novo', { code: 'CODIGOA2', kind: 'instructor' }),
      'invalid-argument',
    );
    assert.equal((await profile('novo')).instructorId, null);
    // 3) a agenda do aluno já desligado ainda apontava para A (sobra do meio)
    assert.equal((await adminDb.doc('users/aluno1/appointments/ag1').get()).data().instructorUid, 'profA');

    // Rodar de novo termina tudo — inclusive o que ficou do aluno1.
    const result = await asAdmin({ uid: 'profA', role: 'student' });
    assert.equal(result.revokedStudents, 2);
    assert.equal((await profile('profA')).role, 'student');
    assert.equal((await profile('profA')).pendingRoleChange, undefined);
    for (const uid of ['aluno1', 'aluno2', 'aluno3']) {
      assert.equal((await profile(uid)).instructorId, null);
      await assertInstructorHasNoAccess('profA', uid);
      await assertHistoryPreserved(uid);
    }
    assert.equal((await adminDb.doc('users/profA/students/aluno1').get()).data().active, false);

    // E rodar uma terceira vez (já concluído) é inofensivo.
    const again = await asAdmin({ uid: 'profA', role: 'student' });
    assert.equal(again.revokedStudents, 0);
  });

  test('H. instrutor → aluno → instrutor: vínculos antigos NÃO voltam; novos só pelo fluxo normal', async () => {
    await seedInstructorWithStudents(2);
    await asAdmin({ uid: 'profA', role: 'student' });
    await asAdmin({ uid: 'profA', role: 'instructor' });

    assert.equal((await profile('profA')).role, 'instructor');
    assert.equal((await profile('aluno1')).instructorId, null);
    assert.equal((await profile('aluno2')).instructorId, null);
    await assertInstructorHasNoAccess('profA', 'aluno1');
    assert.equal((await adminDb.doc('users/profA/students/aluno1').get()).data().active, false);

    // aluno1 volta pelo código (fluxo normal) — só ele ganha acesso de novo
    const { code } = await callAs(ensureInviteCode, 'profA');
    await callAs(linkToProfessional, 'aluno1', { code, kind: 'instructor' });
    assert.equal((await profile('aluno1')).instructorId, 'profA');
    await assertSucceeds(getDoc(doc(client('profA'), 'users/aluno1/workouts/w1')));
    await assertInstructorHasNoAccess('profA', 'aluno2');
  });

  test('I. rebaixado tenta tudo, inclusive reativar `students` à mão — tudo negado', async () => {
    await seedInstructorWithStudents(1);
    await asAdmin({ uid: 'profA', role: 'student' });

    // Reativar a própria entrada antiga (ele pode escrever na própria
    // subcoleção) não concede acesso a nada do aluno.
    await assertSucceeds(
      setDoc(doc(client('profA'), 'users/profA/students/aluno1'), { active: true }, { merge: true }),
    );
    await assertInstructorHasNoAccess('profA', 'aluno1');
    assert.equal((await assertSucceeds(agendaOf('profA'))).size, 0);
    assert.equal((await assertSucceeds(studentsQuery('profA'))).size, 0);
    // e não consegue se re-vincular ao aluno escrevendo o campo
    await assertFails(updateDoc(doc(client('profA'), 'users/aluno1'), { instructorId: 'profA' }));
    // Nem usar o código antigo para receber alunos (agora é aluno)
    await adminDb.doc('users/novo').set({ role: 'student', instructorId: null });
    await rejectsWith(
      callAs(linkToProfessional, 'novo', { code: 'CODIGOA2', kind: 'instructor' }),
      'invalid-argument',
    );
  });

  test('só o instrutor ATUALMENTE vinculado tem acesso de instrutor', async () => {
    await seedInstructorWithStudents(1);
    await adminDb.doc('users/profB').set({ role: 'instructor', inviteCode: 'CODIGOB3' });
    await adminDb.doc('invite_codes/CODIGOB3').set({ uid: 'profB', kind: 'instructor' });
    await asAdmin({ uid: 'profA', role: 'student' });
    await callAs(linkToProfessional, 'aluno1', { code: 'CODIGOB3', kind: 'instructor' });

    await assertSucceeds(getDoc(doc(client('profB'), 'users/aluno1/workouts/w1')));
    await assertSucceeds(getDoc(doc(client('profB'), 'users/aluno1/body_photos/f1')));
    await assertInstructorHasNoAccess('profA', 'aluno1');
  });
});
