// Rodada 3 de segurança — testes COMPORTAMENTAIS:
//  - admin só com e-mail VERIFICADO (regras e Functions `setUserRole`,
//    `getAdminStats`, `reviewProfessionalRequest`);
//  - pedido de profissional só com e-mail verificado;
//  - agenda: o instrutor só grava compromisso em nome próprio e nunca troca
//    o `instructorUid` (a agenda consolidada é liberada por esse campo).
// Regras e Functions reais no mesmo projeto do emulador. Nunca toca
// produção; dados fictícios.
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

const { setUserRole, getAdminStats, reviewProfessionalRequest } = require('../functions/lib/admin.js');

const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  getDocs,
  setDoc,
  addDoc,
  updateDoc,
  collection,
  collectionGroup,
  query,
  where,
  serverTimestamp,
} = require('firebase/firestore');

const ADMIN_EMAIL = 'isaquetrabalho005@gmail.com';
let testEnv;
let dbs;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
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
  dbs = new Map();
  await testEnv.clearFirestore();
});

/** Uma instância por (uid, e-mail, verificado) por teste. */
function db(uid, { email = `${uid}@x.test`, verified = true } = {}) {
  const key = `${uid}|${email}|${verified}`;
  if (!dbs.has(key)) {
    dbs.set(
      key,
      testEnv.authenticatedContext(uid, { email, email_verified: verified }).firestore(),
    );
  }
  return dbs.get(key);
}
const adminDbClient = (verified) => db('admin-uid', { email: ADMIN_EMAIL, verified });
const adminCall = (fn, data, verified) =>
  fn.run({ data, auth: { uid: 'admin-uid', token: { email: ADMIN_EMAIL, email_verified: verified } } });

async function rejectsWith(promise, code) {
  await assert.rejects(promise, (err) => {
    assert.equal(err.code, code, `esperado "${code}", veio "${err.code}" (${err.message})`);
    return true;
  });
}

// ---------------------------------------------------------------------------
describe('Admin só com e-mail verificado', () => {
  beforeEach(async () => {
    await adminDb.doc('users/ana').set({ name: 'Ana', role: 'student' });
    await adminDb.doc('users/ana/physical_assessments/av1').set({ userId: 'ana', date: 1, recordedBy: 'self' });
    await adminDb.doc('professional_requests/ana').set({
      uid: 'ana',
      kind: 'instructor',
      registrationNumber: '123456-G',
      registrationRegion: 'SP',
      name: 'Ana',
      email: 'ana@x.test',
      status: 'pending',
      createdAt: admin.firestore.Timestamp.now(),
    });
  });

  test('V1. e-mail certo mas NÃO verificado: regras negam tudo que é de admin', async () => {
    const a = adminDbClient(false);
    await assertFails(getDoc(doc(a, 'users/ana')));
    await assertFails(getDoc(doc(a, 'users/ana/physical_assessments/av1')));
    await assertFails(setDoc(doc(a, 'exercises/novo'), { name: 'X' }));
    await assertFails(setDoc(doc(a, 'muscle_groups/g1'), { name: 'X' }));
    await assertFails(getDoc(doc(a, 'professional_requests/ana')));
  });

  test('V2. e-mail certo mas NÃO verificado: Functions de admin negam', async () => {
    await rejectsWith(adminCall(setUserRole, { uid: 'ana', role: 'instructor' }, false), 'permission-denied');
    await rejectsWith(adminCall(getAdminStats, {}, false), 'permission-denied');
    await rejectsWith(
      adminCall(reviewProfessionalRequest, { uid: 'ana', decision: 'approve' }, false),
      'permission-denied',
    );
    // sem o campo também nega
    await rejectsWith(
      setUserRole.run({ data: { uid: 'ana', role: 'instructor' }, auth: { uid: 'admin-uid', token: { email: ADMIN_EMAIL } } }),
      'permission-denied',
    );
    assert.equal((await adminDb.doc('users/ana').get()).data().role, 'student');
    assert.equal((await adminDb.doc('professional_requests/ana').get()).data().status, 'pending');
  });

  test('V3. e-mail verificado: regras e Functions de admin funcionam', async () => {
    const a = adminDbClient(true);
    await assertSucceeds(getDoc(doc(a, 'users/ana')));
    await assertSucceeds(setDoc(doc(a, 'exercises/novo'), { name: 'X' }));
    await assertSucceeds(getDoc(doc(a, 'professional_requests/ana')));
    const stats = await adminCall(getAdminStats, {}, true);
    assert.equal(stats.totalUsers, 1);
    await adminCall(reviewProfessionalRequest, { uid: 'ana', decision: 'approve' }, true);
    assert.equal((await adminDb.doc('users/ana').get()).data().role, 'instructor');
    await adminCall(setUserRole, { uid: 'ana', role: 'student' }, true);
    assert.equal((await adminDb.doc('users/ana').get()).data().role, 'student');
  });

  test('V4. outro usuário verificado com outro e-mail não é admin', async () => {
    const other = db('intruso', { email: 'intruso@x.test', verified: true });
    await assertFails(setDoc(doc(other, 'exercises/novo'), { name: 'X' }));
  });
});

// ---------------------------------------------------------------------------
describe('Pedido de profissional só com e-mail verificado', () => {
  const requestFor = (uid) => ({
    uid,
    kind: 'instructor',
    registrationNumber: '123456-G',
    registrationRegion: 'SP',
    name: 'Bia',
    email: `${uid}@x.test`,
    status: 'pending',
    createdAt: serverTimestamp(),
  });

  beforeEach(async () => {
    await adminDb.doc('users/bia').set({ name: 'Bia', role: 'student' });
  });

  test('V5. e-mail NÃO verificado: pedido negado', async () => {
    await assertFails(setDoc(doc(db('bia', { verified: false }), 'professional_requests/bia'), requestFor('bia')));
  });

  test('V6. e-mail verificado: pedido permitido', async () => {
    await assertSucceeds(setDoc(doc(db('bia', { verified: true }), 'professional_requests/bia'), requestFor('bia')));
  });
});

// ---------------------------------------------------------------------------
describe('Agenda: instructorUid é sempre o do próprio instrutor', () => {
  const appointment = (instructorUid, extra = {}) => ({
    instructorUid,
    studentUid: 'aluno',
    studentName: 'Ana',
    title: 'Avaliação',
    start: 1730000000000,
    durationMinutes: 60,
    status: 'scheduled',
    notes: null,
    ...extra,
  });
  const agenda = (uid) => collection(db(uid), 'users/aluno/appointments');

  beforeEach(async () => {
    await adminDb.doc('users/prof').set({ name: 'Prof', role: 'instructor' });
    await adminDb.doc('users/outroProf').set({ name: 'Outro', role: 'instructor' });
    await adminDb.doc('users/aluno').set({ name: 'Ana', role: 'student', instructorId: 'prof' });
  });

  test('A1. fluxo normal: instrutor vinculado cria, cancela e vê na agenda consolidada', async () => {
    const ref = await assertSucceeds(addDoc(agenda('prof'), appointment('prof')));
    // cancelar como o app faz: regrava o documento inteiro com status novo
    await assertSucceeds(setDoc(doc(db('prof'), ref.path), appointment('prof', { status: 'canceled' })));
    const mine = await assertSucceeds(
      getDocs(query(collectionGroup(db('prof'), 'appointments'), where('instructorUid', '==', 'prof'))),
    );
    assert.equal(mine.size, 1);
    // o aluno lê a própria agenda
    await assertSucceeds(getDocs(collection(db('aluno'), 'users/aluno/appointments')));
  });

  test('A2. instrutor NÃO cria compromisso em nome de outra pessoa', async () => {
    await assertFails(addDoc(agenda('prof'), appointment('outroProf')));
    await assertFails(addDoc(agenda('prof'), appointment('aluno')));
    const missing = appointment('prof');
    delete missing.instructorUid;
    await assertFails(addDoc(agenda('prof'), missing));
  });

  test('A3. instrutor NÃO troca o instructorUid num update', async () => {
    const ref = await assertSucceeds(addDoc(agenda('prof'), appointment('prof')));
    const asProf = doc(db('prof'), ref.path);
    await assertFails(updateDoc(asProf, { instructorUid: 'outroProf' }));
    await assertFails(setDoc(asProf, appointment('outroProf')));
    await assertSucceeds(updateDoc(asProf, { title: 'Reavaliação' }));
  });

  test('A4. não reescreve compromisso que não é dele (ex: de instrutor anterior)', async () => {
    await adminDb.doc('users/aluno/appointments/antigo').set({
      formerInstructorUid: 'outroProf',
      studentUid: 'aluno',
      title: 'Antigo',
      start: 1,
    });
    await adminDb.doc('users/aluno/appointments/deOutro').set(appointment('outroProf'));
    await assertFails(setDoc(doc(db('prof'), 'users/aluno/appointments/antigo'), appointment('prof')));
    await assertFails(updateDoc(doc(db('prof'), 'users/aluno/appointments/deOutro'), { title: 'x' }));
  });

  test('A5. não vinculado e aluno continuam sem gravar', async () => {
    await assertFails(addDoc(agenda('outroProf'), appointment('outroProf')));
    await assertFails(addDoc(collection(db('aluno'), 'users/aluno/appointments'), appointment('aluno')));
  });
});
