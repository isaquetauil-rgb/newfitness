// Regras do canal de apoio (`support_threads`), contra o Firestore Emulator.
// Dados fictícios.
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
  getDocs,
  setDoc,
  updateDoc,
  deleteDoc,
  collection,
  writeBatch,
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
});

const asUser = (uid) =>
  testEnv.authenticatedContext(uid, { email: `${uid}@aluno.test` }).firestore();
const asAdmin = () =>
  testEnv
    .authenticatedContext('admin-uid', { email: ADMIN_EMAIL, email_verified: true })
    .firestore();

const thread = (from, extra = {}) => ({
  uid: 'aluno',
  name: 'Aluno Teste',
  lastMessage: 'Oi',
  lastMessageAt: 1,
  lastFrom: from,
  unreadByAdmin: from === 'student',
  unreadByStudent: from === 'admin',
  ...extra,
});
const message = (from, text = 'Oi') => ({ text, from, createdAt: 1 });

function sendAs(db, from) {
  const batch = writeBatch(db);
  batch.set(doc(db, 'support_threads/aluno/messages/m1'), message(from));
  batch.set(doc(db, 'support_threads/aluno'), thread(from), { merge: true });
  return batch.commit();
}

async function seedConversation() {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'support_threads/aluno'), thread('student'));
    await setDoc(doc(db, 'support_threads/aluno/messages/m0'), message('student'));
  });
}

test('aluno abre a conversa e envia mensagem', async () => {
  await assertSucceeds(sendAs(asUser('aluno'), 'student'));
});

test('aluno não escreve como equipe', async () => {
  await assertFails(sendAs(asUser('aluno'), 'admin'));
});

test('outro aluno não lê nem escreve na conversa', async () => {
  await seedConversation();
  const other = asUser('intruso');
  await assertFails(getDoc(doc(other, 'support_threads/aluno')));
  await assertFails(getDocs(collection(other, 'support_threads/aluno/messages')));
  await assertFails(
    setDoc(doc(other, 'support_threads/aluno/messages/x'), message('student')),
  );
  await assertFails(getDocs(collection(other, 'support_threads')));
});

test('admin lê todas as conversas e responde como equipe', async () => {
  await seedConversation();
  const admin = asAdmin();
  await assertSucceeds(getDocs(collection(admin, 'support_threads')));
  await assertSucceeds(getDocs(collection(admin, 'support_threads/aluno/messages')));
  await assertSucceeds(sendAs(admin, 'admin'));
});

test('admin não escreve fingindo ser o aluno', async () => {
  await seedConversation();
  await assertFails(
    setDoc(doc(asAdmin(), 'support_threads/aluno/messages/x'), message('student')),
  );
});

test('cada lado só marca como lida a própria parte', async () => {
  await seedConversation();
  // O aluno não apaga o aviso de mensagem nova do admin...
  await assertFails(
    updateDoc(doc(asUser('aluno'), 'support_threads/aluno'), { unreadByAdmin: false }),
  );
  // ...mas o admin marca a própria parte como lida.
  await assertSucceeds(
    updateDoc(doc(asAdmin(), 'support_threads/aluno'), { unreadByAdmin: false }),
  );
  await assertSucceeds(
    updateDoc(doc(asUser('aluno'), 'support_threads/aluno'), { unreadByStudent: false }),
  );
});

test('enviar sem marcar como não lida para o outro lado é recusado', async () => {
  await seedConversation();
  await assertFails(
    setDoc(
      doc(asUser('aluno'), 'support_threads/aluno'),
      thread('student', { unreadByAdmin: false }),
    ),
  );
  await assertFails(
    setDoc(
      doc(asAdmin(), 'support_threads/aluno'),
      thread('admin', { unreadByStudent: false }),
    ),
  );
});

test('mensagens não são editadas nem apagadas', async () => {
  await seedConversation();
  const student = asUser('aluno');
  await assertFails(
    updateDoc(doc(student, 'support_threads/aluno/messages/m0'), { text: 'mudei' }),
  );
  await assertFails(deleteDoc(doc(student, 'support_threads/aluno/messages/m0')));
  await assertFails(deleteDoc(doc(asAdmin(), 'support_threads/aluno')));
});

test('recusa mensagem vazia, longa demais ou com campo extra', async () => {
  const db = asUser('aluno');
  await assertFails(
    setDoc(doc(db, 'support_threads/aluno/messages/a'), message('student', '')),
  );
  await assertFails(
    setDoc(
      doc(db, 'support_threads/aluno/messages/b'),
      message('student', 'x'.repeat(1001)),
    ),
  );
  await assertFails(
    setDoc(doc(db, 'support_threads/aluno/messages/c'), {
      ...message('student'),
      pinned: true,
    }),
  );
});

test('sem login não acessa nada', async () => {
  await seedConversation();
  const anon = testEnv.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(anon, 'support_threads/aluno')));
  await assertFails(sendAs(anon, 'student'));
});
