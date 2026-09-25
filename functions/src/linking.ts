import * as admin from "firebase-admin";
import { randomInt } from "crypto";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { ChunkedWriter } from "./chunked_writer";

type ProfessionalKind = "instructor" | "nutritionist";

/**
 * Alfabeto dos códigos de convite — sem O/0/I/1 (evita confusão ao digitar).
 * 32 símbolos × 8 posições ≈ 1,1 × 10^12 combinações.
 */
const CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const CODE_LENGTH = 8;

/** Coleção de reservas: `invite_codes/{code}` → `{ uid, kind }`. */
const INVITE_CODES = "invite_codes";

function isProfessional(role: unknown): role is ProfessionalKind {
  return role === "instructor" || role === "nutritionist";
}

/** Gera um código com `crypto.randomInt` (CSPRNG), nunca `Math.random`. */
export function generateInviteCode(): string {
  let code = "";
  for (let i = 0; i < CODE_LENGTH; i++) {
    code += CODE_ALPHABET[randomInt(CODE_ALPHABET.length)];
  }
  return code;
}

/**
 * Garante que o profissional logado (instrutor/nutricionista) tenha um
 * código de convite — e devolve esse código. É o ÚNICO caminho pelo qual um
 * `inviteCode` é gravado (as regras do Firestore proíbem o cliente de
 * definir ou alterar o próprio código; ver `users/{userId}` em
 * `firestore.rules`).
 *
 * Unicidade: cada código é reservado em `invite_codes/{code}` dentro de uma
 * transação — se o documento já existe, o código é descartado e outro é
 * sorteado. A coleção é inacessível para o cliente.
 *
 * Idempotente: chamar de novo devolve o mesmo código.
 *
 * Códigos antigos (gerados no cliente antes desta função existir) são
 * reservados para o dono se — e só se — nenhum outro usuário tiver o mesmo
 * código; caso contrário o profissional recebe um código novo (um código
 * duplicado seria justamente o caso de alguém ter copiado o de outro).
 */
export const ensureInviteCode = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "É preciso estar logado.");
  }
  const uid = request.auth.uid;
  const db = admin.firestore();
  const userRef = db.collection("users").doc(uid);

  const existing = await userRef.get();
  const data = existing.data();
  if (!data) {
    throw new HttpsError(
      "failed-precondition",
      "Perfil do usuário não encontrado."
    );
  }
  if (!isProfessional(data.role)) {
    throw new HttpsError(
      "permission-denied",
      "Só instrutores e nutricionistas têm código de convite."
    );
  }
  const kind = data.role;

  // Código antigo, sem reserva: só é mantido se for exclusivo deste usuário.
  const legacyCode =
    typeof data.inviteCode === "string" && data.inviteCode ? data.inviteCode : null;
  if (legacyCode) {
    const owners = await db
      .collection("users")
      .where("inviteCode", "==", legacyCode)
      .limit(2)
      .get();
    const exclusive = owners.size === 1 && owners.docs[0].id === uid;
    const kept = await db.runTransaction(async (tx) => {
      const reservationRef = db.collection(INVITE_CODES).doc(legacyCode);
      const reservation = await tx.get(reservationRef);
      if (reservation.exists) {
        return reservation.data()?.uid === uid;
      }
      if (!exclusive) return false;
      tx.create(reservationRef, { uid, kind, createdAt: Date.now() });
      return true;
    });
    if (kept) return { code: legacyCode };
  }

  for (let attempt = 0; attempt < 5; attempt++) {
    const code = generateInviteCode();
    const reserved = await db.runTransaction(async (tx) => {
      const reservationRef = db.collection(INVITE_CODES).doc(code);
      const user = await tx.get(userRef);
      // Outra chamada concorrente já gravou um código válido: reaproveita.
      const current = user.data()?.inviteCode;
      if (typeof current === "string" && current && current !== legacyCode) {
        const currentReservation = await tx.get(
          db.collection(INVITE_CODES).doc(current)
        );
        if (currentReservation.data()?.uid === uid) return current;
      }
      if ((await tx.get(reservationRef)).exists) return null;
      tx.create(reservationRef, { uid, kind, createdAt: Date.now() });
      tx.update(userRef, { inviteCode: code });
      return code;
    });
    if (reserved) return { code: reserved };
  }
  throw new HttpsError("internal", "Não foi possível gerar o código. Tente de novo.");
});

/**
 * Encontra o profissional dono de [code]. Fonte principal: a reserva em
 * `invite_codes` (única por construção). Para códigos antigos ainda sem
 * reserva, aceita a busca em `users` só quando há EXATAMENTE um dono — um
 * código duplicado é recusado em vez de vincular o aluno a quem copiou.
 */
async function resolveProfessional(
  db: admin.firestore.Firestore,
  kind: ProfessionalKind,
  code: string
): Promise<admin.firestore.DocumentSnapshot | null> {
  const reservation = await db.collection(INVITE_CODES).doc(code).get();
  if (reservation.exists) {
    const ownerUid = reservation.data()?.uid as string | undefined;
    if (!ownerUid) return null;
    const owner = await db.collection("users").doc(ownerUid).get();
    const ownerData = owner.data();
    // O dono precisa continuar com o papel certo e com este mesmo código
    // (ex: um instrutor rebaixado a aluno deixa de receber vínculos).
    if (!ownerData || !canReceiveLinks(ownerData, kind, code)) return null;
    return owner;
  }

  const matches = await db
    .collection("users")
    .where("inviteCode", "==", code)
    .limit(2)
    .get();
  if (matches.size !== 1) return null;
  const only = matches.docs[0];
  return canReceiveLinks(only.data(), kind, code) ? only : null;
}

/**
 * O profissional pode receber um vínculo agora? Papel certo, o mesmo
 * código, e nenhuma troca de papel em andamento (ver `setUserRole` em
 * `admin.ts`: enquanto um instrutor está sendo rebaixado, os vínculos dele
 * estão sendo encerrados — um vínculo novo nesse meio tempo sobreviveria
 * ao rebaixamento).
 */
function canReceiveLinks(
  data: admin.firestore.DocumentData,
  kind: ProfessionalKind,
  code: string
): boolean {
  return (
    data.role === kind &&
    data.inviteCode === code &&
    (data.pendingRoleChange === undefined || data.pendingRoleChange === null)
  );
}

/**
 * Vincula o usuário autenticado (sempre um aluno) a um instrutor ou
 * nutricionista, validando o código de convite inteiramente no servidor
 * (Admin SDK, que ignora `firestore.rules`) antes de gravar `instructorId`/
 * `nutritionistId`.
 *
 * Por quê isso não pode ser feito direto do app: `firestore.rules` proíbe o
 * próprio usuário de mudar esses dois campos (ver `users/{userId}`) —
 * exatamente para impedir que um aluno se auto-vincule a um instrutor sem um
 * código válido e ganhe, através disso, acesso de leitura/escrita sobre os
 * próprios dados via as regras que confiam nesse campo (`workouts`,
 * `progress_records`, `physical_assessments`, `training_plans`,
 * `appointments`). Esta função é o único caminho (além do admin) que pode
 * gravar esses campos.
 *
 * Troca de profissional: o vínculo vigente é SEMPRE o campo do perfil do
 * aluno (`instructorId`/`nutritionistId`) — é por ele que as regras dão
 * acesso e que a lista de alunos do profissional é montada. A entrada
 * denormalizada no profissional anterior (`students/{uid}`, que guarda as
 * notas/mensalidade DELE sobre o aluno) não é apagada, só marcada como
 * inativa. Nenhum dado do aluno (treinos, avaliações, fotos) é tocado.
 */
export const linkToProfessional = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "É preciso estar logado.");
  }
  const uid = request.auth.uid;
  const kind = request.data?.kind as ProfessionalKind | undefined;
  const rawCode = request.data?.code as string | undefined;
  if ((kind !== "instructor" && kind !== "nutritionist") || !rawCode?.trim()) {
    throw new HttpsError("invalid-argument", "Dados inválidos.");
  }
  const code = rawCode.trim().toUpperCase();

  const db = admin.firestore();

  const callerSnap = await db.collection("users").doc(uid).get();
  const callerData = callerSnap.data();
  if (!callerData) {
    throw new HttpsError(
      "failed-precondition",
      "Perfil do usuário não encontrado."
    );
  }
  // Só uma conta de aluno pode se vincular — impede que um instrutor (ou o
  // próprio admin, ou uma conta que se autopromoveu) use este caminho para
  // ganhar acesso de leitura sobre outra conta.
  if (callerData.role !== "student") {
    throw new HttpsError(
      "permission-denied",
      "Só uma conta de aluno pode se vincular a um instrutor ou nutricionista."
    );
  }

  const professionalDoc = await resolveProfessional(db, kind, code);
  if (!professionalDoc) {
    const label = kind === "instructor" ? "instrutor" : "nutricionista";
    throw new HttpsError("invalid-argument", `Código de ${label} inválido.`);
  }
  const professionalUid = professionalDoc.id;
  if (professionalUid === uid) {
    throw new HttpsError(
      "invalid-argument",
      "Você não pode se vincular a si mesmo."
    );
  }

  const { field, listCollection } = linkNames(kind);
  const professionalRef = db.collection("users").doc(professionalUid);
  const callerRef = db.collection("users").doc(uid);

  // Transação que RELÊ o profissional: se o admin começar a rebaixá-lo
  // (grava `pendingRoleChange` no mesmo documento) entre a validação acima
  // e esta gravação, a transação é refeita, vê a trava e recusa — nenhum
  // vínculo novo escapa do encerramento feito pelo rebaixamento.
  const previousUid = await db.runTransaction(async (tx) => {
    const [professional, caller] = await Promise.all([
      tx.get(professionalRef),
      tx.get(callerRef),
    ]);
    const professionalData = professional.data();
    if (!professionalData || !canReceiveLinks(professionalData, kind, code)) {
      const label = kind === "instructor" ? "instrutor" : "nutricionista";
      throw new HttpsError("invalid-argument", `Código de ${label} inválido.`);
    }
    const previous = caller.data()?.[field] as string | undefined | null;
    tx.set(callerRef, { [field]: professionalUid }, { merge: true });
    tx.set(
      professionalRef.collection(listCollection).doc(uid),
      {
        name: (callerData.name as string | undefined) ?? "",
        email: (callerData.email as string | undefined) ?? "",
        linkedAt: Date.now(),
        active: true,
      },
      { merge: true }
    );
    if (previous && previous !== professionalUid) {
      tx.set(
        db.collection("users").doc(previous).collection(listCollection).doc(uid),
        { active: false, unlinkedAt: Date.now() },
        { merge: true }
      );
    }
    return previous ?? null;
  });

  // Agenda: compromissos de qualquer outro instrutor deixam de conceder
  // acesso (idempotente — rodar de novo não muda nada).
  if (kind === "instructor") {
    const writer = new ChunkedWriter(db);
    await detachStudentAgenda(db, writer, uid, professionalUid);
    await writer.flush();
  }

  return {
    ok: true,
    name: (professionalDoc.data()?.name as string | undefined) ?? "",
    previousUid,
  };
});

function linkNames(kind: ProfessionalKind) {
  return kind === "instructor"
    ? { field: "instructorId", listCollection: "students" }
    : { field: "nutritionistId", listCollection: "nutrition_students" };
}

/**
 * Agenda do aluno [studentUid]: todo compromisso cujo `instructorUid` NÃO
 * seja [keepInstructorUid] (o instrutor atual; `null` = nenhum) passa a
 * guardar o instrutor em `formerInstructorUid`. A regra de collection group
 * de `appointments` libera leitura por `instructorUid` e não consegue
 * consultar o vínculo atual dentro de uma consulta (testado no emulador),
 * então o campo que concede acesso é o que muda. O compromisso em si
 * (título, data, status) continua com o aluno.
 *
 * Idempotente: só mexe no que ainda aponta para outro instrutor.
 */
export async function detachStudentAgenda(
  db: admin.firestore.Firestore,
  writer: ChunkedWriter,
  studentUid: string,
  keepInstructorUid: string | null
): Promise<void> {
  const appointments = await db
    .collection("users")
    .doc(studentUid)
    .collection("appointments")
    .get();
  for (const appointment of appointments.docs) {
    const instructorUid = appointment.data().instructorUid as string | undefined;
    if (!instructorUid || instructorUid === keepInstructorUid) continue;
    await writer.update(appointment.ref, {
      instructorUid: admin.firestore.FieldValue.delete(),
      formerInstructorUid: instructorUid,
    });
  }
}

/**
 * Encerra TODOS os vínculos de instrutor de [instructorUid] — usado quando
 * o admin rebaixa um instrutor (`setUserRole` em `admin.ts`). Só mexe em
 * `instructorId`; `nutritionistId` e qualquer dado dos alunos ficam
 * intactos.
 *
 * Processa em páginas ([pageSize] alunos) e grava em lotes ([maxOps]
 * operações) — sem limite de quantidade de alunos. Para cada aluno, a
 * PRIMEIRA gravação é zerar o `instructorId` (é o que concede acesso nas
 * regras); depois a entrada antiga em `students` fica inativa e a agenda é
 * desligada.
 *
 * Idempotente: se parar no meio (falha, timeout), rodar de novo termina o
 * serviço — a página seguinte é sempre "quem ainda aponta para ele", e as
 * duas varreduras finais (agenda por collection group e entradas em
 * `students`) pegam o que um aluno já desligado possa ter deixado para trás.
 *
 * Devolve quantos alunos foram desligados nesta execução.
 */
export async function revokeInstructorLinks(
  db: admin.firestore.Firestore,
  instructorUid: string,
  options: { pageSize?: number; maxOps?: number } = {}
): Promise<number> {
  const pageSize = options.pageSize ?? 200;
  const writer = new ChunkedWriter(db, options.maxOps);
  const users = db.collection("users");
  let revoked = 0;

  for (;;) {
    const page = await users
      .where("instructorId", "==", instructorUid)
      .limit(pageSize)
      .get();
    if (page.empty) break;
    for (const student of page.docs) {
      await writer.update(student.ref, { instructorId: null });
      await writer.set(
        users.doc(instructorUid).collection("students").doc(student.id),
        { active: false, unlinkedAt: Date.now() },
        { merge: true }
      );
      await detachStudentAgenda(db, writer, student.id, null);
      revoked++;
    }
    // A próxima página precisa ver estes alunos já desligados.
    await writer.flush();
  }

  // Agenda que ainda aponte para ele em qualquer aluno (ex: um aluno
  // desligado numa execução anterior que parou antes da agenda). Usa o
  // índice de collection group já existente (instructorUid + start).
  for (;;) {
    const leftovers = await db
      .collectionGroup("appointments")
      .where("instructorUid", "==", instructorUid)
      .orderBy("start")
      .limit(pageSize)
      .get();
    if (leftovers.empty) break;
    for (const appointment of leftovers.docs) {
      await writer.update(appointment.ref, {
        instructorUid: admin.firestore.FieldValue.delete(),
        formerInstructorUid: instructorUid,
      });
    }
    await writer.flush();
  }

  // Entradas dele sobre alunos ainda marcadas como ativas.
  const entries = await users.doc(instructorUid).collection("students").get();
  for (const entry of entries.docs) {
    if (entry.data().active === false) continue;
    await writer.set(entry.ref, { active: false, unlinkedAt: Date.now() }, { merge: true });
  }
  await writer.flush();
  return revoked;
}

/**
 * Desfaz o vínculo do aluno logado com o instrutor ou a nutricionista
 * (`kind`). Só o próprio aluno, só o próprio vínculo — o uid vem do token,
 * nunca do pedido. Depois disso nenhum profissional tem acesso por vínculo
 * (todas as regras dependem de `instructorId`/`nutritionistId` no perfil
 * do aluno). Nenhum dado do aluno é apagado.
 */
export const unlinkFromProfessional = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "É preciso estar logado.");
  }
  const uid = request.auth.uid;
  const kind = request.data?.kind as ProfessionalKind | undefined;
  if (kind !== "instructor" && kind !== "nutritionist") {
    throw new HttpsError("invalid-argument", "Dados inválidos.");
  }
  const db = admin.firestore();
  const userRef = db.collection("users").doc(uid);
  const caller = (await userRef.get()).data();
  if (!caller) {
    throw new HttpsError("failed-precondition", "Perfil do usuário não encontrado.");
  }
  if (caller.role !== "student") {
    throw new HttpsError(
      "permission-denied",
      "Só uma conta de aluno tem vínculo com instrutor ou nutricionista."
    );
  }
  const { field } = linkNames(kind);
  const previousUid = caller[field] as string | undefined | null;
  if (!previousUid) return { ok: true, changed: false };

  const { listCollection } = linkNames(kind);
  const writer = new ChunkedWriter(db);
  // Primeiro o que concede acesso (o campo no perfil do aluno).
  await writer.update(userRef, { [field]: null });
  await writer.set(
    db.collection("users").doc(previousUid).collection(listCollection).doc(uid),
    { active: false, unlinkedAt: Date.now() },
    { merge: true }
  );
  if (kind === "instructor") await detachStudentAgenda(db, writer, uid, null);
  await writer.flush();
  return { ok: true, changed: true };
});
