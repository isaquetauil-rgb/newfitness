import * as admin from "firebase-admin";
import { CallableRequest, HttpsError } from "firebase-functions/v2/https";
import { isAdminToken } from "./admin";

/**
 * Guarda única das Functions de IA: quem pode chamar (e-mail verificado +
 * papel), validação de entrada e a cota de uso (reservada numa transação
 * ANTES de chamar a Claude e devolvida se a chamada falhar).
 */

export type AiRole = "student" | "instructor" | "nutritionist";
export type QuotaKind = "chat" | "nutrition" | "mealPhoto" | "training";
export type PlanTier = "basic" | "premium";
type Period = "day" | "month";

export interface AiCaller {
  uid: string;
  role: AiRole;
  isAdmin: boolean;
}

export const MAX_TEXT_LENGTH = 2000;

/**
 * Exige login, e-mail verificado e um dos papéis aceitos pela Function. O
 * papel vem do perfil no Firestore (`users/{uid}.role`), nunca do cliente.
 */
export async function requireAiCaller(
  request: CallableRequest,
  allowed: AiRole[],
  deniedMessage: string
): Promise<AiCaller> {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "É preciso estar logado.");
  }
  if (request.auth.token.email_verified !== true) {
    throw new HttpsError(
      "permission-denied",
      "Confirme seu e-mail para usar a IA: no Perfil, toque em " +
        "\"Enviar e-mail de verificação\"."
    );
  }
  const uid = request.auth.uid;
  const profile = await admin.firestore().collection("users").doc(uid).get();
  const role = (profile.get("role") as AiRole | undefined) ?? "student";
  if (!allowed.includes(role)) {
    throw new HttpsError("permission-denied", deniedMessage);
  }
  return { uid, role, isAdmin: isAdminToken(request.auth.token) };
}

/** Texto do usuário (mensagem/pedido): trim, de 1 a 2000 caracteres. */
export function validateText(value: unknown, emptyMessage: string): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpsError("invalid-argument", emptyMessage);
  }
  const text = value.trim();
  if (text.length > MAX_TEXT_LENGTH) {
    throw new HttpsError(
      "invalid-argument",
      `O texto pode ter no máximo ${MAX_TEXT_LENGTH} caracteres.`
    );
  }
  return text;
}

/** Tipos de refeição aceitos (os mesmos do enum `MealType` do app). */
export const MEAL_TYPES: Record<string, string> = {
  breakfast: "café da manhã",
  lunch: "almoço",
  dinner: "janta",
  snack: "lanche",
};

/** Devolve o rótulo em português do tipo de refeição, ou recusa. */
export function validateMealType(value: unknown): string {
  if (typeof value !== "string" || !(value in MEAL_TYPES)) {
    throw new HttpsError("invalid-argument", "Tipo de refeição inválido.");
  }
  return MEAL_TYPES[value];
}

// ---------------------------------------------------------------------------
// Cotas

interface Quota {
  limit: number;
  period: Period;
}

const day = (limit: number): Quota => ({ limit, period: "day" });
const month = (limit: number): Quota => ({ limit, period: "month" });

/**
 * Cotas por papel/plano (decisão do dono). Ausente = a função não é do
 * papel (a Function já recusa antes, pelo `requireAiCaller`).
 */
const QUOTAS: Record<
  "basic" | "premium" | "instructor" | "nutritionist",
  Partial<Record<QuotaKind, Quota>>
> = {
  basic: { chat: day(5), nutrition: month(10), mealPhoto: month(3) },
  premium: { chat: day(20), nutrition: month(60), mealPhoto: month(60) },
  instructor: { chat: day(20), training: day(10) },
  nutritionist: { chat: day(20) },
};

/** Admin: 100 por dia em cada função que o papel dele permitir chamar. */
const ADMIN_QUOTA = day(100);

const TIME_ZONE = "America/Sao_Paulo";

/**
 * Chave do período no fuso de São Paulo: `2026-09-25` (dia, vira à
 * meia-noite) ou `2026-09` (mês, vira no dia 1º).
 */
export function periodKey(period: Period, now: Date = new Date()): string {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: TIME_ZONE,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(now);
  const get = (type: string) => parts.find((p) => p.type === type)?.value;
  const ym = `${get("year")}-${get("month")}`;
  return period === "month" ? ym : `${ym}-${get("day")}`;
}

const KIND_LABEL: Record<QuotaKind, string> = {
  chat: "mensagens no chat com IA",
  nutrition: "perguntas ao assistente de nutrição",
  mealPhoto: "análises de foto de refeição",
  training: "sugestões de treino com IA",
};

function exhaustedMessage(
  kind: QuotaKind,
  quota: Quota,
  tier: PlanTier | null
): string {
  const when = quota.period === "day" ? "de hoje" : "deste mês";
  const renew = quota.period === "day" ? "à meia-noite" : "no dia 1º";
  const plan =
    tier === null ? "" : ` do plano ${tier === "premium" ? "Premium" : "Básico"}`;
  return (
    `Você atingiu o limite de ${quota.limit} ${KIND_LABEL[kind]} ${when}` +
    `${plan}. O limite renova ${renew}.`
  );
}

export interface QuotaReservation {
  ref: admin.firestore.DocumentReference;
  kind: QuotaKind;
}

/**
 * Reserva 1 uso de `kind` para o chamador, numa TRANSAÇÃO: lê o plano e o
 * contador do período, recusa se já chegou ao limite e grava o contador +1
 * — tudo atomicamente. Chamadas em paralelo não passam do limite (o
 * Firestore repete a transação que perder a disputa, que então enxerga o
 * contador novo). Chame ANTES de pagar a chamada à Claude; se ela falhar,
 * devolva com `releaseAiQuota`.
 *
 * O plano vem SÓ de `users/{uid}/finance/subscription.planTier` (gravado
 * apenas pelo admin, via `setStudentPlanTier`); sem plano = Básico.
 */
export async function reserveAiQuota(
  caller: AiCaller,
  kind: QuotaKind,
  now: Date = new Date()
): Promise<QuotaReservation> {
  const db = admin.firestore();
  const userRef = db.collection("users").doc(caller.uid);

  return db.runTransaction(
    async (tx) => {
      let quota: Quota | undefined;
      let tier: PlanTier | null = null;
      if (caller.isAdmin) {
        quota = ADMIN_QUOTA;
      } else if (caller.role === "student") {
        const sub = await tx.get(userRef.collection("finance").doc("subscription"));
        tier = sub.get("planTier") === "premium" ? "premium" : "basic";
        quota = QUOTAS[tier][kind];
      } else {
        quota = QUOTAS[caller.role][kind];
      }
      if (!quota) {
        throw new HttpsError(
          "permission-denied",
          "Seu perfil não tem acesso a esta função de IA."
        );
      }

      const ref = userRef.collection("ai_usage").doc(periodKey(quota.period, now));
      const usage = await tx.get(ref);
      const current = (usage.get(kind) as number | undefined) ?? 0;
      if (current >= quota.limit) {
        throw new HttpsError("resource-exhausted", exhaustedMessage(kind, quota, tier));
      }
      tx.set(ref, { [kind]: current + 1, updatedAt: Date.now() }, { merge: true });
      return { ref, kind };
    },
    { maxAttempts: 20 }
  );
}

/**
 * Devolve o uso reservado quando a chamada à IA falhou (o usuário não paga
 * por uma resposta que não recebeu). Nunca deixa o contador negativo;
 * falhar aqui não derruba a Function (só fica 1 uso a mais contado).
 */
export async function releaseAiQuota(reservation: QuotaReservation): Promise<void> {
  const { ref, kind } = reservation;
  try {
    await admin.firestore().runTransaction(
      async (tx) => {
        const snap = await tx.get(ref);
        const current = (snap.get(kind) as number | undefined) ?? 0;
        if (current > 0) {
          tx.set(ref, { [kind]: current - 1, updatedAt: Date.now() }, { merge: true });
        }
      },
      { maxAttempts: 20 }
    );
  } catch (err) {
    console.error("Falha ao devolver a cota de IA", err);
  }
}

/**
 * Reserva a cota, roda `work` e devolve a cota se `work` falhar (o erro
 * original segue para o cliente).
 */
export async function withAiQuota<T>(
  caller: AiCaller,
  kind: QuotaKind,
  work: () => Promise<T>
): Promise<T> {
  const reservation = await reserveAiQuota(caller, kind);
  try {
    return await work();
  } catch (err) {
    await releaseAiQuota(reservation);
    throw err;
  }
}
