// Testes COMPORTAMENTAIS da Cloud Function `linkToProfessional`
// (functions/src/linking.ts) — chama a função de verdade (via `.run()`,
// mecanismo oficial do firebase-functions v2 para invocar um callable sem
// precisar do Functions Emulator) contra o Firestore Emulator (Admin SDK
// apontado para `FIRESTORE_EMULATOR_HOST`). Nunca toca produção.
//
// Pré-requisito: `npm run build` em functions/ (compila functions/lib/linking.js).
'use strict';

const { test, before, after, beforeEach, describe } = require('node:test');
const assert = require('node:assert/strict');

const PROJECT_ID = 'demo-newfitness-func-test';
process.env.GCLOUD_PROJECT = PROJECT_ID;
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';

// `linking.js` (compilado de functions/src/linking.ts) importa `firebase-admin`
// de dentro de `functions/node_modules` — se este teste usasse sua própria
// cópia (de `firestore-tests/node_modules`), seriam DUAS instâncias
// separadas do módulo, e `admin.initializeApp()` chamado aqui não valeria
// para a instância que `linking.js` enxerga ("default app does not exist").
// Por isso carregamos a MESMA cópia que `linking.js` usa.
const admin = require('../functions/node_modules/firebase-admin');
admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();

const linkingModulePath = require.resolve('../functions/lib/linking.js');
let linkToProfessional;
try {
  ({ linkToProfessional } = require(linkingModulePath));
} catch (e) {
  throw new Error(
    'functions/lib/linking.js não encontrado — rode "npm run build" dentro de ' +
      'functions/ antes de rodar estes testes.',
  );
}

async function clearFirestore() {
  const res = await fetch(
    `http://127.0.0.1:8080/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: 'DELETE' },
  );
  if (!res.ok) {
    throw new Error(`Falha ao limpar o Firestore Emulator: HTTP ${res.status}`);
  }
}

function callAs(uid, data) {
  return linkToProfessional.run({
    data,
    auth: uid ? { uid, token: {} } : undefined,
  });
}

async function assertRejectsWithCode(promise, expectedCode) {
  await assert.rejects(promise, (err) => {
    assert.equal(err.code, expectedCode, `esperado code="${expectedCode}", veio "${err.code}" (${err.message})`);
    return true;
  });
}

before(async () => {
  await clearFirestore();
});

beforeEach(async () => {
  await clearFirestore();
  await db.doc('users/instructor-uid').set({
    name: 'Prof. João',
    email: 'joao@x.com',
    role: 'instructor',
    inviteCode: 'ABC123',
  });
  await db.doc('users/nutri-uid').set({
    name: 'Nutri Marina',
    email: 'marina@x.com',
    role: 'nutritionist',
    inviteCode: 'NUT001',
  });
  await db.doc('users/student-uid').set({
    name: 'Ana',
    email: 'ana@x.com',
    role: 'student',
  });
});

describe('linkToProfessional — vínculo por código (comportamental)', () => {
  test('23. aluno consegue solicitar vínculo com um código válido', async () => {
    const result = await callAs('student-uid', { code: 'ABC123', kind: 'instructor' });
    assert.equal(result.ok, true);
    assert.equal(result.name, 'Prof. João');
  });

  test('24. código inválido não cria vínculo nenhum', async () => {
    await assertRejectsWithCode(
      callAs('student-uid', { code: 'CODIGO-QUE-NAO-EXISTE', kind: 'instructor' }),
      'invalid-argument',
    );
    const student = await db.doc('users/student-uid').get();
    assert.equal(student.data().instructorId, undefined);
  });

  test(
    '25. aluno não consegue se vincular a si mesmo (mesmo tendo um código ' +
      'próprio, o filtro por role o exclui da busca por instrutor/nutricionista)',
    async () => {
      await db.doc('users/student-uid').update({ inviteCode: 'SELF01' });
      await assertRejectsWithCode(
        callAs('student-uid', { code: 'SELF01', kind: 'instructor' }),
        'invalid-argument',
      );
      const student = await db.doc('users/student-uid').get();
      assert.equal(student.data().instructorId, undefined);
    },
  );

  test(
    '26. um código que pertence a um usuário sem o role esperado não dá ' +
      'privilégio nenhum (código de nutricionista não vira vínculo de instrutor)',
    async () => {
      await assertRejectsWithCode(
        callAs('student-uid', { code: 'NUT001', kind: 'instructor' }),
        'invalid-argument',
      );
      const student = await db.doc('users/student-uid').get();
      assert.equal(student.data().instructorId, undefined);
    },
  );

  test('27. o vínculo criado gera corretamente a relação aluno <-> instrutor dos dois lados', async () => {
    await callAs('student-uid', { code: 'ABC123', kind: 'instructor' });

    const student = await db.doc('users/student-uid').get();
    assert.equal(student.data().instructorId, 'instructor-uid');

    const entry = await db.doc('users/instructor-uid/students/student-uid').get();
    assert.equal(entry.exists, true);
    assert.equal(entry.data().name, 'Ana');
    assert.equal(entry.data().email, 'ana@x.com');
    assert.equal(typeof entry.data().linkedAt, 'number');
  });

  test('vínculo com nutricionista usa o campo e a coleção corretos (isolado do instrutor)', async () => {
    const result = await callAs('student-uid', { code: 'NUT001', kind: 'nutritionist' });
    assert.equal(result.ok, true);

    const student = await db.doc('users/student-uid').get();
    assert.equal(student.data().nutritionistId, 'nutri-uid');
    assert.equal(student.data().instructorId, undefined);

    const entry = await db.doc('users/nutri-uid/nutrition_students/student-uid').get();
    assert.equal(entry.exists, true);
  });
});

describe('linkToProfessional — checklist de segurança', () => {
  test('usuário não autenticado é rejeitado', async () => {
    await assertRejectsWithCode(
      callAs(undefined, { code: 'ABC123', kind: 'instructor' }),
      'unauthenticated',
    );
  });

  test('usuário com role diferente de "student" não consegue usar a função', async () => {
    await assertRejectsWithCode(
      callAs('instructor-uid', { code: 'ABC123', kind: 'instructor' }),
      'permission-denied',
    );
    await assertRejectsWithCode(
      callAs('nutri-uid', { code: 'ABC123', kind: 'instructor' }),
      'permission-denied',
    );
  });

  test('dados inválidos (sem code/kind, ou kind desconhecido) são rejeitados', async () => {
    await assertRejectsWithCode(callAs('student-uid', {}), 'invalid-argument');
    await assertRejectsWithCode(
      callAs('student-uid', { code: 'ABC123', kind: 'admin' }),
      'invalid-argument',
    );
    await assertRejectsWithCode(
      callAs('student-uid', { code: '   ', kind: 'instructor' }),
      'invalid-argument',
    );
  });

  test(
    'um aluno não consegue usar a função para obter privilégio de instrutor ' +
      '— nenhuma chamada (válida ou não) grava role/privilégio no chamador',
    async () => {
      await callAs('student-uid', { code: 'ABC123', kind: 'instructor' });
      const student = await db.doc('users/student-uid').get();
      // A função só grava instructorId (o vínculo) — nunca role, nunca
      // nenhum campo que faria o próprio aluno virar instrutor.
      assert.equal(student.data().role, 'student');
      assert.equal(student.data().instructorId, 'instructor-uid');
    },
  );
});
