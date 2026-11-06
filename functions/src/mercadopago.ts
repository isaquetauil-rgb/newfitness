import * as admin from "firebase-admin";
import { defineSecret } from "firebase-functions/params";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onRequest } from "firebase-functions/v2/https";
import {
  CHECKOUT_LOCK_MS,
  CheckoutPlan,
  MpPayment,
  SubscriptionState,
  isActiveStatus,
  isValidSignature,
  paymentUpdate,
  planCheckout,
  preapprovalUpdate,
} from "./mercadopago_logic";

// Segredos configurados via `firebase functions:secrets:set NOME` — nunca no
// código-fonte (mesmo padrão de `anthropicApiKey` em `anthropic.ts`).
export const mercadoPagoAccessToken = defineSecret("MERCADOPAGO_ACCESS_TOKEN");
export const mercadoPagoWebhookSecret = defineSecret(
  "MERCADOPAGO_WEBHOOK_SECRET"
);

const MP_API = "https://api.mercadopago.com";
const MP_TIMEOUT_MS = 15 * 1000;

// TODO: trocar por uma URL https real (ex: o domínio do Firebase Hosting do
// app, ou uma deep link) antes de ir pra produção — o Mercado Pago exige um
// `back_url` válido pra redirecionar o aluno depois do checkout.
const BACK_URL = "https://newfitnessappbr.web.app/pagamento-concluido";

const ACTIVE_MESSAGE =
  "Você já tem uma assinatura ativa. Para mudar a forma de pagamento, " +
  "acesse sua conta do Mercado Pago.";
const IN_PROGRESS_MESSAGE =
  "Já estamos preparando seu pagamento. Aguarde um instante.";

function mpFetch(path: string, init: RequestInit = {}): Promise<Response> {
  return fetch(`${MP_API}${path}`, {
    ...init,
    signal: AbortSignal.timeout(MP_TIMEOUT_MS),
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${mercadoPagoAccessToken.value()}`,
    },
  });
}

/** Falha do Mercado Pago: detalhes no log, frase pronta para o aluno. */
async function mpFailure(what: string, response: Response): Promise<HttpsError> {
  console.error(`Mercado Pago: ${what} (${response.status})`, await response.text());
  return new HttpsError(
    "unavailable",
    "Não foi possível falar com o Mercado Pago. Tente novamente."
  );
}

/**
 * Confere no Mercado Pago a assinatura pendente do aluno. Devolve a URL para
 * retomar o mesmo checkout, ou `null` se é preciso criar outra — nesse caso
 * a antiga já está cancelada e não pode mais cobrar.
 */
async function resolvePendingCheckout(
  preapprovalId: string,
  monthlyFeeCents: number,
  subscriptionRef: admin.firestore.DocumentReference
): Promise<string | null> {
  const response = await mpFetch(`/preapproval/${preapprovalId}`);
  if (!response.ok) throw await mpFailure("consulta da assinatura", response);

  const preapproval = (await response.json()) as {
    status: string;
    init_point?: string;
    auto_recurring?: { transaction_amount?: number };
  };

  // O aluno pagou e o aviso do webhook ainda não chegou.
  if (isActiveStatus(preapproval.status)) {
    await subscriptionRef.set(
      { status: preapproval.status, updatedAt: Date.now() },
      { merge: true }
    );
    throw new HttpsError("failed-precondition", ACTIVE_MESSAGE);
  }
  if (preapproval.status === "cancelled" || preapproval.status === "finished") {
    return null;
  }
  // Status desconhecido: na dúvida, não cria outra que possa cobrar também.
  if (preapproval.status !== "pending") {
    console.error("Mercado Pago: status inesperado", preapproval.status);
    throw new HttpsError(
      "unavailable",
      "Não foi possível falar com o Mercado Pago. Tente novamente."
    );
  }

  const amount = preapproval.auto_recurring?.transaction_amount;
  if (
    preapproval.init_point &&
    amount !== undefined &&
    Math.round(amount * 100) === monthlyFeeCents
  ) {
    return preapproval.init_point;
  }

  const cancel = await mpFetch(`/preapproval/${preapprovalId}`, {
    method: "PUT",
    body: JSON.stringify({ status: "cancelled" }),
  });
  if (!cancel.ok) throw await mpFailure("cancelamento da assinatura", cancel);
  return null;
}

/**
 * Cria uma assinatura (Preapproval) no Mercado Pago para o aluno logado,
 * usando o valor mensal definido pelo instrutor em
 * `users/{instructorId}/students/{studentUid}.monthlyFeeCents`. Devolve o
 * `initPoint` (URL de checkout) pro app abrir com `url_launcher`.
 *
 * Cada aluno tem no máximo uma assinatura: quem já tem uma ativa é recusado,
 * quem tem uma pendente retoma o mesmo checkout (ou troca por uma nova, se o
 * valor mudou), e uma trava com prazo barra chamadas simultâneas.
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

    const subscriptionRef = db
      .collection("users")
      .doc(studentUid)
      .collection("finance")
      .doc("subscription");

    const plan: CheckoutPlan = await db.runTransaction(async (tx) => {
      const now = Date.now();
      const snap = await tx.get(subscriptionRef);
      const decision = planCheckout(
        snap.data() as SubscriptionState | undefined,
        now
      );
      if (decision.action === "proceed") {
        tx.set(
          subscriptionRef,
          { checkoutLockUntil: now + CHECKOUT_LOCK_MS },
          { merge: true }
        );
      }
      return decision;
    });

    if (plan.action === "reject") {
      throw new HttpsError(
        "failed-precondition",
        plan.reason === "active" ? ACTIVE_MESSAGE : IN_PROGRESS_MESSAGE
      );
    }

    try {
      if (plan.existingPreapprovalId) {
        const initPoint = await resolvePendingCheckout(
          plan.existingPreapprovalId,
          monthlyFeeCents,
          subscriptionRef
        );
        if (initPoint) return { initPoint };
      }

      const response = await mpFetch("/preapproval", {
        method: "POST",
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
      if (!response.ok) throw await mpFailure("criação da assinatura", response);

      const preapproval = (await response.json()) as {
        id: string;
        init_point: string;
      };

      await subscriptionRef.set(
        {
          status: "pending",
          mpPreapprovalId: preapproval.id,
          amountCents: monthlyFeeCents,
          updatedAt: Date.now(),
        },
        { merge: true }
      );

      return { initPoint: preapproval.init_point };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      console.error("Mercado Pago: falha de rede no checkout", err);
      throw new HttpsError(
        "unavailable",
        "Não foi possível falar com o Mercado Pago. Tente novamente."
      );
    } finally {
      await subscriptionRef.set(
        { checkoutLockUntil: admin.firestore.FieldValue.delete() },
        { merge: true }
      );
    }
  }
);

/**
 * Resultado de buscar no Mercado Pago o recurso avisado: `null` quando ele
 * não existe (ex: notificação de teste), o que não adianta reenviar. Erro
 * temporário sobe para o webhook responder 502 e o Mercado Pago reenviar.
 */
async function fetchNotified<T>(path: string): Promise<T | null> {
  const response = await mpFetch(path);
  if (response.status === 404) return null;
  if (!response.ok) {
    throw new Error(`Mercado Pago respondeu ${response.status} em ${path}`);
  }
  return (await response.json()) as T;
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
    const subscriptionOf = (studentUid: string) =>
      db
        .collection("users")
        .doc(studentUid)
        .collection("finance")
        .doc("subscription");

    try {
      if (type === "payment") {
        const payment = await fetchNotified<
          MpPayment & { external_reference: string; transaction_amount: number }
        >(`/v1/payments/${dataId}`);
        if (payment?.external_reference) {
          const subscriptionRef = subscriptionOf(payment.external_reference);
          await db.runTransaction(async (tx) => {
            const snap = await tx.get(subscriptionRef);
            const now = Date.now();
            tx.set(subscriptionRef.collection("payments").doc(`${payment.id}`), {
              amountCents: Math.round(payment.transaction_amount * 100),
              date: now,
              status: payment.status,
              mpPaymentId: payment.id,
            });
            tx.set(
              subscriptionRef,
              paymentUpdate(snap.data() as SubscriptionState | undefined, payment, now),
              { merge: true }
            );
          });
        }
      } else if (type === "subscription_preapproval" || type === "preapproval") {
        const preapproval = await fetchNotified<{
          id: string;
          status: string;
          external_reference: string;
        }>(`/preapproval/${dataId}`);
        if (preapproval?.external_reference) {
          const subscriptionRef = subscriptionOf(preapproval.external_reference);
          await db.runTransaction(async (tx) => {
            const snap = await tx.get(subscriptionRef);
            const update = preapprovalUpdate(
              snap.data() as Parameters<typeof preapprovalUpdate>[0],
              preapproval,
              Date.now()
            );
            if (update) tx.set(subscriptionRef, update, { merge: true });
          });
        }
      }
    } catch (err) {
      console.error("Mercado Pago: falha ao processar o webhook", err);
      res.status(502).send("Try again");
      return;
    }

    res.status(200).send("ok");
  }
);
