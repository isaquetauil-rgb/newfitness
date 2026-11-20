// Exportar meus dados (LGPD): o usuário logado baixa uma cópia dos PRÓPRIOS
// dados — perfil (com PAR-Q e aceites), treinos e recordes, avaliações
// físicas, triagens de saúde, refeições, planos de treino e de nutrição e os
// links das fotos.
//
// Saída: `dados.json` (tudo) e `treinos.csv` (uma linha por série), gravados
// em `users/{uid}/exports/` no Storage (pasta privada: o cliente não lê nem
// grava, ver storage.rules). Devolve links assinados que valem 1 hora.
// Limite: 1 exportação por dia (fuso de São Paulo), controlado em
// `users/{uid}/data_exports/{yyyy-MM-dd}` (só a Function grava).
import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { periodKey } from "./ai_guard";

/** Validade dos links devolvidos. */
export const EXPORT_LINK_MS = 60 * 60 * 1000;

/** Subcoleções do usuário que entram na exportação (nome no JSON → coleção). */
export const EXPORTED_COLLECTIONS: Record<string, string> = {
  treinos: "workouts",
  recordes: "progress_records",
  avaliacoesFisicas: "physical_assessments",
  triagensDeSaude: "health_screenings",
  refeicoes: "meal_photos",
  planosDeTreino: "training_plans",
  planosDeNutricao: "nutrition_plans",
  fotosCorporais: "body_photos",
};

type StorageFile = ReturnType<ReturnType<admin.storage.Storage["bucket"]>["file"]>;
type UrlSigner = (file: StorageFile, expiresAt: number) => Promise<string>;

const defaultSigner: UrlSigner = async (file, expiresAt) => {
  const [url] = await file.getSignedUrl({ action: "read", expires: expiresAt });
  return url;
};
let signUrl: UrlSigner = defaultSigner;

/** Só para testes: troca a geração do link assinado (o emulador não assina). */
export function setExportUrlSigner(signer?: UrlSigner): void {
  signUrl = signer ?? defaultSigner;
}

/** Converte Timestamps do Firestore em texto ISO, recursivamente. */
export function toPlain(value: unknown): unknown {
  if (value instanceof admin.firestore.Timestamp) return value.toDate().toISOString();
  if (Array.isArray(value)) return value.map(toPlain);
  if (value && typeof value === "object") {
    const out: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
      out[k] = toPlain(v);
    }
    return out;
  }
  return value;
}

const SET_TYPE: Record<string, string> = {
  warmup: "Aquecimento",
  drop: "Drop",
  failure: "Até a falha",
};

/** "2026-11-20 18:30" no fuso de São Paulo. */
function localDateTime(ms: number): string {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "America/Sao_Paulo",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(new Date(ms));
  const get = (t: string) => parts.find((p) => p.type === t)?.value ?? "";
  return `${get("year")}-${get("month")}-${get("day")} ${get("hour")}:${get("minute")}`;
}

/** Número com vírgula decimal (Excel em português); vazio se não houver. */
function num(value: unknown): string {
  if (typeof value !== "number" || !Number.isFinite(value)) return "";
  return String(Math.round(value * 100) / 100).replace(".", ",");
}

function cell(value: string): string {
  return /[";\n\r]/.test(value) ? `"${value.replace(/"/g, '""')}"` : value;
}

export const CSV_HEADER = [
  "data",
  "treino",
  "duracao_min",
  "exercicio",
  "serie",
  "tipo",
  "repeticoes",
  "peso_kg",
  "segundos",
  "concluida",
  "id_treino",
  "id_exercicio",
];

/**
 * CSV dos treinos: uma linha por série, separado por ponto e vírgula, com
 * BOM (abre certo no Excel em português). Treinos do mais antigo para o
 * mais recente.
 */
export function workoutsCsv(workouts: Array<{ id: string; data: Record<string, unknown> }>): string {
  const rows: string[] = [CSV_HEADER.join(";")];
  const ordered = [...workouts].sort(
    (a, b) => ((a.data.date as number) ?? 0) - ((b.data.date as number) ?? 0)
  );
  for (const { id, data } of ordered) {
    const date = typeof data.date === "number" ? localDateTime(data.date) : "";
    const name = typeof data.name === "string" ? data.name : "Treino";
    const minutes =
      typeof data.durationSeconds === "number" && data.durationSeconds > 0
        ? String(Math.round(data.durationSeconds / 60))
        : "";
    const exercises = Array.isArray(data.exercises) ? data.exercises : [];
    for (const raw of exercises) {
      const ex = (raw ?? {}) as Record<string, unknown>;
      const sets = Array.isArray(ex.sets) ? ex.sets : [];
      sets.forEach((rawSet, i) => {
        const s = (rawSet ?? {}) as Record<string, unknown>;
        const seconds = typeof s.seconds === "number" && s.seconds > 0 ? String(s.seconds) : "";
        rows.push(
          [
            date,
            name,
            minutes,
            String(ex.exerciseName ?? ""),
            String(i + 1),
            SET_TYPE[String(s.type)] ?? "Normal",
            typeof s.reps === "number" ? String(s.reps) : "",
            num(s.weightKg),
            seconds,
            s.completed === true ? "sim" : "não",
            id,
            String(ex.exerciseId ?? ""),
          ]
            .map(cell)
            .join(";")
        );
      });
    }
  }
  return "﻿" + rows.join("\r\n") + "\r\n";
}

/** Reserva a exportação do dia; falha se já houver uma. */
async function reserveToday(uid: string, now: Date): Promise<FirebaseFirestore.DocumentReference> {
  const db = admin.firestore();
  const ref = db.doc(`users/${uid}/data_exports/${periodKey("day", now)}`);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (snap.exists) {
      throw new HttpsError(
        "resource-exhausted",
        "Você já exportou seus dados hoje. Tente de novo amanhã."
      );
    }
    tx.set(ref, { status: "started", startedAt: now.getTime() });
  });
  return ref;
}

export const exportMyData = onCall({ timeoutSeconds: 300, memory: "512MiB" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "É preciso estar logado.");
  }
  const now = new Date();
  const reservation = await reserveToday(uid, now);

  try {
    const db = admin.firestore();
    const userRef = db.doc(`users/${uid}`);
    const profileSnap = await userRef.get();

    const result: Record<string, unknown> = {
      exportadoEm: now.toISOString(),
      usuario: uid,
      perfil: profileSnap.exists ? toPlain(profileSnap.data()) : null,
    };
    const raw: Record<string, Array<{ id: string; data: Record<string, unknown> }>> = {};
    for (const [key, collection] of Object.entries(EXPORTED_COLLECTIONS)) {
      const snap = await userRef.collection(collection).get();
      raw[key] = snap.docs.map((d) => ({ id: d.id, data: d.data() }));
      result[key] = raw[key].map((d) => ({ id: d.id, ...(toPlain(d.data) as object) }));
    }

    const bucket = admin.storage().bucket();
    const expiresAt = now.getTime() + EXPORT_LINK_MS;

    // Fotos corporais: link assinado (1 h) do arquivo privado.
    const photos = result.fotosCorporais as Array<Record<string, unknown>>;
    for (const photo of photos) {
      const storagePath = photo.storagePath;
      if (typeof storagePath === "string" && storagePath.startsWith(`users/${uid}/`)) {
        try {
          photo.link = await signUrl(bucket.file(storagePath), expiresAt);
        } catch {
          photo.link = null;
        }
      }
    }

    // Só uma exportação guardada por usuário: apaga as anteriores.
    const folder = `users/${uid}/exports/`;
    await bucket.deleteFiles({ prefix: folder }).catch(() => undefined);

    const stamp = periodKey("day", now);
    const jsonFile = bucket.file(`${folder}${stamp}/dados.json`);
    const csvFile = bucket.file(`${folder}${stamp}/treinos.csv`);
    await jsonFile.save(JSON.stringify(result, null, 2), {
      contentType: "application/json; charset=utf-8",
      resumable: false,
    });
    await csvFile.save(workoutsCsv(raw.treinos), {
      contentType: "text/csv; charset=utf-8",
      resumable: false,
    });

    const [jsonUrl, csvUrl] = await Promise.all([
      signUrl(jsonFile, expiresAt),
      signUrl(csvFile, expiresAt),
    ]);
    await reservation.set(
      { status: "done", finishedAt: Date.now(), workouts: raw.treinos.length },
      { merge: true }
    );
    return { jsonUrl, csvUrl, expiresAt, workouts: raw.treinos.length };
  } catch (error) {
    // Falhou: libera o dia para tentar de novo.
    await reservation.delete().catch(() => undefined);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "Não foi possível exportar seus dados. Tente de novo.");
  }
});
