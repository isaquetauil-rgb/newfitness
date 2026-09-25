// Testes COMPORTAMENTAIS de segurança do código de convite e da integridade
// dos vínculos aluno ↔ profissional. Combina, NO MESMO projeto do emulador:
//  - as Cloud Functions reais (`ensureInviteCode`, `linkToProfessional`,
//    chamadas via `.run()`, Admin SDK apontado para o Firestore Emulator);
//  - as Security Rules reais (`@firebase/rules-unit-testing`), para provar o
//    que um cliente consegue ou não fazer depois de cada passo.
// Nunca toca produção (projectId "demo-..."); dados 100% fictícios.
//
// Pré-requisito: `npm run build` em functions/.
'use strict';

const { test, before, after, beforeEach, describe } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const PROJECT_ID = 'demo-newfitness-links-test';
process.env.GCLOUD_PROJECT = PROJECT_ID;
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';

// Mesma cópia do firebase-admin que `functions/lib/linking.js` usa (ver
// comentário em linking-function.test.js).
const admin = require('../functions/node_modules/firebase-admin');
admin.initializeApp({ projectId: PROJECT_ID });
const adminDb = admin.firestore();

let ensureInviteCode;
let linkToProfessional;
try {
  ({ ensureInviteCode, linkToProfessional } = require('../functions/lib/linking.js'));
} catch (e) {
  throw new Error('functions/lib/linking.js não encontrado — rode "npm run build" em functions/.');
}

const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
  collection,
  query,
  where,
} = require('firebase/firestore');

let testEnv;

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
  await testEnv.clearFirestore();
});

const client = (uid) => testEnv.authenticatedContext(uid, { email: `${uid}@x.test` }).firestore();

const call = (fn, uid, data = {}) => fn.run({ data, auth: { uid, token: {} } });

async function rejectsWith(promise, code) {
  await assert.rejects(promise, (err) => {
    assert.equal(err.code, code, `esperado "${code}", veio "${err.code}" (${err.message})`);
    return true;
  });
}

/**
 * Cria o perfil. Aluno: pelo CLIENTE (como o app faz no cadastro).
 * Profissional: pelo Admin SDK — desde o fluxo de aprovação, o cliente só
 * cria perfil de aluno; personal/nutricionista passam a existir por pedido
 * aprovado ou promoção administrativa (ver professional-requests.test.js).
 */
async function signUpAs(uid, role, name = uid) {
  const profile = {
    name,
    email: `${uid}@x.test`,
    role,
    instructorId: null,
    nutritionistId: null,
    inviteCode: null,
  };
  if (role === 'student') {
    await assertSucceeds(setDoc(doc(client(uid), `users/${uid}`), profile));
  } else {
    await adminDb.doc(`users/${uid}`).set(profile);
  }
}

async function issueCode(uid) {
  const { code } = await call(ensureInviteCode, uid);
  return code;
}

describe('inviteCode — só o backend define', () => {
  test('I1. cliente NÃO consegue criar o perfil já com um inviteCode escolhido', async () => {
    await assertFails(
      setDoc(doc(client('evil'), 'users/evil'), {
        name: 'Evil',
        role: 'instructor',
        instructorId: null,
        nutritionistId: null,
        inviteCode: 'ESCOLHI1',
      }),
    );
  });

  test('I2. cliente NÃO consegue alterar/definir o próprio inviteCode depois', async () => {
    await signUpAs('prof', 'instructor');
    const code = await issueCode('prof');
    await assertFails(updateDoc(doc(client('prof'), 'users/prof'), { inviteCode: 'OUTRO123' }));
    await assertFails(updateDoc(doc(client('prof'), 'users/prof'), { inviteCode: null }));
    // Campos editáveis continuam funcionando.
    await assertSucceeds(updateDoc(doc(client('prof'), 'users/prof'), { name: 'Prof. Novo' }));
    assert.equal((await adminDb.doc('users/prof').get()).data().inviteCode, code);
  });

  test('I3. instrutor recebe um código válido (8 caracteres do alfabeto seguro) e idempotente', async () => {
    await signUpAs('prof', 'instructor');
    const code = await issueCode('prof');
    assert.match(code, /^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$/);
    assert.equal(await issueCode('prof'), code, 'segunda chamada devolve o mesmo código');
    assert.equal((await adminDb.doc('users/prof').get()).data().inviteCode, code);
    const reservation = await adminDb.doc(`invite_codes/${code}`).get();
    assert.equal(reservation.data().uid, 'prof');
  });

  test('I4. nutricionista também recebe código; aluno não', async () => {
    await signUpAs('nutri', 'nutritionist');
    assert.match(await issueCode('nutri'), /^[A-Z2-9]{8}$/);
    await signUpAs('aluno', 'student');
    await rejectsWith(call(ensureInviteCode, 'aluno'), 'permission-denied');
  });

  test('I5. vários instrutores nunca recebem o mesmo código', async () => {
    const uids = Array.from({ length: 25 }, (_, i) => `prof${i}`);
    for (const uid of uids) await signUpAs(uid, 'instructor');
    const codes = await Promise.all(uids.map(issueCode));
    assert.equal(new Set(codes).size, uids.length);
  });

  test('I6. reservas (invite_codes) são inacessíveis ao cliente', async () => {
    await signUpAs('prof', 'instructor');
    const code = await issueCode('prof');
    await assertFails(getDoc(doc(client('prof'), `invite_codes/${code}`)));
    await assertFails(setDoc(doc(client('evil'), 'invite_codes/QUALQUER'), { uid: 'evil' }));
  });

  test('I7. quem conhece o código de outro instrutor NÃO altera nem assume a conta dele', async () => {
    await signUpAs('profA', 'instructor', 'Prof. A');
    const codeA = await issueCode('profA');
    await signUpAs('evil', 'instructor', 'Evil');
    await issueCode('evil');

    // Não copia o código para si...
    await assertFails(updateDoc(doc(client('evil'), 'users/evil'), { inviteCode: codeA }));
    // ...não mexe no perfil de A, nem lê a lista/perfil dele.
    await assertFails(updateDoc(doc(client('evil'), 'users/profA'), { name: 'hack' }));
    await assertFails(getDoc(doc(client('evil'), 'users/profA')));
    await assertFails(getDocs(collection(client('evil'), 'users/profA/students')));
    // E um aluno que usa o código de A continua indo para A.
    await signUpAs('aluno', 'student');
    await call(linkToProfessional, 'aluno', { code: codeA, kind: 'instructor' });
    assert.equal((await adminDb.doc('users/aluno').get()).data().instructorId, 'profA');
  });

  test('I8. código antigo duplicado (copiado antes desta correção) NÃO vincula ninguém', async () => {
    // Situação legada gravada direto (como era possível antes das regras novas).
    await adminDb.doc('users/profA').set({ name: 'A', role: 'instructor', inviteCode: 'LEGADO1' });
    await adminDb.doc('users/evil').set({ name: 'E', role: 'instructor', inviteCode: 'LEGADO1' });
    await signUpAs('aluno', 'student');
    await rejectsWith(
      call(linkToProfessional, 'aluno', { code: 'LEGADO1', kind: 'instructor' }),
      'invalid-argument',
    );
    // O dono legítimo recebe um código novo (o antigo não era exclusivo).
    const fresh = await issueCode('profA');
    assert.notEqual(fresh, 'LEGADO1');
  });

  test('I9. código antigo exclusivo continua valendo e é reservado para o dono', async () => {
    await adminDb.doc('users/profA').set({ name: 'A', role: 'instructor', inviteCode: 'ANTIGO22' });
    assert.equal(await issueCode('profA'), 'ANTIGO22');
    assert.equal((await adminDb.doc('invite_codes/ANTIGO22').get()).data().uid, 'profA');
  });

  test('I10. instrutor rebaixado a aluno deixa de receber vínculos pelo código', async () => {
    await signUpAs('profA', 'instructor');
    const code = await issueCode('profA');
    await adminDb.doc('users/profA').update({ role: 'student' });
    await signUpAs('aluno', 'student');
    await rejectsWith(call(linkToProfessional, 'aluno', { code, kind: 'instructor' }), 'invalid-argument');
  });
});

describe('troca de instrutor — vínculo sempre o atual', () => {
  const studentsOf = (uid) =>
    getDocs(query(collection(client(uid), 'users'), where('instructorId', '==', uid)));

  async function scenario() {
    await signUpAs('profA', 'instructor', 'Prof. A');
    await signUpAs('profB', 'instructor', 'Prof. B');
    await signUpAs('aluno', 'student', 'Ana');
    const codeA = await issueCode('profA');
    const codeB = await issueCode('profB');
    await call(linkToProfessional, 'aluno', { code: codeA, kind: 'instructor' });
    // Histórico do aluno criado pelo próprio aluno enquanto vinculado a A.
    await assertSucceeds(setDoc(doc(client('aluno'), 'users/aluno/workouts/w1'), { userId: 'aluno', name: 'Treino A' }));
    await assertSucceeds(
      setDoc(doc(client('aluno'), 'users/aluno/physical_assessments/av1'), {
        userId: 'aluno',
        date: 1720000000000,
        weightKg: 80,
        recordedBy: 'self',
        createdByUid: 'aluno',
      }),
    );
    // Avaliação lançada por A e nota privada de A sobre o aluno.
    await assertSucceeds(
      setDoc(doc(client('profA'), 'users/aluno/physical_assessments/avA'), {
        userId: 'aluno',
        date: 1720000000000,
        weightKg: 79,
        recordedBy: 'instructor',
        createdByUid: 'profA',
      }),
    );
    await assertSucceeds(setDoc(doc(client('profA'), 'users/profA/students/aluno'), { notes: 'joelho' }, { merge: true }));
    return { codeA, codeB };
  }

  test('L1. aluno vinculado a A aparece para A (consulta pelo vínculo atual)', async () => {
    await scenario();
    const snap = await assertSucceeds(studentsOf('profA'));
    assert.deepEqual(snap.docs.map((d) => d.id), ['aluno']);
  });

  test('L2–L4. aluno troca para B: some da lista de A e aparece na de B', async () => {
    const { codeB } = await scenario();
    await call(linkToProfessional, 'aluno', { code: codeB, kind: 'instructor' });

    const forA = await assertSucceeds(studentsOf('profA'));
    assert.equal(forA.size, 0);
    const forB = await assertSucceeds(studentsOf('profB'));
    assert.deepEqual(forB.docs.map((d) => d.id), ['aluno']);
  });

  test('L5. depois da troca, A não acessa mais nenhum dado do aluno', async () => {
    const { codeB } = await scenario();
    await call(linkToProfessional, 'aluno', { code: codeB, kind: 'instructor' });

    const a = client('profA');
    await assertFails(getDoc(doc(a, 'users/aluno')));
    await assertFails(getDoc(doc(a, 'users/aluno/workouts/w1')));
    await assertFails(getDoc(doc(a, 'users/aluno/physical_assessments/av1')));
    // Nem a avaliação que ele mesmo lançou.
    await assertFails(getDoc(doc(a, 'users/aluno/physical_assessments/avA')));
    await assertFails(
      setDoc(doc(a, 'users/aluno/training_plans/p1'), { studentUid: 'aluno', title: 'x', workouts: [] }),
    );
  });

  test('L6. B acessa só o que as regras permitem', async () => {
    const { codeB } = await scenario();
    await call(linkToProfessional, 'aluno', { code: codeB, kind: 'instructor' });

    const b = client('profB');
    await assertSucceeds(getDoc(doc(b, 'users/aluno')));
    await assertSucceeds(getDoc(doc(b, 'users/aluno/workouts/w1')));
    await assertSucceeds(getDoc(doc(b, 'users/aluno/physical_assessments/avA')));
    // Mas não edita o que não é dele, nem escreve treinos do aluno, nem
    // lê as notas privadas de A.
    await assertFails(updateDoc(doc(b, 'users/aluno/physical_assessments/avA'), { weightKg: 1 }));
    await assertFails(setDoc(doc(b, 'users/aluno/workouts/w2'), { userId: 'aluno' }));
    await assertFails(getDoc(doc(b, 'users/profA/students/aluno')));
    await assertFails(updateDoc(doc(b, 'users/aluno'), { instructorId: 'profB' }));
  });

  test('L7. histórico do aluno é preservado; notas de A não são apagadas (só marcadas inativas)', async () => {
    const { codeB } = await scenario();
    await call(linkToProfessional, 'aluno', { code: codeB, kind: 'instructor' });

    const aluno = client('aluno');
    await assertSucceeds(getDoc(doc(aluno, 'users/aluno/workouts/w1')));
    const avA = await assertSucceeds(getDoc(doc(aluno, 'users/aluno/physical_assessments/avA')));
    assert.equal(avA.data().createdByUid, 'profA');

    const oldEntry = (await adminDb.doc('users/profA/students/aluno').get()).data();
    assert.equal(oldEntry.notes, 'joelho');
    assert.equal(oldEntry.active, false);
    assert.equal(typeof oldEntry.unlinkedAt, 'number');
    const newEntry = (await adminDb.doc('users/profB/students/aluno').get()).data();
    assert.equal(newEntry.active, true);
  });

  test('L8. instrutor NÃO consegue listar alunos de outro instrutor pela consulta', async () => {
    await scenario();
    await assertFails(
      getDocs(query(collection(client('profB'), 'users'), where('instructorId', '==', 'profA'))),
    );
    await assertFails(getDocs(collection(client('profB'), 'users')));
  });
});
