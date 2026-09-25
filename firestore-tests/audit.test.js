// Regressões encontradas na auditoria funcional/E2E — só o que foi
// corrigido nesta rodada e depende das regras (o resto está nos testes
// Flutter). Nunca toca produção; dados fictícios.
'use strict';

const { test, before, after, beforeEach, describe } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, updateDoc, arrayUnion, arrayRemove } = require('firebase/firestore');

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
  await testEnv.withSecurityRulesDisabled(async (c) => {
    const seedDb = c.firestore();
    await setDoc(doc(seedDb, 'announcements/a1'), {
      authorName: 'Admin',
      title: 'Aviso',
      body: 'Texto',
      createdAt: 1,
      likeUids: ['bia'],
    });
    // aviso antigo, sem o campo
    await setDoc(doc(seedDb, 'announcements/old'), {
      authorName: 'Admin',
      title: 'Antigo',
      body: 'Texto',
      createdAt: 1,
    });
  });
});

// Um contexto por usuário (criar vários para o mesmo uid dá
// "Firestore has already been started").
const contexts = new Map();
const db = (uid, email = `${uid}@x.test`) => {
  if (!contexts.has(uid)) contexts.set(uid, testEnv.authenticatedContext(uid, { email }).firestore());
  return contexts.get(uid);
};
const ann = (uid, id = 'a1') => doc(db(uid), `announcements/${id}`);

describe('Timeline — curtir só mexe na própria curtida', () => {
  test('T1. usuário curte e descurte (como o app faz)', async () => {
    await assertSucceeds(updateDoc(ann('ana'), { likeUids: arrayUnion('ana') }));
    await assertSucceeds(updateDoc(ann('ana'), { likeUids: arrayRemove('ana') }));
    await assertSucceeds(updateDoc(ann('ana', 'old'), { likeUids: arrayUnion('ana') }));
  });

  test('T2. NÃO apaga a curtida de outra pessoa nem zera a lista', async () => {
    await assertFails(updateDoc(ann('ana'), { likeUids: arrayRemove('bia') }));
    await assertFails(updateDoc(ann('ana'), { likeUids: [] }));
  });

  test('T3. NÃO inventa curtidas de outras pessoas', async () => {
    await assertFails(updateDoc(ann('ana'), { likeUids: arrayUnion('carla') }));
    await assertFails(updateDoc(ann('ana'), { likeUids: ['bia', 'ana', 'carla'] }));
  });

  test('T4. NÃO altera outros campos do aviso; admin continua podendo', async () => {
    await assertFails(updateDoc(ann('ana'), { title: 'hack' }));
    const asAdmin = doc(db('admin-uid', ADMIN_EMAIL), 'announcements/a1');
    await assertSucceeds(updateDoc(asAdmin, { title: 'Novo título' }));
  });
});
