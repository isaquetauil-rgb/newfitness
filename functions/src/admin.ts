import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { revokeInstructorLinks } from "./linking";

/**
 * E-mail do dono do app — única constante das Functions (use sempre esta).
 * O MESMO valor está em `isAdmin()` de `firestore.rules`, em `ownerEmail`
 * de `lib/core/constants/admin_config.dart` e nas constantes `ADMIN_EMAIL`
 * dos testes do emulador (`firestore-tests/`). Todos precisam bater.
 */
export const ADMIN_EMAIL = "isaquetrabalho005@gmail.com";

/**
 * Mesmo critério das regras: e-mail do token igual ao do dono E e-mail
 * verificado (`email_verified === true`).
 */
export function isAdminToken(
  token: { email?: string; email_verified?: boolean } | undefined
): boolean {
  return (
    typeof token?.email === "string" &&
    token.email.toLowerCase() === ADMIN_EMAIL.toLowerCase() &&
    token.email_verified === true
  );
}

/**
 * Estatísticas do painel de administração, contadas no servidor (Admin SDK).
 *
 * Por quê numa Function: duas das contagens atravessam os dados de TODOS os
 * alunos (`workouts` e `finance` de cada um, via collection group). Liberar
 * isso nas regras exigiria uma regra de collection group para `workouts` e
 * `finance` — mais superfície de leitura no cliente só para mostrar
 * números. Aqui o cliente só recebe os totais, e só o admin.
 */
export const getAdminStats = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "É preciso estar logado.");
  }
  if (!isAdminToken(request.auth.token)) {
    throw new HttpsError("permission-denied", "Acesso restrito ao administrador.");
  }
  const db = admin.firestore();
  const users = db.collection("users");
  const count = async (q: admin.firestore.Query) =>
    (await q.count().get()).data().count;

  const [
    totalUsers,
    totalStudents,
    totalInstructors,
    totalNutritionists,
    totalExercises,
    totalWorkoutsLogged,
    activeSubscriptions,
  ] = await Promise.all([
    count(users),
    count(users.where("role", "==", "student")),
    count(users.where("role", "==", "instructor")),
    count(users.where("role", "==", "nutritionist")),
    count(db.collection("exercises")),
    count(db.collectionGroup("workouts")),
    count(db.collectionGroup("finance").where("status", "==", "authorized")),
  ]);

  return {
    totalUsers,
    totalStudents,
    totalInstructors,
    totalNutritionists,
    totalExercises,
    totalWorkoutsLogged,
    activeSubscriptions,
  };
});

const ROLES = ["student", "instructor", "nutritionist"] as const;
type Role = (typeof ROLES)[number];

/**
 * Único caminho para mudar o papel de um usuário (só o admin). As regras do
 * Firestore não deixam NENHUM cliente — nem o admin — gravar `role`
 * diretamente, justamente para que rebaixar um instrutor sempre passe por
 * aqui.
 *
 * Por quê: o acesso de um instrutor aos dados de um aluno vem do
 * `instructorId` no perfil do ALUNO, não do papel do instrutor. Mudar só o
 * `role` deixava o ex-instrutor com acesso a todos os alunos antigos
 * (confirmado no emulador).
 *
 * Rebaixar um instrutor (instructor → qualquer outro papel):
 *  1. trava: grava `pendingRoleChange` no perfil dele — a partir daí
 *     `linkToProfessional` recusa vínculos novos com ele (a gravação do
 *     vínculo roda numa transação que relê este documento);
 *  2. encerra todos os vínculos de instrutor dele em lotes
 *     (`revokeInstructorLinks`), preservando o histórico dos alunos;
 *  3. SÓ ENTÃO grava o novo papel e tira a trava.
 * Se algo falhar no passo 2, o papel continua "instructor" (com a trava) e
 * o admin vê o erro; chamar de novo termina o serviço (idempotente). Nunca
 * sobra um usuário com papel de não-instrutor ainda vinculado a alunos.
 *
 * Só mexe em vínculos de INSTRUTOR (`instructorId`); `nutritionistId` e os
 * vínculos de nutrição não são tocados. Voltar a ser instrutor não
 * restaura vínculos antigos — os alunos se vinculam de novo pelo código.
 */
export const setUserRole = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "É preciso estar logado.");
  }
  if (!isAdminToken(request.auth.token)) {
    throw new HttpsError("permission-denied", "Acesso restrito ao administrador.");
  }
  const uid = request.data?.uid as string | undefined;
  const role = request.data?.role as string | undefined;
  if (!uid || typeof uid !== "string" || !ROLES.includes(role as Role)) {
    throw new HttpsError("invalid-argument", "Usuário ou papel inválido.");
  }

  const revokedStudents = await applyUserRole(admin.firestore(), uid, role as Role);
  return { ok: true, role, revokedStudents };
});

/**
 * Núcleo de toda mudança de papel — usado por `setUserRole` (promoção/
 * rebaixamento direto pelo admin) e por `reviewProfessionalRequest`
 * (aprovação de pedido). Ver o comentário de `setUserRole` para a ordem
 * trava → revogação em lotes → papel.
 *
 * A gravação FINAL do papel roda numa transação. [options.finalize] roda
 * dentro dela, antes da gravação do papel, recebendo o perfil lido na
 * transação — é onde a aprovação confere o pedido e grava o status, para
 * papel e pedido mudarem juntos (tudo ou nada). O `finalize` deve fazer
 * todas as leituras antes de qualquer gravação (regra das transações).
 *
 * Com [options.allowRevocation] = false, recusa qualquer mudança que
 * exigiria encerrar vínculos de instrutor (a aprovação de pedido nunca deve
 * rebaixar ninguém).
 *
 * Devolve quantos alunos foram desvinculados.
 */
export async function applyUserRole(
  db: admin.firestore.Firestore,
  uid: string,
  role: Role,
  options: {
    allowRevocation?: boolean;
    finalize?: (
      tx: admin.firestore.Transaction,
      userSnap: admin.firestore.DocumentSnapshot
    ) => Promise<void>;
  } = {}
): Promise<number> {
  const userRef = db.collection("users").doc(uid);
  const snap = await userRef.get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Usuário não encontrado.");
  }
  const currentRole = (snap.data()?.role as string | undefined) ?? "student";

  let revokedStudents = 0;
  if (currentRole === "instructor" && role !== "instructor") {
    if (options.allowRevocation === false) {
      throw new HttpsError(
        "failed-precondition",
        "Esta operação não pode tirar alguém do papel de instrutor."
      );
    }
    await userRef.update({ pendingRoleChange: role });
    try {
      revokedStudents = await revokeInstructorLinks(db, uid);
    } catch (e) {
      console.error(`Falha ao encerrar vínculos de ${uid}`, e);
      throw new HttpsError(
        "internal",
        "Não foi possível encerrar todos os vínculos deste instrutor. O papel " +
          "NÃO foi alterado — tente de novo para concluir."
      );
    }
  }

  await db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    if (options.finalize) await options.finalize(tx, userSnap);
    tx.update(userRef, {
      role,
      pendingRoleChange: admin.firestore.FieldValue.delete(),
    });
  });
  return revokedStudents;
}

const PROFESSIONAL_REQUESTS = "professional_requests";
const PROFESSIONAL_KINDS = ["instructor", "nutritionist"] as const;
type ProfessionalKind = (typeof PROFESSIONAL_KINDS)[number];

/**
 * O admin aprova ou recusa o pedido de um usuário para virar personal
 * (`instructor`) ou nutricionista (`nutritionist`) — o admin confere o
 * CREF/CRN manualmente no site do conselho antes de decidir.
 *
 * Recebe `{ uid, decision: "approve" | "reject", reason? }`; `reason` é
 * obrigatório (1 a 500 caracteres) na recusa.
 *
 * Aprovar: o papel (em `users`) e o status do pedido (`approved`,
 * `reviewedAt`, `reviewedBy`) são gravados na MESMA transação, via
 * `applyUserRole` — nunca fica papel mudado com pedido pendente, nem o
 * contrário. Só aprova quem hoje é aluno (ou já tem exatamente o papel
 * pedido, caso em que só marca o pedido); quem já é o OUTRO tipo de
 * profissional é recusado — isso é troca de papel, feita no painel.
 *
 * Recusar: grava `rejected` + motivo; o papel não muda.
 *
 * Nos dois casos uma cópia vai para `professional_requests/{uid}/history`
 * (o documento principal pode ser apagado pelo dono para pedir de novo).
 *
 * Idempotente: repetir a mesma decisão devolve ok sem refazer nada; uma
 * decisão contrária à já tomada é recusada (`failed-precondition`).
 */
export const reviewProfessionalRequest = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "É preciso estar logado.");
  }
  if (!isAdminToken(request.auth.token)) {
    throw new HttpsError("permission-denied", "Acesso restrito ao administrador.");
  }
  const reviewerUid = request.auth.uid;
  const uid = request.data?.uid as unknown;
  const decision = request.data?.decision as unknown;
  const rawReason = request.data?.reason as unknown;
  if (typeof uid !== "string" || !uid.trim()) {
    throw new HttpsError("invalid-argument", "Usuário inválido.");
  }
  if (decision !== "approve" && decision !== "reject") {
    throw new HttpsError("invalid-argument", "Decisão inválida.");
  }
  const reason = typeof rawReason === "string" ? rawReason.trim() : "";
  if (decision === "reject" && (reason.length < 1 || reason.length > 500)) {
    throw new HttpsError(
      "invalid-argument",
      "Informe o motivo da recusa (1 a 500 caracteres)."
    );
  }

  const db = admin.firestore();
  const requestRef = db.collection(PROFESSIONAL_REQUESTS).doc(uid);
  const snap = await requestRef.get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Pedido não encontrado.");
  }
  const target = decision === "approve" ? "approved" : "rejected";
  const currentStatus = snap.data()?.status as string | undefined;
  if (currentStatus !== "pending") {
    if (currentStatus === target) return { ok: true, status: target, unchanged: true };
    throw new HttpsError(
      "failed-precondition",
      "Este pedido já foi decidido de outra forma."
    );
  }

  const reviewedAt = admin.firestore.FieldValue.serverTimestamp();
  const historyRef = requestRef.collection("history").doc();

  /** Lê o pedido dentro da transação e confirma que continua pendente. */
  async function readPending(tx: admin.firestore.Transaction) {
    const fresh = await tx.get(requestRef);
    const data = fresh.data();
    if (!data) throw new HttpsError("not-found", "Pedido não encontrado.");
    if (data.status !== "pending") {
      throw new HttpsError(
        "failed-precondition",
        "Este pedido já foi decidido — atualize a lista."
      );
    }
    return data;
  }

  if (decision === "reject") {
    await db.runTransaction(async (tx) => {
      const data = await readPending(tx);
      const decided = {
        status: "rejected",
        rejectionReason: reason,
        reviewedAt,
        reviewedBy: reviewerUid,
      };
      tx.update(requestRef, decided);
      tx.set(historyRef, { ...data, ...decided });
    });
    return { ok: true, status: "rejected" };
  }

  const kind = snap.data()?.kind as string;
  if (!PROFESSIONAL_KINDS.includes(kind as ProfessionalKind)) {
    throw new HttpsError("failed-precondition", "Tipo de pedido inválido.");
  }

  await applyUserRole(db, uid, kind as ProfessionalKind, {
    allowRevocation: false,
    finalize: async (tx, userSnap) => {
      // Leituras primeiro (pedido); depois as gravações.
      const data = await readPending(tx);
      const role = (userSnap.data()?.role as string | undefined) ?? "student";
      if (role !== "student" && role !== kind) {
        throw new HttpsError(
          "failed-precondition",
          "Este usuário já é outro tipo de profissional — use a troca de " +
            "papel no painel."
        );
      }
      const decided = { status: "approved", reviewedAt, reviewedBy: reviewerUid };
      tx.update(requestRef, decided);
      tx.set(historyRef, { ...data, ...decided });
    },
  });
  return { ok: true, status: "approved" };
});
