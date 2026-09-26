import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { isAdminToken } from "./admin";

/**
 * Define o plano de IA (Básico/Premium) de um ALUNO — só o admin (e-mail do
 * dono verificado). Grava em um único lugar, `users/{uid}/finance/
 * subscription.planTier`, que é a fonte que a cota lê (`reserveAiQuota` em
 * `ai_guard.ts`). O plano é do aluno: não muda ao vincular/desvincular de
 * um instrutor. Sem plano gravado = Básico.
 */
export const setStudentPlanTier = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "É preciso estar logado.");
  }
  if (!isAdminToken(request.auth.token)) {
    throw new HttpsError(
      "permission-denied",
      "Só o administrador define o plano de IA."
    );
  }

  const studentUid = request.data?.studentUid as string | undefined;
  const planTier = request.data?.planTier as string | undefined;
  if (
    typeof studentUid !== "string" ||
    studentUid.length === 0 ||
    (planTier !== "basic" && planTier !== "premium")
  ) {
    throw new HttpsError("invalid-argument", "Dados inválidos.");
  }

  const db = admin.firestore();
  const studentSnap = await db.collection("users").doc(studentUid).get();
  if (!studentSnap.exists) {
    throw new HttpsError("not-found", "Usuário não encontrado.");
  }
  if ((studentSnap.get("role") ?? "student") !== "student") {
    throw new HttpsError(
      "failed-precondition",
      "Só alunos têm plano de IA."
    );
  }

  await db
    .doc(`users/${studentUid}/finance/subscription`)
    .set({ planTier, planTierUpdatedAt: Date.now() }, { merge: true });

  return { ok: true };
});
