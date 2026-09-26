// Rodada 4 — controle de custo e segurança da IA. Testes COMPORTAMENTAIS
// das Functions de IA (`functions/src/ai.ts`) e das regras de
// `chat_messages`/`meal_photos`, contra o Firestore e o Storage Emulator.
//
// A Anthropic NUNCA é chamada: `setClaudeClient` troca o cliente por um
// falso que registra cada pedido (modelo, mensagens, ferramentas) e devolve
// o que o teste mandar. Dados fictícios.
//
// Pré-requisito: `npm run build` em functions/.
'use strict';

const { test, before, after, beforeEach, afterEach, describe } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const PROJECT_ID = 'demo-newfitness-rules-test';
const BUCKET = `${PROJECT_ID}.appspot.com`;
process.env.GCLOUD_PROJECT = PROJECT_ID;
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.FIREBASE_STORAGE_EMULATOR_HOST = '127.0.0.1:9199';

const admin = require('../functions/node_modules/firebase-admin');
admin.initializeApp({ projectId: PROJECT_ID, storageBucket: BUCKET });
const adminDb = admin.firestore();
const bucket = admin.storage().bucket();

const { chatWithAI, askNutritionAI, analyzeMealPhoto, suggestTrainingPlan } = require('../functions/lib/ai.js');
const { setClaudeClient, ClaudeHttpError, AI_TIMEOUTS } = require('../functions/lib/anthropic.js');
const { periodKey } = require('../functions/lib/ai_guard.js');
const { setStudentPlanTier } = require('../functions/lib/plans.js');
const { unlinkFromProfessional } = require('../functions/lib/linking.js');

const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, addDoc, updateDoc, deleteDoc, collection } = require('firebase/firestore');

const ADMIN_EMAIL = 'isaquetrabalho005@gmail.com';
const HAIKU = 'claude-haiku-4-5-20251001';
const SONNET = 'claude-sonnet-5';

let testEnv;
let calls;
let behavior;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
  setClaudeClient(async (req) => {
    calls.push(req);
    return behavior(req);
  });
});

after(async () => {
  setClaudeClient(null);
  await testEnv.cleanup();
});

beforeEach(async () => {
  calls = [];
  behavior = async () => 'Resposta falsa da IA.';
  await testEnv.clearFirestore();
  await adminDb.doc('users/aluno').set({ name: 'Ana Aluna', role: 'student' });
  await adminDb.doc('users/prof').set({ name: 'Paulo Prof', role: 'instructor' });
  await adminDb.doc('users/nutri').set({ name: 'Nina Nutri', role: 'nutritionist' });
  await adminDb.doc('users/owner').set({ name: 'Dono', role: 'student' });
});

afterEach(() => {
  AI_TIMEOUTS.defaultMs = 45_000;
  AI_TIMEOUTS.nutritionMs = 100_000;
});

const token = (uid, { verified = true, email = `${uid}@x.test` } = {}) => ({
  uid,
  token: { email, email_verified: verified },
});
const adminAuth = (verified = true) => token('owner', { verified, email: ADMIN_EMAIL });
const run = (fn, uid, data, opts) => fn.run({ data, auth: token(uid, opts) });

async function rejectsWith(promise, code, messagePart) {
  await assert.rejects(promise, (err) => {
    assert.equal(err.code, code, `esperado "${code}", veio "${err.code}" (${err.message})`);
    if (messagePart) assert.match(err.message, messagePart);
    return true;
  });
}

const usageRef = (uid, period) => adminDb.doc(`users/${uid}/ai_usage/${periodKey(period)}`);
const usageOf = async (uid, period, kind) => (await usageRef(uid, period).get()).get(kind) ?? 0;
const seedUsage = (uid, period, kind, n) => usageRef(uid, period).set({ [kind]: n });

async function uploadMeal(uid, name, { contentType = 'image/jpeg', bytes = Buffer.from([0xff, 0xd8, 0xff, 1, 2, 3]) } = {}) {
  const filePath = `users/${uid}/meal_photos/${name}`;
  await bucket.file(filePath).save(bytes, { contentType });
  return `http://127.0.0.1:9199/v0/b/${BUCKET}/o/${encodeURIComponent(filePath)}?alt=media&token=t`;
}

async function seedMeal(uid, id, imageUrl, extra = {}) {
  await adminDb.doc(`users/${uid}/meal_photos/${id}`).set({
    userId: uid,
    date: 1,
    mealType: 'lunch',
    imageUrl,
    aiAnalysis: null,
    aiAnalysisError: null,
    ...extra,
  });
}

// ---------------------------------------------------------------------------
describe('Cotas por papel e plano', () => {
  test('Q1. aluno Básico: chat 5/dia — a 6ª é recusada com a mensagem do limite', async () => {
    for (let i = 0; i < 5; i++) await run(chatWithAI, 'aluno', { message: `oi ${i}` });
    await rejectsWith(run(chatWithAI, 'aluno', { message: 'mais uma' }), 'resource-exhausted', /limite de 5 .*plano Básico.*meia-noite/);
    assert.equal(calls.length, 5);
    assert.equal(await usageOf('aluno', 'day', 'chat'), 5);
  });

  test('Q2. aluno Básico: nutrição 10/mês (documento do MÊS; foto 3/mês em R1 e S2)', async () => {
    await seedUsage('aluno', 'month', 'nutrition', 9);
    await run(askNutritionAI, 'aluno', { message: 'proteína?' });
    await rejectsWith(run(askNutritionAI, 'aluno', { message: 'e agora?' }), 'resource-exhausted', /limite de 10 .*deste mês.*dia 1º/);
    assert.equal(await usageOf('aluno', 'month', 'nutrition'), 10);
    assert.match(periodKey('month'), /^\d{4}-\d{2}$/);
    assert.match(periodKey('day'), /^\d{4}-\d{2}-\d{2}$/);
  });

  test('Q3. aluno Premium (definido pelo admin): chat 20/dia, nutrição 60/mês, foto 60/mês', async () => {
    await setStudentPlanTier.run({ data: { studentUid: 'aluno', planTier: 'premium' }, auth: adminAuth() });
    await seedUsage('aluno', 'day', 'chat', 19);
    await run(chatWithAI, 'aluno', { message: 'oi' });
    await rejectsWith(run(chatWithAI, 'aluno', { message: 'oi' }), 'resource-exhausted', /limite de 20 .*plano Premium/);
    await seedUsage('aluno', 'month', 'nutrition', 59);
    await run(askNutritionAI, 'aluno', { message: 'oi' });
    await rejectsWith(run(askNutritionAI, 'aluno', { message: 'oi' }), 'resource-exhausted', /limite de 60/);
    await seedUsage('aluno', 'month', 'mealPhoto', 59);
    const url = await uploadMeal('aluno', 'p.jpg');
    await seedMeal('aluno', 'm1', url);
    await seedMeal('aluno', 'm2', url);
    await run(analyzeMealPhoto, 'aluno', { photoId: 'm1' });
    await rejectsWith(run(analyzeMealPhoto, 'aluno', { photoId: 'm2' }), 'resource-exhausted', /limite de 60 análises/);
  });

  test('Q4. instrutor: chat 20/dia e sugestão de treino 10/dia', async () => {
    await seedUsage('prof', 'day', 'chat', 19);
    await run(chatWithAI, 'prof', { message: 'oi' });
    await rejectsWith(run(chatWithAI, 'prof', { message: 'oi' }), 'resource-exhausted', /limite de 20/);
    await seedUsage('prof', 'day', 'training', 9);
    await run(suggestTrainingPlan, 'prof', { prompt: 'treino de perna' });
    await rejectsWith(run(suggestTrainingPlan, 'prof', { prompt: 'mais' }), 'resource-exhausted', /limite de 10 sugestões/);
  });

  test('Q5. nutricionista: chat 20/dia', async () => {
    await seedUsage('nutri', 'day', 'chat', 19);
    await run(chatWithAI, 'nutri', { message: 'oi' });
    await rejectsWith(run(chatWithAI, 'nutri', { message: 'oi' }), 'resource-exhausted', /limite de 20/);
  });

  test('Q6. admin (e-mail verificado): 100/dia em cada função do papel dele', async () => {
    await seedUsage('owner', 'day', 'chat', 99);
    await chatWithAI.run({ data: { message: 'oi' }, auth: adminAuth() });
    await rejectsWith(chatWithAI.run({ data: { message: 'oi' }, auth: adminAuth() }), 'resource-exhausted', /limite de 100/);
    // nutrição do admin (papel aluno) também conta por DIA
    await askNutritionAI.run({ data: { message: 'oi' }, auth: adminAuth() });
    assert.equal(await usageOf('owner', 'day', 'nutrition'), 1);
    assert.equal(await usageOf('owner', 'month', 'nutrition'), 0);
  });
});

// ---------------------------------------------------------------------------
describe('Atomicidade e devolução da cota', () => {
  test('R1. corrida: 10 análises em paralelo com cota 3 → exatamente 3 aprovadas e 3 chamadas à IA', async () => {
    const url = await uploadMeal('aluno', 'corrida.jpg');
    for (let i = 0; i < 10; i++) await seedMeal('aluno', `m${i}`, url);
    behavior = async () => {
      await new Promise((r) => setTimeout(r, 50));
      return 'Prato equilibrado.';
    };

    const results = await Promise.allSettled(
      Array.from({ length: 10 }, (_, i) => run(analyzeMealPhoto, 'aluno', { photoId: `m${i}` })),
    );
    const ok = results.filter((r) => r.status === 'fulfilled');
    const denied = results.filter((r) => r.status === 'rejected');
    assert.equal(ok.length, 3);
    assert.equal(calls.length, 3);
    for (const r of denied) assert.equal(r.reason.code, 'resource-exhausted');
    assert.equal(await usageOf('aluno', 'month', 'mealPhoto'), 3);
  });

  test('R2. falha da IA devolve a cota (erro genérico e 429 → unavailable)', async () => {
    behavior = async () => {
      throw new Error('falha qualquer');
    };
    await rejectsWith(run(chatWithAI, 'aluno', { message: 'oi' }), 'internal');
    assert.equal(await usageOf('aluno', 'day', 'chat'), 0);

    behavior = async () => {
      throw new ClaudeHttpError(429, 'rate limit');
    };
    await rejectsWith(run(chatWithAI, 'aluno', { message: 'oi' }), 'unavailable', /muita procura/);
    behavior = async () => {
      throw new ClaudeHttpError(529, 'overloaded');
    };
    await rejectsWith(run(askNutritionAI, 'aluno', { message: 'oi' }), 'unavailable');
    assert.equal(await usageOf('aluno', 'day', 'chat'), 0);
    assert.equal(await usageOf('aluno', 'month', 'nutrition'), 0);
  });

  test('R3. timeout: aborta a chamada, devolve deadline-exceeded amigável e a cota', async () => {
    AI_TIMEOUTS.defaultMs = 50;
    let signal;
    behavior = (req) => {
      signal = req.signal;
      return new Promise(() => {}); // nunca responde
    };
    await rejectsWith(run(chatWithAI, 'aluno', { message: 'oi' }), 'deadline-exceeded', /A IA demorou para responder/);
    assert.equal(signal.aborted, true);
    assert.equal(await usageOf('aluno', 'day', 'chat'), 0);

    AI_TIMEOUTS.nutritionMs = 50;
    await rejectsWith(run(askNutritionAI, 'aluno', { message: 'oi' }), 'deadline-exceeded');
  });
});

// ---------------------------------------------------------------------------
describe('Quem pode chamar', () => {
  test('P1. e-mail NÃO verificado é negado em todas as Functions de IA, sem chamar a IA', async () => {
    const unverified = { verified: false };
    await rejectsWith(run(chatWithAI, 'aluno', { message: 'oi' }, unverified), 'permission-denied', /Confirme seu e-mail/);
    await rejectsWith(run(askNutritionAI, 'aluno', { message: 'oi' }, unverified), 'permission-denied');
    await rejectsWith(run(analyzeMealPhoto, 'aluno', { photoId: 'x' }, unverified), 'permission-denied');
    await rejectsWith(run(suggestTrainingPlan, 'prof', { prompt: 'oi' }, unverified), 'permission-denied');
    await rejectsWith(chatWithAI.run({ data: { message: 'oi' }, auth: adminAuth(false) }), 'permission-denied');
    await rejectsWith(chatWithAI.run({ data: { message: 'oi' } }), 'unauthenticated');
    assert.equal(calls.length, 0);
  });

  test('P2. papéis: sugestão só instrutor; nutrição e foto só aluno', async () => {
    await rejectsWith(run(suggestTrainingPlan, 'aluno', { prompt: 'oi' }), 'permission-denied');
    await rejectsWith(run(suggestTrainingPlan, 'nutri', { prompt: 'oi' }), 'permission-denied');
    await rejectsWith(run(askNutritionAI, 'prof', { message: 'oi' }), 'permission-denied');
    await rejectsWith(run(askNutritionAI, 'nutri', { message: 'oi' }), 'permission-denied');
    await rejectsWith(run(analyzeMealPhoto, 'prof', { photoId: 'm1' }), 'permission-denied');
    assert.equal(calls.length, 0);
    for (const uid of ['aluno', 'prof', 'nutri']) await run(chatWithAI, uid, { message: 'oi' });
    assert.equal(calls.length, 3);
  });

  test('P3. sugestão por aluno: só aluno vinculado, e o nome vem do perfil (não do cliente)', async () => {
    await rejectsWith(
      run(suggestTrainingPlan, 'prof', { prompt: 'dor lombar', studentUid: 'aluno' }),
      'permission-denied',
      /não está vinculado/,
    );
    await adminDb.doc('users/aluno').update({ instructorId: 'prof' });
    await run(suggestTrainingPlan, 'prof', { prompt: 'dor lombar', studentUid: 'aluno', studentName: 'Nome Forjado' });
    const sent = calls[0].messages[0].content;
    assert.match(sent, /Ana Aluna/);
    assert.doesNotMatch(sent, /Nome Forjado/);
  });

  test('P4. foto de outra pessoa: não encontrada; URL fora da pasta do dono: inválida', async () => {
    const other = await uploadMeal('outro', 'x.jpg');
    await seedMeal('outro', 'dele', other);
    await rejectsWith(run(analyzeMealPhoto, 'aluno', { photoId: 'dele' }), 'not-found');
    await seedMeal('aluno', 'aponta', other);
    await rejectsWith(run(analyzeMealPhoto, 'aluno', { photoId: 'aponta' }), 'invalid-argument');
    assert.equal(calls.length, 0);
  });
});

// ---------------------------------------------------------------------------
describe('Validação de entrada e histórico', () => {
  test('V1. mensagem/pedido: trim, de 1 a 2000 caracteres', async () => {
    await rejectsWith(run(chatWithAI, 'aluno', { message: '   ' }), 'invalid-argument');
    await rejectsWith(run(chatWithAI, 'aluno', { message: 42 }), 'invalid-argument');
    await rejectsWith(run(chatWithAI, 'aluno', { message: 'x'.repeat(2001) }), 'invalid-argument', /2000/);
    await rejectsWith(run(suggestTrainingPlan, 'prof', { prompt: 'x'.repeat(2001) }), 'invalid-argument');
    await run(chatWithAI, 'aluno', { message: `  ${'y'.repeat(2000)}  ` });
    assert.equal(calls.length, 1);
    assert.equal(calls[0].messages.at(-1).content, 'y'.repeat(2000));
  });

  test('V2. mealType fora do enum: recusado, erro registrado na foto, sem IA', async () => {
    const url = await uploadMeal('aluno', 'tipo.jpg');
    await seedMeal('aluno', 'm1', url, { mealType: 'ceia' });
    await rejectsWith(run(analyzeMealPhoto, 'aluno', { photoId: 'm1' }), 'invalid-argument', /Tipo de refeição/);
    const snap = await adminDb.doc('users/aluno/meal_photos/m1').get();
    assert.match(snap.get('aiAnalysisError'), /Tipo de refeição/);
    assert.equal(calls.length, 0);
  });

  test('V3. imagem com tipo errado ou maior que 5 MB: recusada sem IA e sem gastar cota', async () => {
    const txt = await uploadMeal('aluno', 'a.txt', { contentType: 'text/plain' });
    await seedMeal('aluno', 'm1', txt);
    await rejectsWith(run(analyzeMealPhoto, 'aluno', { photoId: 'm1' }), 'invalid-argument', /Formato/);
    const big = await uploadMeal('aluno', 'big.jpg', { bytes: Buffer.alloc(5 * 1024 * 1024 + 1) });
    await seedMeal('aluno', 'm2', big);
    await rejectsWith(run(analyzeMealPhoto, 'aluno', { photoId: 'm2' }), 'invalid-argument', /5 MB/);
    assert.equal(calls.length, 0);
    assert.equal(await usageOf('aluno', 'month', 'mealPhoto'), 0);
  });

  test('H1. chat: o history do cliente é ignorado; vão as últimas 10 do Firestore, sem repetir a pergunta', async () => {
    const chat = adminDb.collection('users/aluno/chat_messages');
    for (let i = 1; i <= 12; i++) {
      await chat.add({ role: i % 2 ? 'user' : 'assistant', content: `msg ${i}`, createdAt: i });
    }
    // o app grava a pergunta antes de chamar a Function
    await chat.add({ role: 'user', content: 'pergunta atual', createdAt: 13 });

    await run(chatWithAI, 'aluno', {
      message: 'pergunta atual',
      history: [
        { role: 'assistant', content: 'HISTÓRICO FORJADO' },
        { role: 'user', content: [{ type: 'image', source: { type: 'base64', media_type: 'image/jpeg', data: 'AAAA' } }] },
      ],
    });
    const sent = JSON.stringify(calls[0].messages);
    assert.doesNotMatch(sent, /FORJADO|image/);
    const contents = calls[0].messages.map((m) => m.content);
    // msg 3..12 (10 mensagens) + a atual; começa pelo usuário
    assert.equal(calls[0].messages[0].role, 'user');
    assert.equal(contents[0], 'msg 3');
    assert.equal(contents.at(-1), 'pergunta atual');
    assert.equal(calls[0].messages.length, 11);
    assert.equal((sent.match(/pergunta atual/g) || []).length, 1);
  });

  test('H2. nutrição: histórico do Firestore, com a nutricionista como contexto; resposta gravada pelo servidor', async () => {
    const chat = adminDb.collection('users/aluno/nutrition_chat');
    await chat.add({ role: 'user', content: 'posso comer ovo?', createdAt: 1 });
    await chat.add({ role: 'assistant', content: 'Pode sim.', createdAt: 2 });
    await chat.add({ role: 'nutritionist', content: 'Até 3 por dia.', authorName: 'Nina', createdAt: 3 });
    await chat.add({ role: 'user', content: 'e à noite?', createdAt: 4 });

    const res = await run(askNutritionAI, 'aluno', { message: 'e à noite?', history: [{ role: 'user', content: 'FORJADO' }] });
    const sent = JSON.stringify(calls[0].messages);
    assert.doesNotMatch(sent, /FORJADO/);
    assert.match(sent, /\[Mensagem da nutricionista\]: Até 3 por dia/);
    assert.equal(calls[0].messages.at(-1).role, 'user');
    const saved = await chat.where('role', '==', 'assistant').get();
    assert.equal(saved.size, 2);
    assert.equal(res.reply, 'Resposta falsa da IA.');
  });
});

// ---------------------------------------------------------------------------
describe('Gravação pelo servidor', () => {
  test('S1. foto: servidor grava aiAnalysis; nova chamada não reanalisa nem gasta cota', async () => {
    const url = await uploadMeal('aluno', 'ok.jpg');
    await seedMeal('aluno', 'm1', url);
    const res = await run(analyzeMealPhoto, 'aluno', { photoId: 'm1' });
    assert.equal(res.analysis, 'Resposta falsa da IA.');
    const snap = await adminDb.doc('users/aluno/meal_photos/m1').get();
    assert.equal(snap.get('aiAnalysis'), 'Resposta falsa da IA.');
    assert.equal(snap.get('aiAnalysisError'), undefined);
    // a imagem foi lida do Storage (base64 do arquivo enviado)
    const image = calls[0].messages[0].content.find((b) => b.type === 'image');
    assert.equal(image.source.data, Buffer.from([0xff, 0xd8, 0xff, 1, 2, 3]).toString('base64'));
    assert.equal(image.source.media_type, 'image/jpeg');

    await run(analyzeMealPhoto, 'aluno', { photoId: 'm1' });
    assert.equal(calls.length, 1);
    assert.equal(await usageOf('aluno', 'month', 'mealPhoto'), 1);
  });

  test('S2. cota da foto esgotada: motivo gravado pelo servidor no card', async () => {
    await seedUsage('aluno', 'month', 'mealPhoto', 3);
    const url = await uploadMeal('aluno', 'ok.jpg');
    await seedMeal('aluno', 'm1', url);
    await rejectsWith(run(analyzeMealPhoto, 'aluno', { photoId: 'm1' }), 'resource-exhausted', /limite de 3/);
    const snap = await adminDb.doc('users/aluno/meal_photos/m1').get();
    assert.match(snap.get('aiAnalysisError'), /limite de 3/);
    assert.equal(snap.get('aiAnalysis'), null);
  });

  test('S3. versão antiga (sem photoId, com base64): failed-precondition, sem IA', async () => {
    await rejectsWith(
      run(analyzeMealPhoto, 'aluno', { imageBase64: 'AAAA', mediaType: 'image/jpeg', mealType: 'Almoço' }),
      'failed-precondition',
      /Atualize o app para ver a análise da IA/,
    );
    assert.equal(calls.length, 0);
  });

  test('S4. regras de meal_photos: cliente cria sem análise, nunca grava aiAnalysis/aiAnalysisError', async () => {
    const db = testEnv.authenticatedContext('aluno', { email_verified: true }).firestore();
    const base = { userId: 'aluno', date: 1, mealType: 'lunch', imageUrl: 'x' };
    await assertSucceeds(setDoc(doc(db, 'users/aluno/meal_photos/novo'), { ...base, aiAnalysis: null, aiAnalysisError: null }));
    await assertSucceeds(setDoc(doc(db, 'users/aluno/meal_photos/semcampo'), base));
    await assertFails(setDoc(doc(db, 'users/aluno/meal_photos/forjada'), { ...base, aiAnalysis: 'Refeição perfeita!' }));
    await assertFails(setDoc(doc(db, 'users/aluno/meal_photos/forjada2'), { ...base, aiAnalysisError: 'x' }));
    await assertFails(updateDoc(doc(db, 'users/aluno/meal_photos/novo'), { aiAnalysis: 'Refeição perfeita!' }));
    await assertFails(updateDoc(doc(db, 'users/aluno/meal_photos/novo'), { aiAnalysisError: 'x' }));
    await assertSucceeds(updateDoc(doc(db, 'users/aluno/meal_photos/novo'), { mealType: 'dinner' }));
    await assertSucceeds(deleteDoc(doc(db, 'users/aluno/meal_photos/novo')));
  });

  test('S5. chat geral: servidor grava a resposta; cliente só cria "user" (1–2000, campos fechados)', async () => {
    const res = await run(chatWithAI, 'aluno', { message: 'oi' });
    const saved = await adminDb.collection('users/aluno/chat_messages').where('role', '==', 'assistant').get();
    assert.equal(saved.size, 1);
    assert.equal(saved.docs[0].get('content'), res.reply);

    const db = testEnv.authenticatedContext('aluno', { email_verified: true }).firestore();
    const chat = collection(db, 'users/aluno/chat_messages');
    const ref = await assertSucceeds(addDoc(chat, { role: 'user', content: 'oi', createdAt: 1 }));
    await assertFails(addDoc(chat, { role: 'assistant', content: 'forjada', createdAt: 1 }));
    await assertFails(addDoc(chat, { role: 'user', content: 'oi', createdAt: 1, extra: true }));
    await assertFails(addDoc(chat, { role: 'user', content: '', createdAt: 1 }));
    await assertFails(addDoc(chat, { role: 'user', content: 'x'.repeat(2001), createdAt: 1 }));
    await assertFails(updateDoc(ref, { content: 'editada' }));
    await assertSucceeds(deleteDoc(ref));
    const other = testEnv.authenticatedContext('prof', { email_verified: true }).firestore();
    await assertFails(addDoc(collection(other, 'users/aluno/chat_messages'), { role: 'user', content: 'oi', createdAt: 1 }));
  });
});

// ---------------------------------------------------------------------------
describe('Plano (planTier) só pelo admin', () => {
  test('T1. instrutor e admin sem e-mail verificado não definem o plano', async () => {
    await adminDb.doc('users/aluno').update({ instructorId: 'prof' });
    await rejectsWith(
      setStudentPlanTier.run({ data: { studentUid: 'aluno', planTier: 'premium' }, auth: token('prof') }),
      'permission-denied',
    );
    await rejectsWith(
      setStudentPlanTier.run({ data: { studentUid: 'aluno', planTier: 'premium' }, auth: adminAuth(false) }),
      'permission-denied',
    );
    assert.equal((await adminDb.doc('users/aluno/finance/subscription').get()).exists, false);
  });

  test('T2. admin define no aluno (fonte única); o plano continua após desvincular', async () => {
    await adminDb.doc('users/aluno').update({ instructorId: 'prof' });
    await adminDb.doc('users/prof/students/aluno').set({ uid: 'aluno', name: 'Ana Aluna', planTier: 'basic' });
    await setStudentPlanTier.run({ data: { studentUid: 'aluno', planTier: 'premium' }, auth: adminAuth() });
    assert.equal((await adminDb.doc('users/aluno/finance/subscription').get()).get('planTier'), 'premium');

    await unlinkFromProfessional.run({ data: { kind: 'instructor' }, auth: token('aluno') });
    assert.equal((await adminDb.doc('users/aluno/finance/subscription').get()).get('planTier'), 'premium');

    // a cota lê o plano do aluno (Premium: 20/dia), não a cópia do instrutor
    await seedUsage('aluno', 'day', 'chat', 5);
    await run(chatWithAI, 'aluno', { message: 'oi' });
  });

  test('T3. só aluno tem plano; dados inválidos recusados', async () => {
    await rejectsWith(
      setStudentPlanTier.run({ data: { studentUid: 'prof', planTier: 'premium' }, auth: adminAuth() }),
      'failed-precondition',
    );
    await rejectsWith(
      setStudentPlanTier.run({ data: { studentUid: 'aluno', planTier: 'gold' }, auth: adminAuth() }),
      'invalid-argument',
    );
    await rejectsWith(
      setStudentPlanTier.run({ data: { studentUid: 'ninguem', planTier: 'basic' }, auth: adminAuth() }),
      'not-found',
    );
  });
});

// ---------------------------------------------------------------------------
describe('Modelo por função', () => {
  test('M1. chat e foto: Haiku 4.5; nutrição e sugestão: Sonnet 5; busca na web só na nutrição, 1 por pergunta', async () => {
    await adminDb.doc('users/aluno').update({ instructorId: 'prof' });
    await run(chatWithAI, 'aluno', { message: 'oi' });
    await run(askNutritionAI, 'aluno', { message: 'oi' });
    const url = await uploadMeal('aluno', 'ok.jpg');
    await seedMeal('aluno', 'm1', url);
    await run(analyzeMealPhoto, 'aluno', { photoId: 'm1' });
    await run(suggestTrainingPlan, 'prof', { prompt: 'oi', studentUid: 'aluno' });

    assert.deepEqual(calls.map((c) => c.model), [HAIKU, SONNET, HAIKU, SONNET]);
    assert.equal(calls[0].tools, undefined);
    assert.deepEqual(calls[1].tools, [{ type: 'web_search_20250305', name: 'web_search', max_uses: 1 }]);
    assert.equal(calls[2].tools, undefined);
    assert.equal(calls[3].tools, undefined);
    assert.match(calls[0].system, /não substitui/);
    assert.match(calls[1].system, /não substitui/);
  });
});
