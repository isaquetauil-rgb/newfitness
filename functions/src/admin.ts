import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { revokeInstructorLinks } from "./linking";

/**
 * E-mail do dono do app — o MESMO de `isAdmin()` em `firestore.rules` e de
 * `ownerEmail` em `lib/core/constants/admin_config.dart`. Os três precisam
 * mudar juntos.
 */
export const ADMIN_EMAIL = "isaquetrabalho005@gmail.com";

/** Mesmo critério das regras: e-mail do token igual ao do dono. */
export function isAdminToken(
  token: { email?: string } | undefined
): boolean {
  return (
    typeof token?.email === "string" &&
    token.email.toLowerCase() === ADMIN_EMAIL.toLowerCase()
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

  const db = admin.firestore();
  const userRef = db.collection("users").doc(uid);
  const snap = await userRef.get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Usuário não encontrado.");
  }
  const currentRole = (snap.data()?.role as string | undefined) ?? "student";

  let revokedStudents = 0;
  if (currentRole === "instructor" && role !== "instructor") {
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

  await userRef.update({
    role,
    pendingRoleChange: admin.firestore.FieldValue.delete(),
  });
  return { ok: true, role, revokedStudents };
});
