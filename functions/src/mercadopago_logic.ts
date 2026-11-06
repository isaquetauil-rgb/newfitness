import * as crypto from "crypto";

/**
 * Regras do fluxo de assinatura do Mercado Pago, sem acesso a rede nem ao
 * Firestore — quem chama (`mercadopago.ts`) lê o estado, aplica e grava.
 */

/** Tempo que uma criação de checkout segura a trava (cobre as 3 chamadas). */
export const CHECKOUT_LOCK_MS = 90 * 1000;

/** `users/{uid}/finance/subscription`, só o que estas regras consultam. */
export interface SubscriptionState {
  status?: string;
  mpPreapprovalId?: string;
  lastApprovedPaymentId?: number;
  checkoutLockUntil?: number;
}

export type CheckoutPlan =
  | { action: "reject"; reason: "active" | "in-progress" }
  | { action: "proceed"; existingPreapprovalId?: string };

/** Assinatura que ainda pode cobrar o aluno: não se cria outra por cima. */
export function isActiveStatus(status: string | undefined): boolean {
  return status === "authorized" || status === "paused";
}

/**
 * Decide se pode seguir com o checkout: nunca com assinatura ativa nem com
 * outra criação em andamento (toque duplo, dois aparelhos). Uma assinatura
 * ainda pendente é devolvida para o chamador conferir no Mercado Pago.
 */
export function planCheckout(
  current: SubscriptionState | undefined,
  now: number
): CheckoutPlan {
  if (isActiveStatus(current?.status)) {
    return { action: "reject", reason: "active" };
  }
  if ((current?.checkoutLockUntil ?? 0) > now) {
    return { action: "reject", reason: "in-progress" };
  }
  if (current?.status === "pending" && current.mpPreapprovalId) {
    return { action: "proceed", existingPreapprovalId: current.mpPreapprovalId };
  }
  return { action: "proceed" };
}

/**
 * Assinatura HMAC-SHA256 do payload conforme o padrão de validação de
 * webhook do Mercado Pago: manifest `id:{dataId};request-id:{requestId};ts:{ts};`
 * comparado ao `v1` do header `x-signature`. Confirme o formato exato na
 * documentação do Mercado Pago (Webhooks > Validação de assinatura) ao
 * configurar em produção — provedores de pagamento às vezes ajustam detalhes.
 */
export function isValidSignature(params: {
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
  const expected = Buffer.from(
    crypto.createHmac("sha256", secret).update(manifest).digest("hex")
  );
  const received = Buffer.from(v1);

  // `timingSafeEqual` lança erro com tamanhos diferentes.
  return (
    expected.length === received.length &&
    crypto.timingSafeEqual(expected, received)
  );
}

export interface MpPayment {
  id: number;
  status: string;
}

const MONTH_MS = 30 * 24 * 60 * 60 * 1000;
const REVERSED_STATUSES = ["refunded", "charged_back"];

/**
 * Mudanças em `finance/subscription` causadas por um pagamento.
 *
 * Estorno/contestação do pagamento que mantinha a assinatura em dia a deixa
 * `paused`: o aluno sai de "Em dia", mas a assinatura segue viva no Mercado
 * Pago (e por isso não dá para assinar de novo). A próxima cobrança aprovada
 * a coloca em dia. Estorno de um mês antigo só fica no histórico.
 *
 * Assinatura cancelada não volta a `authorized` por causa de um pagamento
 * que chegou atrasado.
 */
export function paymentUpdate(
  current: SubscriptionState | undefined,
  payment: MpPayment,
  now: number
): Record<string, unknown> {
  if (payment.status === "approved") {
    return {
      ...(current?.status === "cancelled"
        ? {}
        : { status: "authorized", nextPaymentDate: now + MONTH_MS }),
      lastPaymentStatus: "approved",
      lastApprovedPaymentId: payment.id,
      updatedAt: now,
    };
  }
  if (REVERSED_STATUSES.includes(payment.status)) {
    const lastApproved = current?.lastApprovedPaymentId;
    if (lastApproved !== undefined && lastApproved !== payment.id) {
      return { updatedAt: now };
    }
    return {
      ...(current?.status === "cancelled"
        ? {}
        : { status: "paused", nextPaymentDate: null }),
      lastPaymentStatus: payment.status,
      updatedAt: now,
    };
  }
  return { lastPaymentStatus: payment.status, updatedAt: now };
}

/**
 * Mudanças em `finance/subscription` causadas pela assinatura `preapproval`,
 * ou `null` se o aviso é de uma assinatura antiga do aluno (o cancelamento
 * de uma pendente trocada por outra não pode derrubar a atual).
 */
export function preapprovalUpdate(
  current: (SubscriptionState & { lastPaymentStatus?: string }) | undefined,
  preapproval: { id: string; status: string },
  now: number
): Record<string, unknown> | null {
  if (current?.mpPreapprovalId && current.mpPreapprovalId !== preapproval.id) {
    return null;
  }
  // `finished` = terminou o prazo; o app só conhece `cancelled`.
  const status =
    preapproval.status === "finished" ? "cancelled" : preapproval.status;
  const reversed =
    current?.status === "paused" &&
    REVERSED_STATUSES.includes(current.lastPaymentStatus ?? "");
  if (reversed && status === "authorized") {
    return { updatedAt: now };
  }
  return { status, updatedAt: now };
}
