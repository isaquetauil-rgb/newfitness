import * as crypto from "crypto";
import * as admin from "firebase-admin";
import { defineSecret } from "firebase-functions/params";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onRequest } from "firebase-functions/v2/https";

// Segredos configurados via `firebase functions:secrets:set NOME` — nunca no
// código-fonte (mesmo padrão de `anthropicApiKey` em `anthropic.ts`).
export const mercadoPagoAccessToken = defineSecret("MERCADOPAGO_ACCESS_TOKEN");
export const mercadoPagoWebhookSecret = defineSecret(
  "MERCADOPAGO_WEBHOOK_SECRET"
);

const MP_API = "https://api.mercadopago.com";

// TODO: trocar por uma URL https real (ex: o domínio do Firebase Hosting do
// app, ou uma deep link) antes de ir pra produção — o Mercado Pago exige um
// `back_url` válido pra redirecionar o aluno depois do checkout.
const BACK_URL = "https://newfitnessappbr.web.app/pagamento-concluido";

/**
 * Cria uma assinatura (Preapproval) no Mercado Pago para o aluno logado,
 * usando o valor mensal definido pelo instrutor em
 * `users/{instructorId}/students/{studentUid}.monthlyFeeCents`. Devolve o
 * `initPoint` (URL de checkout) pro app abrir com `url_launcher`.
 */
export const createSubscriptionCheckout = onCall(
  { secrets: [mercadoPagoAccessToken] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "É preciso estar logado.");
    }

    const studentUid = request.auth.uid;
    const db = admin.firestore();

    const studentSnap = await db.collection("users").doc(studentUid).get();
    const student = studentSnap.data();
    const instructorId = student?.instructorId as string | undefined;
    if (!instructorId) {
      throw new HttpsError(
        "failed-precondition",
        "Você ainda não está vinculado a um instrutor."
      );
    }

    const studentEntrySnap = await db
      .collection("users")
      .doc(instructorId)
      .collection("students")
      .doc(studentUid)
      .get();
    const monthlyFeeCents = studentEntrySnap.data()?.monthlyFeeCents as
      | number
      | undefined;
    if (!monthlyFeeCents || monthlyFeeCents <= 0) {
      throw new HttpsError(
        "failed-precondition",
        "Seu instrutor ainda não definiu o valor da mensalidade."
      );
    }

    const response = await fetch(`${MP_API}/preapproval`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${mercadoPagoAccessToken.value()}`,
      },
      body: JSON.stringify({
        reason: "Mensalidade NewFitness",
        external_reference: studentUid,
        payer_email: student?.email,
        back_url: BACK_URL,
        auto_recurring: {
          frequency: 1,
          frequency_type: "months",
          transaction_amount: monthlyFeeCents / 100,
          currency_id: "BRL",
        },
      }),
    });

    if (!response.ok) {
      const errText = await response.text();
      throw new HttpsError(
        "internal",
        `Erro ao criar assinatura no Mercado Pago: ${errText}`
      );
    }

    const preapproval = (await response.json()) as {
      id: string;
      init_point: string;
    };

    await db
      .collection("users")
      .doc(studentUid)
      .collection("finance")
      .doc("subscription")
      .set(
        {
          status: "pending",
          mpPreapprovalId: preapproval.id,
          amountCents: monthlyFeeCents,
          updatedAt: Date.now(),
        },
        { merge: true }
      );

    return { initPoint: preapproval.init_point };
  }
);

/**
 * Assinatura HMAC-SHA256 do payload conforme o padrão de validação de
 * webhook do Mercado Pago: manifest `id:{dataId};request-id:{requestId};ts:{ts};`
 * comparado ao `v1` do header `x-signature`. Confirme o formato exato na
 * documentação do Mercado Pago (Webhooks > Validação de assinatura) ao
 * configurar em produção — provedores de pagamento às vezes ajustam detalhes.
 */
function isValidSignature(params: {
  dataId: string;
  requestId: string | undefined;
  signatureHeader: string | undefined;
  secret: string;
}): boolean {
  const { dataId, requestId, signatureHeader, secret } = params;
  if (!signatureHeader) return false;

  const parts = Object.fromEntries(
    signatureHeader.split(",").map((p) => {
      const [key, value] = p.split("=");
      return [key.trim(), value?.trim()];
    })
  );
  const ts = parts["ts"];
  const v1 = parts["v1"];
  if (!ts || !v1) return false;

  const manifest = `id:${dataId};request-id:${requestId ?? ""};ts:${ts};`;
  const expected = crypto
    .createHmac("sha256", secret)
    .update(manifest)
    .digest("hex");

  return crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(v1));
}

/**
 * Endpoint HTTP chamado diretamente pelo Mercado Pago (sem autenticação do
 * Firebase) quando um pagamento ou assinatura muda de status. A validação de
 * assinatura é a única defesa contra uma chamada forjada nesse endpoint
 * público — nunca gravar no Firestore sem ela passar.
 */
export const mercadoPagoWebhook = onRequest(
  { secrets: [mercadoPagoAccessToken, mercadoPagoWebhookSecret] },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method not allowed");
      return;
    }

    const dataId = (req.query["data.id"] ?? req.query["id"]) as
      | string
      | undefined;
    const type = req.query["type"] as string | undefined;
    if (!dataId || !type) {
      res.status(400).send("Missing data.id/type");
      return;
    }

    const validSignature = isValidSignature({
      dataId,
      requestId: req.headers["x-request-id"] as string | undefined,
      signatureHeader: req.headers["x-signature"] as string | undefined,
      secret: mercadoPagoWebhookSecret.value(),
    });
    if (!validSignature) {
      res.status(401).send("Invalid signature");
      return;
    }

    const db = admin.firestore();
    const authHeader = { Authorization: `Bearer ${mercadoPagoAccessToken.value()}` };

    if (type === "payment") {
      const paymentResp = await fetch(`${MP_API}/v1/payments/${dataId}`, {
        headers: authHeader,
      });
      if (!paymentResp.ok) {
        res.status(200).send("ok"); // não retenta se o próprio MP falhar
        return;
      }
      const payment = (await paymentResp.json()) as {
        id: number;
        status: string;
        external_reference: string;
        transaction_amount: number;
      };
      const studentUid = payment.external_reference;
      if (studentUid) {
        const subscriptionRef = db
          .collection("users")
          .doc(studentUid)
          .collection("finance")
          .doc("subscription");

        await subscriptionRef
          .collection("payments")
          .doc(`${payment.id}`)
          .set({
            amountCents: Math.round(payment.transaction_amount * 100),
            date: Date.now(),
            status: payment.status,
            mpPaymentId: payment.id,
          });

        if (payment.status === "approved") {
          await subscriptionRef.set(
            {
              status: "authorized",
              lastPaymentStatus: "approved",
              nextPaymentDate: Date.now() + 30 * 24 * 60 * 60 * 1000,
              updatedAt: Date.now(),
            },
            { merge: true }
          );
        } else {
          await subscriptionRef.set(
            { lastPaymentStatus: payment.status, updatedAt: Date.now() },
            { merge: true }
          );
        }
      }
    } else if (type === "subscription_preapproval" || type === "preapproval") {
      const preapprovalResp = await fetch(`${MP_API}/preapproval/${dataId}`, {
        headers: authHeader,
      });
      if (!preapprovalResp.ok) {
        res.status(200).send("ok");
        return;
      }
      const preapproval = (await preapprovalResp.json()) as {
        status: string;
        external_reference: string;
      };
      const studentUid = preapproval.external_reference;
      if (studentUid) {
        await db
          .collection("users")
          .doc(studentUid)
          .collection("finance")
          .doc("subscription")
          .set(
            { status: preapproval.status, updatedAt: Date.now() },
            { merge: true }
          );
      }
    }

    res.status(200).send("ok");
  }
);
