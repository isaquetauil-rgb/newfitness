// Testes COMPORTAMENTAIS do Mercado Pago (`functions/src/mercadopago.ts`)
// contra o Firestore Emulator. O Mercado Pago NUNCA é chamado: `fetch` é
// trocado por um falso que registra cada pedido e devolve o que o teste
// mandar. Dados fictícios.
//
// Pré-requisito: `npm run build` em functions/.
'use strict';

const { test, before, beforeEach, after, describe } = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');

const PROJECT_ID = 'demo-newfitness-rules-test';
const WEBHOOK_SECRET = 'segredo-de-teste';
process.env.GCLOUD_PROJECT = PROJECT_ID;
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.MERCADOPAGO_ACCESS_TOKEN = 'token-de-teste';
process.env.MERCADOPAGO_WEBHOOK_SECRET = WEBHOOK_SECRET;

const admin = require('../functions/node_modules/firebase-admin');
if (admin.apps.length === 0) admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();

const { createSubscriptionCheckout, mercadoPagoWebhook } = require('../functions/lib/mercadopago.js');
const { isValidSignature } = require('../functions/lib/mercadopago_logic.js');

const STUDENT = 'aluno-mp';
const INSTRUCTOR = 'instrutor-mp';
const subRef = db.doc(`users/${STUDENT}/finance/subscription`);
const realFetch = globalThis.fetch;

let calls;
let mpHandler;

const json = (body, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

const checkout = () =>
  createSubscriptionCheckout.run({
    data: {},
    auth: { uid: STUDENT, token: { email_verified: true } },
  });

const sign = (dataId, requestId, ts = '1700000000') => {
  const manifest = `id:${dataId};request-id:${requestId};ts:${ts};`;
  const v1 = crypto.createHmac('sha256', WEBHOOK_SECRET).update(manifest).digest('hex');
  return `ts=${ts},v1=${v1}`;
};

async function webhook(type, dataId, signature = sign(dataId, 'req-1')) {
  const req = {
    method: 'POST',
    query: { 'data.id': dataId, type },
    headers: { 'x-request-id': 'req-1', 'x-signature': signature },
  };
  const result = {};
  const res = {
    status(code) { result.status = code; return res; },
    send(body) { result.body = body; return res; },
  };
  await mercadoPagoWebhook(req, res);
  return result;
}

const postsTo = (path) => calls.filter((c) => c.method === 'POST' && c.path === path);

async function rejectsWith(promise, code) {
  await assert.rejects(promise, (err) => {
    assert.equal(err.code, code);
    return true;
  });
}

before(() => {
  globalThis.fetch = async (url, init = {}) => {
    const path = String(url).replace('https://api.mercadopago.com', '');
    const call = { path, method: init.method ?? 'GET', body: init.body && JSON.parse(init.body) };
    calls.push(call);
    return mpHandler(call);
  };
});

after(async () => {
  globalThis.fetch = realFetch;
  await db.terminate();
});

beforeEach(async () => {
  calls = [];
  mpHandler = () => json({ id: 'pre-novo', init_point: 'https://mp.test/novo' });
  await db.recursiveDelete(db.doc(`users/${STUDENT}`));
  await db.doc(`users/${STUDENT}`).set({ instructorId: INSTRUCTOR, email: 'aluno@teste.com' });
  await db.doc(`users/${INSTRUCTOR}/students/${STUDENT}`).set({ monthlyFeeCents: 15000 });
});

describe('assinatura do webhook', () => {
  test('aceita a assinatura correta', () => {
    assert.equal(isValidSignature({
      dataId: '1', requestId: 'r', signatureHeader: sign('1', 'r'), secret: WEBHOOK_SECRET,
    }), true);
  });

  test('recusa assinatura errada de mesmo tamanho', () => {
    const wrong = 'ts=1700000000,v1=' + 'a'.repeat(64);
    assert.equal(isValidSignature({
      dataId: '1', requestId: 'r', signatureHeader: wrong, secret: WEBHOOK_SECRET,
    }), false);
  });

  test('assinatura de outro tamanho vira 401, não erro interno', async () => {
    const result = await webhook('payment', '1', 'ts=1,v1=curta');
    assert.equal(result.status, 401);
    assert.equal(calls.length, 0);
  });
});

describe('checkout sem cobrança duplicada', () => {
  test('primeira assinatura cria uma no Mercado Pago e libera a trava', async () => {
    const result = await checkout();
    assert.equal(result.initPoint, 'https://mp.test/novo');
    assert.equal(postsTo('/preapproval').length, 1);
    const sub = (await subRef.get()).data();
    assert.equal(sub.status, 'pending');
    assert.equal(sub.mpPreapprovalId, 'pre-novo');
    assert.equal(sub.checkoutLockUntil, undefined);
  });

  for (const status of ['authorized', 'paused']) {
    test(`assinatura ${status} é recusada sem chamar o Mercado Pago`, async () => {
      await subRef.set({ status, mpPreapprovalId: 'pre-1' });
      await rejectsWith(checkout(), 'failed-precondition');
      assert.equal(calls.length, 0);
    });
  }

  test('chamadas simultâneas criam só uma assinatura', async () => {
    mpHandler = (call) => (call.method === 'POST'
      ? json({ id: 'pre-novo', init_point: 'https://mp.test/novo' })
      : json({
        status: 'pending', init_point: 'https://mp.test/novo',
        auto_recurring: { transaction_amount: 150 },
      }));
    const results = await Promise.allSettled([checkout(), checkout(), checkout()]);
    assert.equal(postsTo('/preapproval').length, 1);
    for (const result of results) {
      if (result.status === 'fulfilled') {
        assert.equal(result.value.initPoint, 'https://mp.test/novo');
      } else {
        assert.equal(result.reason.code, 'failed-precondition');
      }
    }
  });

  test('assinatura cancelada no Mercado Pago permite criar outra', async () => {
    await subRef.set({ status: 'pending', mpPreapprovalId: 'pre-1' });
    mpHandler = (call) => (call.method === 'GET'
      ? json({ status: 'cancelled' })
      : json({ id: 'pre-novo', init_point: 'https://mp.test/novo' }));
    assert.equal((await checkout()).initPoint, 'https://mp.test/novo');
    assert.equal(postsTo('/preapproval').length, 1);
  });

  test('status desconhecido não cria outra assinatura', async () => {
    await subRef.set({ status: 'pending', mpPreapprovalId: 'pre-1' });
    mpHandler = () => json({ status: 'status-novo' });
    await rejectsWith(checkout(), 'unavailable');
    assert.equal(postsTo('/preapproval').length, 0);
  });

  test('pendente com o mesmo valor retoma o mesmo checkout', async () => {
    await subRef.set({ status: 'pending', mpPreapprovalId: 'pre-1' });
    mpHandler = () => json({
      status: 'pending', init_point: 'https://mp.test/antigo',
      auto_recurring: { transaction_amount: 150 },
    });
    const result = await checkout();
    assert.equal(result.initPoint, 'https://mp.test/antigo');
    assert.equal(postsTo('/preapproval').length, 0);
  });

  test('pendente com valor antigo é cancelada antes de criar a nova', async () => {
    await subRef.set({ status: 'pending', mpPreapprovalId: 'pre-1' });
    mpHandler = (call) => {
      if (call.method === 'GET') {
        return json({
          status: 'pending', init_point: 'https://mp.test/antigo',
          auto_recurring: { transaction_amount: 100 },
        });
      }
      return json({ id: 'pre-novo', init_point: 'https://mp.test/novo' });
    };
    const result = await checkout();
    assert.equal(result.initPoint, 'https://mp.test/novo');
    assert.deepEqual(calls.map((c) => c.method), ['GET', 'PUT', 'POST']);
    assert.equal(calls[1].body.status, 'cancelled');
  });

  test('se cancelar a antiga falha, não cria a nova', async () => {
    await subRef.set({ status: 'pending', mpPreapprovalId: 'pre-1' });
    mpHandler = (call) => (call.method === 'GET'
      ? json({ status: 'pending', auto_recurring: { transaction_amount: 100 } })
      : json({ message: 'erro' }, 500));
    await rejectsWith(checkout(), 'unavailable');
    assert.equal(postsTo('/preapproval').length, 0);
    assert.equal((await subRef.get()).data().checkoutLockUntil, undefined);
  });

  test('pagou e o webhook não chegou: corrige o status e recusa', async () => {
    await subRef.set({ status: 'pending', mpPreapprovalId: 'pre-1' });
    mpHandler = () => json({ status: 'authorized' });
    await rejectsWith(checkout(), 'failed-precondition');
    assert.equal(postsTo('/preapproval').length, 0);
    assert.equal((await subRef.get()).data().status, 'authorized');
  });

  test('falha ao criar não mostra o erro do Mercado Pago ao aluno', async () => {
    mpHandler = () => json({ message: 'detalhe interno' }, 500);
    await assert.rejects(checkout(), (err) => {
      assert.equal(err.code, 'unavailable');
      assert.doesNotMatch(err.message, /detalhe interno/);
      return true;
    });
  });
});

describe('webhook de pagamento', () => {
  const payment = (id, status) => () => json({
    id, status, external_reference: STUDENT, transaction_amount: 150,
  });

  test('falha temporária do Mercado Pago pede reenvio e nada é gravado', async () => {
    mpHandler = () => json({ message: 'fora do ar' }, 503);
    assert.equal((await webhook('payment', '7')).status, 502);
    assert.equal((await subRef.get()).exists, false);
  });

  test('falha de rede também pede reenvio', async () => {
    mpHandler = () => { throw new Error('sem rede'); };
    assert.equal((await webhook('payment', '7')).status, 502);
  });

  test('o reenvio depois da falha grava o pagamento', async () => {
    mpHandler = () => json({}, 503);
    await webhook('payment', '7');
    mpHandler = payment(7, 'approved');
    assert.equal((await webhook('payment', '7')).status, 200);
    assert.equal((await subRef.get()).data().status, 'authorized');
  });

  test('recurso inexistente (404) não é reenviado', async () => {
    mpHandler = () => json({}, 404);
    assert.equal((await webhook('payment', '7')).status, 200);
  });

  test('aprovado coloca em dia', async () => {
    mpHandler = payment(7, 'approved');
    await webhook('payment', '7');
    const sub = (await subRef.get()).data();
    assert.equal(sub.status, 'authorized');
    assert.equal(sub.lastApprovedPaymentId, 7);
    assert.ok(sub.nextPaymentDate > Date.now());
  });

  for (const status of ['refunded', 'charged_back']) {
    test(`${status} tira o aluno de "em dia"`, async () => {
      mpHandler = payment(7, 'approved');
      await webhook('payment', '7');
      mpHandler = payment(7, status);
      await webhook('payment', '7');
      const sub = (await subRef.get()).data();
      assert.equal(sub.status, 'paused');
      assert.equal(sub.lastPaymentStatus, status);
      assert.equal(sub.nextPaymentDate, null);
    });
  }

  test('estorno de um mês antigo não afeta quem está em dia', async () => {
    await subRef.set({ status: 'authorized', lastApprovedPaymentId: 8, lastPaymentStatus: 'approved' });
    mpHandler = payment(7, 'refunded');
    await webhook('payment', '7');
    const sub = (await subRef.get()).data();
    assert.equal(sub.status, 'authorized');
    assert.equal(sub.lastPaymentStatus, 'approved');
    const record = await subRef.collection('payments').doc('7').get();
    assert.equal(record.data().status, 'refunded');
  });

  test('a cobrança seguinte aprovada coloca em dia de novo', async () => {
    await subRef.set({ status: 'paused', lastApprovedPaymentId: 7, lastPaymentStatus: 'refunded' });
    mpHandler = payment(8, 'approved');
    await webhook('payment', '8');
    assert.equal((await subRef.get()).data().status, 'authorized');
  });

  test('pagamento atrasado não reativa assinatura cancelada', async () => {
    await subRef.set({ status: 'cancelled' });
    mpHandler = payment(7, 'approved');
    await webhook('payment', '7');
    assert.equal((await subRef.get()).data().status, 'cancelled');
  });
});

describe('webhook de assinatura', () => {
  const preapproval = (id, status) => () => json({ id, status, external_reference: STUDENT });

  test('atualiza a assinatura atual', async () => {
    await subRef.set({ status: 'pending', mpPreapprovalId: 'pre-1' });
    mpHandler = preapproval('pre-1', 'authorized');
    await webhook('subscription_preapproval', 'pre-1');
    assert.equal((await subRef.get()).data().status, 'authorized');
  });

  test('ignora o cancelamento de uma assinatura antiga', async () => {
    await subRef.set({ status: 'pending', mpPreapprovalId: 'pre-novo' });
    mpHandler = preapproval('pre-velho', 'cancelled');
    assert.equal((await webhook('subscription_preapproval', 'pre-velho')).status, 200);
    assert.equal((await subRef.get()).data().status, 'pending');
  });

  test('não volta para "em dia" depois de um estorno', async () => {
    await subRef.set({ status: 'paused', mpPreapprovalId: 'pre-1', lastPaymentStatus: 'refunded' });
    mpHandler = preapproval('pre-1', 'authorized');
    await webhook('subscription_preapproval', 'pre-1');
    assert.equal((await subRef.get()).data().status, 'paused');
  });

  test('assinatura encerrada aparece como cancelada no app', async () => {
    await subRef.set({ status: 'authorized', mpPreapprovalId: 'pre-1' });
    mpHandler = preapproval('pre-1', 'finished');
    await webhook('subscription_preapproval', 'pre-1');
    assert.equal((await subRef.get()).data().status, 'cancelled');
  });
});
