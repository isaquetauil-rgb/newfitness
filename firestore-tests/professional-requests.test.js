// Aprovação de profissionais — testes COMPORTAMENTAIS com as regras reais
// e as Cloud Functions reais (`reviewProfessionalRequest`, `applyUserRole`,
// `setUserRole`, `ensureInviteCode`, `linkToProfessional`), no mesmo
// projeto do emulador. Nunca toca produção; dados fictícios.
//
// Cobre: o cliente só cria perfil de ALUNO; ninguém apaga perfil (fecha a
// autopromoção por apagar-e-recriar); pedido `professional_requests/{uid}`
// validado (name/email não forjáveis, CREF/CRN, região, horário do
// servidor); só a Function (admin) decide; aprovação grava papel e status
// juntos; recusa exige motivo; histórico; idempotência.
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

const { reviewProfessionalRequest, applyUserRole, setUserRole } = require('../functions/lib/admin.js');
const { ensureInviteCode, linkToProfessional } = require('../functions/lib/linking.js');

const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
  deleteDoc,
  collection,
  query,
  where,
  orderBy,
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

const emailOf = (uid) => (uid === 'admin-uid' ? ADMIN_EMAIL : `${uid}@x.test`);
// Uma instância por usuário por teste (várias para o mesmo uid dão erro).
function db(uid) {
  if (!dbs.has(uid)) {
    dbs.set(uid, testEnv.authenticatedContext(uid, { email: emailOf(uid) }).firestore());
  }
  return dbs.get(uid);
}
const reqDoc = (uid, owner = uid) => doc(db(uid), `professional_requests/${owner}`);

const callAs = (fn, uid, data = {}) =>
  fn.run({ data, auth: { uid, token: { email: emailOf(uid) } } });
const asAdmin = (fn, data) => callAs(fn, 'admin-uid', data);

async function rejectsWith(promise, code) {
  await assert.rejects(promise, (err) => {
    assert.equal(err.code, code, `esperado "${code}", veio "${err.code}" (${err.message})`);
    return true;
  });
}

const profile = async (uid) => (await adminDb.doc(`users/${uid}`).get()).data();
const requestData = async (uid) => (await adminDb.doc(`professional_requests/${uid}`).get()).data();
const historyOf = async (uid) =>
  (await adminDb.collection(`professional_requests/${uid}/history`).get()).docs.map((d) => d.data());

/** Perfil de aluno criado pelo próprio cliente (como o app faz). */
async function signUpStudent(uid, name = `Nome ${uid}`) {
  await assertSucceeds(
    setDoc(doc(db(uid), `users/${uid}`), {
      name,
      email: emailOf(uid),
      role: 'student',
      instructorId: null,
      nutritionistId: null,
      inviteCode: null,
    }),
  );
}

/** Dados de um pedido válido, como o app grava. */
function validRequest(uid, overrides = {}) {
  return {
    uid,
    kind: 'instructor',
    registrationNumber: '123456-G',
    registrationRegion: 'SP',
    name: `Nome ${uid}`,
    email: emailOf(uid),
    status: 'pending',
    createdAt: serverTimestamp(),
    ...overrides,
  };
}

async function requestAs(uid, overrides = {}) {
  await assertSucceeds(setDoc(reqDoc(uid), validRequest(uid, overrides)));
}

// ---------------------------------------------------------------------------
describe('Perfil: só nasce aluno e ninguém apaga', () => {
  test('P1. cliente NÃO cria perfil como instructor nem nutritionist; como aluno, sim', async () => {
    const base = { name: 'X', instructorId: null, nutritionistId: null, inviteCode: null };
    await assertFails(setDoc(doc(db('ana'), 'users/ana'), { ...base, role: 'instructor' }));
    await assertFails(setDoc(doc(db('ana'), 'users/ana'), { ...base, role: 'nutritionist' }));
    await assertFails(setDoc(doc(db('ana'), 'users/ana'), { ...base, role: 'admin' }));
    await assertSucceeds(setDoc(doc(db('ana'), 'users/ana'), { ...base, role: 'student' }));
    // sem o campo role também é aluno (perfil padrão)
    await assertSucceeds(setDoc(doc(db('bia'), 'users/bia'), { name: 'Bia' }));
  });

  test('P2. nem o admin cria perfil pelo cliente (nem de outra pessoa, nem como profissional)', async () => {
    await assertFails(setDoc(doc(db('admin-uid'), 'users/outro'), { name: 'X', role: 'student' }));
    await assertFails(setDoc(doc(db('admin-uid'), 'users/admin-uid'), { name: 'A', role: 'instructor' }));
  });

  test('P3. ninguém apaga perfil (dono nem admin) — apagar-e-recriar não promove', async () => {
    await signUpStudent('ana');
    await assertFails(deleteDoc(doc(db('ana'), 'users/ana')));
    await assertFails(deleteDoc(doc(db('admin-uid'), 'users/ana')));
    // e, mesmo que o documento sumisse, recriar como instrutor é negado (P1)
    await adminDb.doc('users/ana').delete();
    await assertFails(setDoc(doc(db('ana'), 'users/ana'), { name: 'Ana', role: 'instructor' }));
    await assertSucceeds(setDoc(doc(db('ana'), 'users/ana'), { name: 'Ana', role: 'student' }));
  });
});

// ---------------------------------------------------------------------------
describe('Pedido: criação validada pelas regras', () => {
  beforeEach(async () => {
    await signUpStudent('ana');
  });

  test('Q1. aluno cria pedido válido de personal (CREF/UF) e de nutricionista (CRN/região)', async () => {
    await requestAs('ana');
    const saved = await requestData('ana');
    assert.equal(saved.status, 'pending');
    assert.ok(saved.createdAt.toDate() instanceof Date);

    await signUpStudent('bia');
    await requestAs('bia', { kind: 'nutritionist', registrationNumber: 'CRN-3 12345', registrationRegion: '3' });
  });

  test('Q2. name e email NÃO podem ser forjados', async () => {
    await assertFails(setDoc(reqDoc('ana'), validRequest('ana', { name: 'Outro Nome' })));
    await assertFails(setDoc(reqDoc('ana'), validRequest('ana', { email: 'falso@x.test' })));
  });

  test('Q3. registro inválido é negado (tamanho, pontas com espaço, caracteres)', async () => {
    for (const bad of ['123', 'A'.repeat(31), ' 123456', '123456 ', '1234#5', '12\n34']) {
      await assertFails(setDoc(reqDoc('ana'), validRequest('ana', { registrationNumber: bad })));
    }
    // limites válidos: 4 e 30 caracteres, com espaço/ponto/barra/hífen no meio
    await requestAs('ana', { registrationNumber: 'A1.2' });
    await adminDb.doc('professional_requests/ana').delete();
    await requestAs('ana', { registrationNumber: 'CREF 123.456-G/SP' + 'x'.repeat(13) });
  });

  test('Q4. região inválida é negada (UF para CREF, 1 a 11 para CRN)', async () => {
    const cases = [
      { kind: 'instructor', registrationRegion: 'XX' },
      { kind: 'instructor', registrationRegion: 'sp' },
      { kind: 'instructor', registrationRegion: '3' },
      { kind: 'nutritionist', registrationRegion: '12' },
      { kind: 'nutritionist', registrationRegion: '0' },
      { kind: 'nutritionist', registrationRegion: 'SP' },
      { kind: 'nutritionist', registrationRegion: 3 },
    ];
    for (const c of cases) {
      await assertFails(setDoc(reqDoc('ana'), validRequest('ana', c)));
    }
  });

  test('Q5. status, tipo, campos e horário são controlados', async () => {
    await assertFails(setDoc(reqDoc('ana'), validRequest('ana', { status: 'approved' })));
    await assertFails(setDoc(reqDoc('ana'), validRequest('ana', { kind: 'admin' })));
    await assertFails(setDoc(reqDoc('ana'), validRequest('ana', { reviewedBy: 'ana' })));
    await assertFails(setDoc(reqDoc('ana'), validRequest('ana', { createdAt: new Date() })));
    const missing = validRequest('ana');
    delete missing.registrationRegion;
    await assertFails(setDoc(reqDoc('ana'), missing));
    await assertFails(setDoc(reqDoc('ana'), validRequest('ana', { uid: 'outro' })));
  });

  test('Q6. ninguém cria pedido em nome de outra pessoa', async () => {
    await signUpStudent('bia');
    await assertFails(setDoc(reqDoc('bia', 'ana'), validRequest('ana')));
  });

  test('Q7. quem já é profissional não cria pedido', async () => {
    await adminDb.doc('users/ana').update({ role: 'instructor' });
    await assertFails(setDoc(reqDoc('ana'), validRequest('ana')));
  });
});

// ---------------------------------------------------------------------------
describe('Pedido: leitura, status e exclusão', () => {
  beforeEach(async () => {
    await signUpStudent('ana');
    await signUpStudent('bia');
    await requestAs('ana');
  });

  test('S1. aluno NÃO altera o status (nem aprova o próprio pedido) nem outros campos', async () => {
    await assertFails(updateDoc(reqDoc('ana'), { status: 'approved' }));
    await assertFails(updateDoc(reqDoc('ana'), { registrationNumber: '999999-G' }));
    await assertFails(setDoc(reqDoc('ana'), validRequest('ana')));
    assert.equal((await requestData('ana')).status, 'pending');
    assert.equal((await profile('ana')).role, 'student');
  });

  test('S2. leitura só do dono e do admin; admin lista os pendentes', async () => {
    await assertSucceeds(getDoc(reqDoc('ana')));
    await assertFails(getDoc(reqDoc('bia', 'ana')));
    await assertFails(getDocs(collection(db('bia'), 'professional_requests')));
    await assertSucceeds(getDoc(reqDoc('admin-uid', 'ana')));
    const pending = await assertSucceeds(
      getDocs(
        query(
          collection(db('admin-uid'), 'professional_requests'),
          where('status', '==', 'pending'),
          orderBy('createdAt'),
        ),
      ),
    );
    assert.deepEqual(pending.docs.map((d) => d.id), ['ana']);
  });

  test('S3. dono cancela enquanto pendente; outra pessoa não', async () => {
    await assertFails(deleteDoc(reqDoc('bia', 'ana')));
    await assertSucceeds(deleteDoc(reqDoc('ana')));
  });

  test('S4. histórico: dono e admin leem; ninguém grava pelo cliente', async () => {
    await asAdmin(reviewProfessionalRequest, { uid: 'ana', decision: 'reject', reason: 'CREF não encontrado' });
    const hist = collection(db('ana'), 'professional_requests/ana/history');
    await assertSucceeds(getDocs(hist));
    await assertSucceeds(getDocs(collection(db('admin-uid'), 'professional_requests/ana/history')));
    await assertFails(getDocs(collection(db('bia'), 'professional_requests/ana/history')));
    await assertFails(setDoc(doc(db('ana'), 'professional_requests/ana/history/x'), { status: 'approved' }));
  });
});

// ---------------------------------------------------------------------------
describe('reviewProfessionalRequest (Function do admin)', () => {
  beforeEach(async () => {
    await signUpStudent('ana');
    await requestAs('ana');
  });

  test('F1. não-admin e anônimo não chamam; aluno não aprova o próprio pedido', async () => {
    await rejectsWith(callAs(reviewProfessionalRequest, 'ana', { uid: 'ana', decision: 'approve' }), 'permission-denied');
    await adminDb.doc('users/prof').set({ role: 'instructor' });
    await rejectsWith(callAs(reviewProfessionalRequest, 'prof', { uid: 'ana', decision: 'approve' }), 'permission-denied');
    await rejectsWith(
      reviewProfessionalRequest.run({ data: { uid: 'ana', decision: 'approve' }, auth: undefined }),
      'unauthenticated',
    );
    assert.equal((await profile('ana')).role, 'student');
    assert.equal((await requestData('ana')).status, 'pending');
  });

  test('F2. argumentos inválidos e recusa sem motivo são negados', async () => {
    await rejectsWith(asAdmin(reviewProfessionalRequest, { uid: 'ana', decision: 'aprovar' }), 'invalid-argument');
    await rejectsWith(asAdmin(reviewProfessionalRequest, { decision: 'approve' }), 'invalid-argument');
    await rejectsWith(asAdmin(reviewProfessionalRequest, { uid: 'ana', decision: 'reject' }), 'invalid-argument');
    await rejectsWith(
      asAdmin(reviewProfessionalRequest, { uid: 'ana', decision: 'reject', reason: '   ' }),
      'invalid-argument',
    );
    await rejectsWith(
      asAdmin(reviewProfessionalRequest, { uid: 'ana', decision: 'reject', reason: 'x'.repeat(501) }),
      'invalid-argument',
    );
    await rejectsWith(asAdmin(reviewProfessionalRequest, { uid: 'naoexiste', decision: 'approve' }), 'not-found');
    assert.equal((await requestData('ana')).status, 'pending');
  });

  test('F3. enquanto pendente: sem código de convite nem vínculo', async () => {
    await rejectsWith(callAs(ensureInviteCode, 'ana'), 'permission-denied');
    assert.equal((await profile('ana')).inviteCode, null);
  });

  test('F4. aprovar grava papel E status juntos; depois o código e o vínculo funcionam', async () => {
    const r = await asAdmin(reviewProfessionalRequest, { uid: 'ana', decision: 'approve' });
    assert.equal(r.status, 'approved');

    assert.equal((await profile('ana')).role, 'instructor');
    const saved = await requestData('ana');
    assert.equal(saved.status, 'approved');
    assert.equal(saved.reviewedBy, 'admin-uid');
    assert.ok(saved.reviewedAt);
    const hist = await historyOf('ana');
    assert.equal(hist.length, 1);
    assert.equal(hist[0].status, 'approved');
    assert.equal(hist[0].registrationNumber, '123456-G');

    const { code } = await callAs(ensureInviteCode, 'ana');
    await signUpStudent('aluno');
    await callAs(linkToProfessional, 'aluno', { code, kind: 'instructor' });
    assert.equal((await profile('aluno')).instructorId, 'ana');
  });

  test('F5. recusar exige motivo, não muda o papel, grava histórico e permite pedir de novo', async () => {
    await asAdmin(reviewProfessionalRequest, { uid: 'ana', decision: 'reject', reason: '  CREF inválido  ' });
    assert.equal((await profile('ana')).role, 'student');
    const saved = await requestData('ana');
    assert.equal(saved.status, 'rejected');
    assert.equal(saved.rejectionReason, 'CREF inválido');
    // o aluno vê o motivo
    const own = await assertSucceeds(getDoc(reqDoc('ana')));
    assert.equal(own.data().rejectionReason, 'CREF inválido');
    assert.equal((await historyOf('ana'))[0].status, 'rejected');

    // pedir de novo na hora: apaga o recusado e cria outro
    await assertSucceeds(deleteDoc(reqDoc('ana')));
    await requestAs('ana', { registrationNumber: '654321-G' });
    assert.equal((await requestData('ana')).status, 'pending');
    assert.equal((await historyOf('ana')).length, 1); // histórico preservado
  });

  test('F6. idempotência: mesma decisão = ok; decisão contrária = failed-precondition', async () => {
    await asAdmin(reviewProfessionalRequest, { uid: 'ana', decision: 'approve' });
    const again = await asAdmin(reviewProfessionalRequest, { uid: 'ana', decision: 'approve' });
    assert.equal(again.unchanged, true);
    assert.equal((await historyOf('ana')).length, 1);
    await rejectsWith(
      asAdmin(reviewProfessionalRequest, { uid: 'ana', decision: 'reject', reason: 'x' }),
      'failed-precondition',
    );

    await signUpStudent('bia');
    await requestAs('bia');
    await asAdmin(reviewProfessionalRequest, { uid: 'bia', decision: 'reject', reason: 'x' });
    const againReject = await asAdmin(reviewProfessionalRequest, { uid: 'bia', decision: 'reject', reason: 'y' });
    assert.equal(againReject.unchanged, true);
    await rejectsWith(asAdmin(reviewProfessionalRequest, { uid: 'bia', decision: 'approve' }), 'failed-precondition');
    assert.equal((await profile('bia')).role, 'student');
  });

  test('F7. papel já igual ao pedido (promovido pelo painel): só marca aprovado', async () => {
    await asAdmin(setUserRole, { uid: 'ana', role: 'instructor' });
    await asAdmin(reviewProfessionalRequest, { uid: 'ana', decision: 'approve' });
    assert.equal((await profile('ana')).role, 'instructor');
    assert.equal((await requestData('ana')).status, 'approved');
  });

  test('F8. já é OUTRO tipo de profissional: recusa, e nada muda (tudo ou nada)', async () => {
    await asAdmin(setUserRole, { uid: 'ana', role: 'nutritionist' });
    await rejectsWith(asAdmin(reviewProfessionalRequest, { uid: 'ana', decision: 'approve' }), 'failed-precondition');
    assert.equal((await profile('ana')).role, 'nutritionist');
    assert.equal((await requestData('ana')).status, 'pending');
    assert.equal((await historyOf('ana')).length, 0);
  });

  test('F9. atomicidade: se a etapa final falha, nem papel nem pedido mudam', async () => {
    await rejectsWith(
      applyUserRole(adminDb, 'ana', 'instructor', {
        allowRevocation: false,
        finalize: async (tx) => {
          tx.update(adminDb.doc('professional_requests/ana'), { status: 'approved' });
          const failure = new Error('falha simulada depois de gravar o pedido');
          failure.code = 'aborted';
          throw failure;
        },
      }),
      'aborted',
    );
    assert.equal((await profile('ana')).role, 'student');
    assert.equal((await requestData('ana')).status, 'pending');
  });

  test('F10. aprovação nunca rebaixa instrutor (sem revogação por esse caminho)', async () => {
    await adminDb.doc('users/prof').set({ role: 'instructor' });
    await rejectsWith(applyUserRole(adminDb, 'prof', 'student', { allowRevocation: false }), 'failed-precondition');
    assert.equal((await profile('prof')).role, 'instructor');
  });

  test('F11. ex-profissional (rebaixado) pede de novo pelo fluxo normal', async () => {
    await asAdmin(reviewProfessionalRequest, { uid: 'ana', decision: 'approve' });
    // enquanto profissional, não apaga o pedido aprovado
    await assertFails(deleteDoc(reqDoc('ana')));
    await asAdmin(setUserRole, { uid: 'ana', role: 'student' });
    await assertSucceeds(deleteDoc(reqDoc('ana')));
    await requestAs('ana', { kind: 'nutritionist', registrationRegion: '3' });
    await asAdmin(reviewProfessionalRequest, { uid: 'ana', decision: 'approve' });
    assert.equal((await profile('ana')).role, 'nutritionist');
    assert.equal((await historyOf('ana')).length, 2);
  });
});
