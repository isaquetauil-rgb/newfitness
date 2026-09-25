// Testes COMPORTAMENTAIS da rodada de correção de inconsistências:
//  1. estatísticas do painel admin (Cloud Function `getAdminStats`);
//  2. troca e desvinculação de instrutor/nutricionista
//     (`linkToProfessional`/`unlinkFromProfessional`) e o efeito real nas
//     regras do Firestore e do Storage;
//  3. conversa de nutrição: ninguém forja `assistant`, cada um só escreve o
//     próprio papel, mensagens imutáveis.
// Functions reais (`.run()`, Admin SDK no emulador) + regras reais
// (`@firebase/rules-unit-testing`) no MESMO projeto. Nunca toca produção.
//
// Pré-requisito: `npm run build` em functions/.
'use strict';

const { test, before, after, beforeEach, describe } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

// Mesmo projeto do `firebase emulators:exec --project ...` do README: as
// regras do Storage consultam o Firestore (`firestore.get`) no projeto do
// emulador — com outro projectId essas consultas não achariam os dados
// deste teste. Os arquivos rodam em sequência e limpam tudo em beforeEach.
const PROJECT_ID = 'demo-newfitness-rules-test';
process.env.GCLOUD_PROJECT = PROJECT_ID;
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';

const admin = require('../functions/node_modules/firebase-admin');
admin.initializeApp({ projectId: PROJECT_ID });
const adminDb = admin.firestore();

const { ensureInviteCode, linkToProfessional, unlinkFromProfessional } = require('../functions/lib/linking.js');
const { getAdminStats } = require('../functions/lib/admin.js');
const { saveNutritionReply } = require('../functions/lib/nutrition.js');

const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  getDocs,
  setDoc,
  addDoc,
  updateDoc,
  deleteDoc,
  collection,
  collectionGroup,
  query,
  where,
} = require('firebase/firestore');

const ADMIN_EMAIL = 'isaquetrabalho005@gmail.com';
let testEnv;

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
  await testEnv.clearFirestore();
  await testEnv.clearStorage();
});

const ctx = (uid) => testEnv.authenticatedContext(uid, { email: `${uid}@x.test` });
const client = (uid) => ctx(uid).firestore();
const call = (fn, uid, data = {}, token = { email: `${uid}@x.test` }) =>
  fn.run({ data, auth: { uid, token } });

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

async function codeOf(uid) {
  return (await call(ensureInviteCode, uid)).code;
}

const linkedStudents = (profUid, field) =>
  getDocs(query(collection(client(profUid), 'users'), where(field, '==', profUid)));

// ---------------------------------------------------------------------------
describe('1. Estatísticas do painel admin', () => {
  beforeEach(async () => {
    await adminDb.doc('users/s1').set({ role: 'student' });
    await adminDb.doc('users/s2').set({ role: 'student' });
    await adminDb.doc('users/i1').set({ role: 'instructor' });
    await adminDb.doc('users/n1').set({ role: 'nutritionist' });
    await adminDb.doc('exercises/e1').set({ name: 'Supino' });
    await adminDb.doc('exercises/e2').set({ name: 'Remada' });
    await adminDb.doc('users/s1/workouts/w1').set({ userId: 's1' });
    await adminDb.doc('users/s1/workouts/w2').set({ userId: 's1' });
    await adminDb.doc('users/s2/workouts/w3').set({ userId: 's2' });
    await adminDb.doc('users/s1/finance/subscription').set({ status: 'authorized' });
    await adminDb.doc('users/s2/finance/subscription').set({ status: 'pending' });
  });

  test('A1. admin obtém as estatísticas com os números corretos', async () => {
    const stats = await call(getAdminStats, 'admin-uid', {}, { email: ADMIN_EMAIL });
    assert.deepEqual(stats, {
      totalUsers: 4,
      totalStudents: 2,
      totalInstructors: 1,
      totalNutritionists: 1,
      totalExercises: 2,
      totalWorkoutsLogged: 3,
      activeSubscriptions: 1,
    });
  });

  test('A2. aluno, instrutor e nutricionista NÃO obtêm as estatísticas', async () => {
    await rejectsWith(call(getAdminStats, 's1'), 'permission-denied');
    await rejectsWith(call(getAdminStats, 'i1'), 'permission-denied');
    await rejectsWith(call(getAdminStats, 'n1'), 'permission-denied');
    await rejectsWith(getAdminStats.run({ data: {}, auth: undefined }), 'unauthenticated');
  });

  test('A3. as regras continuam fechadas para consultas de todos os treinos/assinaturas', async () => {
    const adminClient = testEnv.authenticatedContext('admin-uid', { email: ADMIN_EMAIL }).firestore();
    await assertFails(getDocs(collectionGroup(adminClient, 'workouts')));
    await assertFails(getDocs(collectionGroup(client('i1'), 'workouts')));
    await assertFails(getDocs(collectionGroup(client('s1'), 'finance')));
  });
});

// ---------------------------------------------------------------------------
describe('2a. Troca e desvinculação de INSTRUTOR', () => {
  async function scenario() {
    await signUpAs('prof1', 'instructor', 'Prof. 1');
    await signUpAs('prof2', 'instructor', 'Prof. 2');
    await signUpAs('aluno', 'student', 'Ana');
    const code1 = await codeOf('prof1');
    const code2 = await codeOf('prof2');
    await call(linkToProfessional, 'aluno', { code: code1, kind: 'instructor' });
    // Histórico criado enquanto vinculado ao prof1.
    await assertSucceeds(setDoc(doc(client('aluno'), 'users/aluno/workouts/w1'), { userId: 'aluno' }));
    await assertSucceeds(
      setDoc(doc(client('prof1'), 'users/aluno/training_plans/p1'), {
        studentUid: 'aluno',
        instructorUid: 'prof1',
        title: 'Plano',
        workouts: [],
      }),
    );
    await assertSucceeds(
      setDoc(doc(client('prof1'), 'users/aluno/appointments/ag1'), {
        instructorUid: 'prof1',
        studentUid: 'aluno',
        title: 'Avaliação',
        start: 1720000000000,
      }),
    );
    await assertSucceeds(
      setDoc(doc(client('prof1'), 'users/aluno/physical_assessments/av1'), {
        userId: 'aluno',
        date: 1720000000000,
        weightKg: 80,
        recordedBy: 'instructor',
        createdByUid: 'prof1',
      }),
    );
    return { code1, code2 };
  }

  const agendaOf = (uid) =>
    getDocs(query(collectionGroup(client(uid), 'appointments'), where('instructorUid', '==', uid)));

  test('T1. troca 1 → 2: prof1 perde acesso (inclusive agenda), prof2 ganha', async () => {
    const { code2 } = await scenario();
    // Antes da troca: prof2 não vê nada.
    await assertFails(getDoc(doc(client('prof2'), 'users/aluno/workouts/w1')));

    await call(linkToProfessional, 'aluno', { code: code2, kind: 'instructor' });

    const p1 = client('prof1');
    await assertFails(getDoc(doc(p1, 'users/aluno')));
    await assertFails(getDoc(doc(p1, 'users/aluno/workouts/w1')));
    await assertFails(getDoc(doc(p1, 'users/aluno/training_plans/p1')));
    await assertFails(getDoc(doc(p1, 'users/aluno/physical_assessments/av1')));
    await assertFails(getDoc(doc(p1, 'users/aluno/appointments/ag1')));
    const agenda1 = await assertSucceeds(agendaOf('prof1'));
    assert.equal(agenda1.size, 0, 'agenda do prof1 não mostra mais o ex-aluno');
    assert.equal((await assertSucceeds(linkedStudents('prof1', 'instructorId'))).size, 0);

    const p2 = client('prof2');
    await assertSucceeds(getDoc(doc(p2, 'users/aluno')));
    await assertSucceeds(getDoc(doc(p2, 'users/aluno/workouts/w1')));
    await assertSucceeds(getDoc(doc(p2, 'users/aluno/training_plans/p1')));
    assert.deepEqual((await linkedStudents('prof2', 'instructorId')).docs.map((d) => d.id), ['aluno']);
  });

  test('T2. histórico preservado após a troca (e a lista antiga só fica inativa)', async () => {
    const { code2 } = await scenario();
    await call(linkToProfessional, 'aluno', { code: code2, kind: 'instructor' });

    const a = client('aluno');
    await assertSucceeds(getDoc(doc(a, 'users/aluno/workouts/w1')));
    await assertSucceeds(getDoc(doc(a, 'users/aluno/training_plans/p1')));
    const ag = await assertSucceeds(getDoc(doc(a, 'users/aluno/appointments/ag1')));
    assert.equal(ag.data().formerInstructorUid, 'prof1');
    assert.equal(ag.data().title, 'Avaliação');
    const av = await assertSucceeds(getDoc(doc(a, 'users/aluno/physical_assessments/av1')));
    assert.equal(av.data().createdByUid, 'prof1');
    const oldEntry = (await adminDb.doc('users/prof1/students/aluno').get()).data();
    assert.equal(oldEntry.active, false);
  });

  test('T3. desvincular: nenhum instrutor mantém acesso; histórico continua', async () => {
    await scenario();
    const result = await call(unlinkFromProfessional, 'aluno', { kind: 'instructor' });
    assert.equal(result.changed, true);

    assert.equal((await adminDb.doc('users/aluno').get()).data().instructorId, null);
    const p1 = client('prof1');
    await assertFails(getDoc(doc(p1, 'users/aluno')));
    await assertFails(getDoc(doc(p1, 'users/aluno/workouts/w1')));
    await assertFails(getDoc(doc(p1, 'users/aluno/appointments/ag1')));
    assert.equal((await agendaOf('prof1')).size, 0);
    assert.equal((await linkedStudents('prof1', 'instructorId')).size, 0);
    await assertFails(getDoc(doc(client('prof2'), 'users/aluno/workouts/w1')));

    await assertSucceeds(getDoc(doc(client('aluno'), 'users/aluno/workouts/w1')));
    await assertSucceeds(getDoc(doc(client('aluno'), 'users/aluno/training_plans/p1')));
  });

  test('T4. a entrada antiga em `students` não concede acesso por si só', async () => {
    await scenario();
    await call(unlinkFromProfessional, 'aluno', { kind: 'instructor' });
    // A entrada continua existindo (histórico do instrutor)...
    await assertSucceeds(getDoc(doc(client('prof1'), 'users/prof1/students/aluno')));
    // ...e mesmo reativada à mão por ele, não abre nada do aluno.
    await assertSucceeds(
      setDoc(doc(client('prof1'), 'users/prof1/students/aluno'), { active: true }, { merge: true }),
    );
    await assertFails(getDoc(doc(client('prof1'), 'users/aluno/workouts/w1')));
    await assertFails(getDoc(doc(client('prof1'), 'users/aluno')));
  });

  test('T5. o novo instrutor só ganha acesso depois de o vínculo ser confirmado', async () => {
    await signUpAs('prof2', 'instructor');
    await signUpAs('aluno', 'student');
    await codeOf('prof2');
    await assertSucceeds(setDoc(doc(client('aluno'), 'users/aluno/workouts/w1'), { userId: 'aluno' }));
    // Código errado: nada muda.
    await rejectsWith(call(linkToProfessional, 'aluno', { code: 'ERRADO99', kind: 'instructor' }), 'invalid-argument');
    await assertFails(getDoc(doc(client('prof2'), 'users/aluno/workouts/w1')));
  });

  test('T6. ninguém altera o vínculo de outra pessoa nem o próprio vínculo direto', async () => {
    await scenario();
    // O uid vem do token: um "uid" no pedido é ignorado.
    await signUpAs('intruso', 'student');
    await call(unlinkFromProfessional, 'intruso', { kind: 'instructor', uid: 'aluno' });
    assert.equal((await adminDb.doc('users/aluno').get()).data().instructorId, 'prof1');
    // Profissional não usa a função.
    await rejectsWith(call(unlinkFromProfessional, 'prof1', { kind: 'instructor' }), 'permission-denied');
    // Escrita direta do campo é negada pelas regras.
    await assertFails(updateDoc(doc(client('aluno'), 'users/aluno'), { instructorId: null }));
    await assertFails(updateDoc(doc(client('aluno'), 'users/aluno'), { instructorId: 'prof2' }));
    await assertFails(updateDoc(doc(client('prof1'), 'users/aluno'), { instructorId: null }));
    // Dados inválidos / sem login.
    await rejectsWith(call(unlinkFromProfessional, 'aluno', { kind: 'admin' }), 'invalid-argument');
    await rejectsWith(unlinkFromProfessional.run({ data: { kind: 'instructor' }, auth: undefined }), 'unauthenticated');
  });

  test('T7. desvincular sem vínculo não faz nada (idempotente)', async () => {
    await signUpAs('aluno', 'student');
    const r = await call(unlinkFromProfessional, 'aluno', { kind: 'instructor' });
    assert.equal(r.changed, false);
  });
});

// ---------------------------------------------------------------------------
describe('2b. Troca e desvinculação de NUTRICIONISTA', () => {
  async function scenario() {
    await signUpAs('nutri1', 'nutritionist', 'Nutri 1');
    await signUpAs('nutri2', 'nutritionist', 'Nutri 2');
    await signUpAs('aluno', 'student', 'Ana');
    const code1 = await codeOf('nutri1');
    const code2 = await codeOf('nutri2');
    await call(linkToProfessional, 'aluno', { code: code1, kind: 'nutritionist' });
    await assertSucceeds(
      setDoc(doc(client('nutri1'), 'users/aluno/nutrition_plans/np1'), {
        studentUid: 'aluno',
        nutritionistUid: 'nutri1',
        title: 'Plano',
        meals: [],
      }),
    );
    await assertSucceeds(
      addDoc(collection(client('aluno'), 'users/aluno/nutrition_chat'), {
        role: 'user',
        content: 'Posso comer ovo?',
        createdAt: 1,
      }),
    );
    await assertSucceeds(
      setDoc(doc(client('aluno'), 'users/aluno/meal_photos/m1'), { userId: 'aluno', imageUrl: 'x' }),
    );
    await testEnv.withSecurityRulesDisabled(async (c) => {
      await c.storage().ref('users/aluno/meal_photos/m1.jpg').put(new Uint8Array([1, 2, 3]), {
        contentType: 'image/jpeg',
      });
    });
    return { code1, code2 };
  }

  test('N1. troca 1 → 2: nutri1 perde acesso, nutri2 ganha', async () => {
    const { code2 } = await scenario();
    await assertSucceeds(getDocs(collection(client('nutri1'), 'users/aluno/nutrition_chat')));

    await call(linkToProfessional, 'aluno', { code: code2, kind: 'nutritionist' });

    const n1 = client('nutri1');
    await assertFails(getDocs(collection(n1, 'users/aluno/nutrition_chat')));
    await assertFails(getDoc(doc(n1, 'users/aluno/nutrition_plans/np1')));
    await assertFails(getDoc(doc(n1, 'users/aluno/meal_photos/m1')));
    await assertFails(ctx('nutri1').storage().ref('users/aluno/meal_photos/m1.jpg').getMetadata());
    assert.equal((await linkedStudents('nutri1', 'nutritionistId')).size, 0);

    const n2 = client('nutri2');
    await assertSucceeds(getDocs(collection(n2, 'users/aluno/nutrition_chat')));
    await assertSucceeds(getDoc(doc(n2, 'users/aluno/nutrition_plans/np1')));
    await assertSucceeds(ctx('nutri2').storage().ref('users/aluno/meal_photos/m1.jpg').getMetadata());
    assert.deepEqual((await linkedStudents('nutri2', 'nutritionistId')).docs.map((d) => d.id), ['aluno']);
    // Histórico preservado.
    assert.equal((await getDocs(collection(client('aluno'), 'users/aluno/nutrition_chat'))).size, 1);
    await assertSucceeds(getDoc(doc(client('aluno'), 'users/aluno/nutrition_plans/np1')));
    assert.equal((await adminDb.doc('users/nutri1/nutrition_students/aluno').get()).data().active, false);
  });

  test('N2. desvincular: nenhuma nutricionista mantém acesso; histórico continua', async () => {
    await scenario();
    await call(unlinkFromProfessional, 'aluno', { kind: 'nutritionist' });

    assert.equal((await adminDb.doc('users/aluno').get()).data().nutritionistId, null);
    await assertFails(getDocs(collection(client('nutri1'), 'users/aluno/nutrition_chat')));
    await assertFails(
      addDoc(collection(client('nutri1'), 'users/aluno/nutrition_chat'), {
        role: 'nutritionist',
        content: 'x',
        createdAt: 2,
      }),
    );
    await assertFails(ctx('nutri1').storage().ref('users/aluno/meal_photos/m1.jpg').getMetadata());
    await assertSucceeds(getDoc(doc(client('aluno'), 'users/aluno/nutrition_plans/np1')));
    assert.equal((await getDocs(collection(client('aluno'), 'users/aluno/nutrition_chat'))).size, 1);
  });

  test('N3. vínculo de instrutor e de nutricionista são independentes', async () => {
    await scenario();
    await signUpAs('prof1', 'instructor');
    await call(linkToProfessional, 'aluno', { code: await codeOf('prof1'), kind: 'instructor' });
    await call(unlinkFromProfessional, 'aluno', { kind: 'nutritionist' });
    const profile = (await adminDb.doc('users/aluno').get()).data();
    assert.equal(profile.instructorId, 'prof1');
    assert.equal(profile.nutritionistId, null);
  });
});

// ---------------------------------------------------------------------------
describe('3. Conversa de nutrição — cada um só escreve o próprio papel', () => {
  const chat = (uid) => collection(client(uid), 'users/aluno/nutrition_chat');
  const msg = (role, extra = {}) => ({ role, content: 'texto', createdAt: 1720000000000, ...extra });

  beforeEach(async () => {
    await signUpAs('nutri1', 'nutritionist', 'Dra. Nutri');
    await signUpAs('nutri2', 'nutritionist');
    await signUpAs('aluno', 'student');
    await signUpAs('outroAluno', 'student');
    await call(linkToProfessional, 'aluno', { code: await codeOf('nutri1'), kind: 'nutritionist' });
  });

  test('C1. aluno cria mensagem `user` e lê a conversa', async () => {
    await assertSucceeds(addDoc(chat('aluno'), msg('user')));
    await assertSucceeds(getDocs(chat('aluno')));
  });

  test('C2. aluno NÃO forja `assistant` nem `nutritionist`', async () => {
    await assertFails(addDoc(chat('aluno'), msg('assistant')));
    await assertFails(addDoc(chat('aluno'), msg('nutritionist', { authorName: 'Dra. Nutri' })));
    // nem se passa por nutricionista com `authorName` numa mensagem `user`
    await assertFails(addDoc(chat('aluno'), msg('user', { authorName: 'Dra. Nutri' })));
    // nem grava campos extras
    await assertFails(addDoc(chat('aluno'), msg('user', { verified: true })));
    await assertFails(addDoc(chat('aluno'), msg('user', { content: '' })));
  });

  test('C3. nutricionista vinculada lê e cria `nutritionist`, mas NÃO `assistant`/`user`', async () => {
    await assertSucceeds(getDocs(chat('nutri1')));
    await assertSucceeds(addDoc(chat('nutri1'), msg('nutritionist', { authorName: 'Dra. Nutri' })));
    await assertFails(addDoc(chat('nutri1'), msg('assistant')));
    await assertFails(addDoc(chat('nutri1'), msg('user')));
  });

  test('C4. quem não é o aluno nem a nutricionista dele não lê nem escreve', async () => {
    await assertFails(getDocs(chat('nutri2')));
    await assertFails(addDoc(chat('nutri2'), msg('nutritionist')));
    await assertFails(getDocs(chat('outroAluno')));
    await assertFails(addDoc(chat('outroAluno'), msg('user')));
  });

  test('C5. mensagens são imutáveis: ninguém muda autor/papel nem apaga', async () => {
    const ref = await addDoc(chat('aluno'), msg('user'));
    const asAluno = doc(client('aluno'), ref.path);
    const asNutri = doc(client('nutri1'), ref.path);
    await assertFails(updateDoc(asAluno, { role: 'assistant' }));
    await assertFails(updateDoc(asAluno, { content: 'editado' }));
    await assertFails(updateDoc(asNutri, { role: 'nutritionist' }));
    await assertFails(deleteDoc(asAluno));
    await assertFails(deleteDoc(asNutri));
  });

  test('C6. a resposta da IA é gravada pelo servidor na conversa do próprio usuário', async () => {
    await saveNutritionReply('aluno', 'Coma mais fibras.');
    await saveNutritionReply('aluno', '   ');
    const snap = await assertSucceeds(getDocs(chat('aluno')));
    const replies = snap.docs.map((d) => d.data()).filter((m) => m.role === 'assistant');
    assert.equal(replies.length, 2);
    assert.ok(replies.some((m) => m.content === 'Coma mais fibras.'));
    assert.ok(replies.some((m) => m.content.startsWith('Desculpe')));
    // A nutricionista vinculada também vê.
    const forNutri = await assertSucceeds(getDocs(chat('nutri1')));
    assert.equal(forNutri.size, 2);
  });
});
