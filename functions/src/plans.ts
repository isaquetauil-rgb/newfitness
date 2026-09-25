import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";

type PlanTier = "basic" | "premium";

/**
 * Limites mensais de IA do plano Básico — o Premium não tem limite
 * (`Infinity`). Espelhado no cliente em `AiUsageLimits`
 * (`lib/shared/models/subscription.dart`) só para exibir "X de Y usados"
 * sem gastar uma leitura extra; a trava de verdade é sempre aqui.
 */
const AI_LIMITS: Record<PlanTier, { mealPhoto: number; bodyPhoto: number }> = {
  basic: { mealPhoto: 3, bodyPhoto: 1 },
  premium: { mealPhoto: Infinity, bodyPhoto: Infinity },
};

function currentMonth(): string {
  return new Date().toISOString().slice(0, 7); // "2026-09"
}

/**
 * Verifica se `uid` ainda tem cota de IA disponível este mês para `field`,
 * SEM incrementar — chame antes de pagar o custo de uma chamada à Claude,
 * pra não gastar a análise num pedido que vai ser recusado. Instrutor nunca
 * é limitado aqui (o limite é só do acompanhamento pessoal de
 * refeição/evolução que o aluno usa) — combinado com o usuário via chat.
 *
 * Devolve o mês corrente pra passar pra `incrementAiUsage` depois que a
 * análise realmente for concluída (`month` vazio = uso ilimitado, nada a
 * incrementar).
 */
export async function assertAiUsageAllowed(
  uid: string,
  field: "mealPhoto" | "bodyPhoto"
): Promise<{ month: string }> {
  const db = admin.firestore();

  const profileSnap = await db.collection("users").doc(uid).get();
  if (profileSnap.data()?.role === "instructor") {
    return { month: "" };
  }

  const subscriptionSnap = await db
    .doc(`users/${uid}/finance/subscription`)
    .get();
  const tier = (subscriptionSnap.data()?.planTier as PlanTier) ?? "basic";
  const limit = AI_LIMITS[tier][field];
  if (limit === Infinity) return { month: "" };

  const month = currentMonth();
  const usageSnap = await db.doc(`users/${uid}/ai_usage/${month}`).get();
  const current = (usageSnap.data()?.[field] as number | undefined) ?? 0;
  if (current >= limit) {
    const label = field === "mealPhoto" ? "análise de refeição" : "análise de evolução";
    throw new HttpsError(
      "resource-exhausted",
      `Você atingiu o limite de ${limit} ${label}(ões) este mês no plano ` +
        "Básico. Peça ao seu instrutor pra assinar o Premium para uso " +
        "ilimitado de IA."
    );
  }
  return { month };
}

/** Chame só depois que a análise de IA for concluída com sucesso. */
export async function incrementAiUsage(
  uid: string,
  field: "mealPhoto" | "bodyPhoto",
  month: string
): Promise<void> {
  if (!month) return; // uso ilimitado (instrutor ou plano Premium)
  await admin
    .firestore()
    .doc(`users/${uid}/ai_usage/${month}`)
    .set({ [field]: admin.firestore.FieldValue.increment(1) }, { merge: true });
}

/**
 * Chamada pelo instrutor pra definir o plano de IA (Básico/Premium) de um
 * aluno vinculado. Espelha o valor em dois documentos: `students/{uid}`
 * (cópia denormalizada que o instrutor já lê em `watchStudents`, mesmo
 * padrão de `monthlyFeeCents`) e `finance/subscription` do aluno (pra ele
 * mesmo conseguir ler o próprio plano — regra do Firestore só deixa o
 * instrutor ler `students`).
 */
export const setStudentPlanTier = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "É preciso estar logado.");
  }

  const studentUid = request.data?.studentUid as string | undefined;
  const planTier = request.data?.planTier as string | undefined;
  if (!studentUid || (planTier !== "basic" && planTier !== "premium")) {
    throw new HttpsError("invalid-argument", "Dados inválidos.");
  }

  const db = admin.firestore();
  const studentSnap = await db.collection("users").doc(studentUid).get();
  if (studentSnap.data()?.instructorId !== request.auth.uid) {
    throw new HttpsError(
      "permission-denied",
      "Você só pode definir o plano dos seus próprios alunos."
    );
  }

  await Promise.all([
    db
      .doc(`users/${studentUid}/finance/subscription`)
      .set({ planTier }, { merge: true }),
    db
      .doc(`users/${request.auth.uid}/students/${studentUid}`)
      .set({ planTier }, { merge: true }),
  ]);

  return { ok: true };
});
