// Exportar meus dados (LGPD): o usuário logado baixa uma cópia dos PRÓPRIOS
// dados — perfil (com PAR-Q e aceites), treinos e recordes, avaliações
// físicas, triagens de saúde, refeições, planos de treino e de nutrição e as
// fotos.
//
// Saída: UM arquivo ZIP com `dados.json` (tudo), `treinos.csv` (uma linha por
// série) e a pasta `fotos/` com os arquivos das fotos (até
// [EXPORT_PHOTOS_LIMIT_BYTES]; o que passar fica de fora e o app avisa).
// Gravado em `users/{uid}/exports/` no Storage (pasta privada, ver
// storage.rules). Devolve um link assinado do ZIP, que vale 1 hora (é só
// para baixar: o conteúdo do ZIP não expira).
// Limite: 1 exportação por dia (fuso de São Paulo), controlado em
// `users/{uid}/data_exports/{yyyy-MM-dd}` (só a Function grava).
import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import JSZip from "jszip";
import { periodKey } from "./ai_guard";

/** Validade do link de download do ZIP. */
export const EXPORT_LINK_MS = 60 * 60 * 1000;

/** Soma máxima das fotos dentro do ZIP (o resto fica de fora, com aviso). */
export const EXPORT_PHOTOS_LIMIT_BYTES = 100 * 1024 * 1024;
let photosLimitBytes = EXPORT_PHOTOS_LIMIT_BYTES;

/** Só para testes: troca o limite de tamanho das fotos. */
export function setExportPhotosLimit(bytes?: number): void {
  photosLimitBytes = bytes ?? EXPORT_PHOTOS_LIMIT_BYTES;
}

/**
 * Caminho no Storage de uma foto do usuário: o `storagePath` do documento
 * ou, nas refeições, o caminho dentro do link de download
 * (`.../o/<caminho codificado>?...`). Só aceita a pasta do próprio usuário.
 */
export function photoStoragePath(uid: string, doc: Record<string, unknown>): string | null {
  let path: string | null = null;
  if (typeof doc.storagePath === "string") path = doc.storagePath;
  else if (typeof doc.imageUrl === "string") {
    const m = /\/o\/([^?]+)/.exec(doc.imageUrl);
    if (m) {
      try {
        path = decodeURIComponent(m[1]);
      } catch {
        path = null;
      }
    }
  }
  return path && path.startsWith(`users/${uid}/`) && !path.includes("..") ? path : null;
}

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

/** Duração máxima de treinos antigos (gravados sem a hora das séries). */
export const LEGACY_MAX_DURATION_SECONDS = 3 * 60 * 60;

/**
 * Duração do treino, com a MESMA regra do app
 * (`effectiveDurationSeconds` em lib/features/workout/logic/workout_timing.dart):
 * treinos novos já gravam a duração até a última série concluída (+ o
 * descanso dela); treinos antigos, sem a hora das séries (`completedAt`),
 * ficam limitados a 3 horas — um treino esquecido aberto não vira uma
 * sessão de dias na planilha.
 */
export function effectiveDurationSeconds(data: Record<string, unknown>): number {
  const raw = typeof data.durationSeconds === "number" ? data.durationSeconds : 0;
  if (!(raw > 0)) return 0;
  const exercises = Array.isArray(data.exercises) ? data.exercises : [];
  const hasTimes = exercises.some((e) => {
    const sets = (e as Record<string, unknown> | null)?.sets;
    return (
      Array.isArray(sets) &&
      sets.some((s) => typeof (s as Record<string, unknown> | null)?.completedAt === "number")
    );
  });
  return hasTimes ? raw : Math.min(raw, LEGACY_MAX_DURATION_SECONDS);
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
    const seconds = effectiveDurationSeconds(data);
    const minutes = seconds > 0 ? String(Math.round(seconds / 60)) : "";
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

export const exportMyData = onCall({ timeoutSeconds: 540, memory: "1GiB" }, async (request) => {
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
    const zip = new JSZip();

    // Fotos (corporais e de refeição) dentro do ZIP, até o limite de tamanho.
    // Cada registro no JSON ganha `arquivo` (caminho dentro do ZIP) ou
    // `foraDoZip: true` (passou do limite) / `arquivoIndisponivel: true`.
    let photosBytes = 0;
    let photosIncluded = 0;
    let photosOmitted = 0;
    const photoGroups: Array<[string, string]> = [
      ["fotosCorporais", "fotos/corporais"],
      ["refeicoes", "fotos/refeicoes"],
    ];
    for (const [key, folderInZip] of photoGroups) {
      for (const photo of result[key] as Array<Record<string, unknown>>) {
        const path = photoStoragePath(uid, photo);
        if (!path) continue;
        const file = bucket.file(path);
        try {
          const [meta] = await file.getMetadata();
          const size = Number(meta.size ?? 0);
          if (photosBytes + size > photosLimitBytes) {
            photo.foraDoZip = true;
            photosOmitted++;
            continue;
          }
          const [bytes] = await file.download();
          const ext = (path.match(/\.([a-zA-Z0-9]{2,5})$/)?.[1] ?? "jpg").toLowerCase();
          const name = `${folderInZip}/${String(photo.id)}.${ext}`;
          zip.file(name, bytes, { compression: "STORE" });
          photo.arquivo = name;
          photosBytes += size;
          photosIncluded++;
        } catch {
          photo.arquivoIndisponivel = true;
        }
      }
    }

    zip.file("dados.json", JSON.stringify(result, null, 2));
    zip.file("treinos.csv", workoutsCsv(raw.treinos));
    const content = await zip.generateAsync({
      type: "nodebuffer",
      compression: "DEFLATE",
      compressionOptions: { level: 6 },
    });

    // Só uma exportação guardada por usuário: apaga as anteriores.
    const folder = `users/${uid}/exports/`;
    await bucket.deleteFiles({ prefix: folder }).catch(() => undefined);

    const stamp = periodKey("day", now);
    const zipFile = bucket.file(`${folder}${stamp}/meus-dados-newfitness.zip`);
    await zipFile.save(content, { contentType: "application/zip", resumable: false });
    const zipUrl = await signUrl(zipFile, expiresAt);

    await reservation.set(
      {
        status: "done",
        finishedAt: Date.now(),
        workouts: raw.treinos.length,
        photos: photosIncluded,
        photosOmitted,
        sizeBytes: content.length,
      },
      { merge: true }
    );
    return {
      zipUrl,
      expiresAt,
      workouts: raw.treinos.length,
      photos: photosIncluded,
      photosOmitted,
      sizeBytes: content.length,
    };
  } catch (error) {
    // Falhou: libera o dia para tentar de novo.
    await reservation.delete().catch(() => undefined);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "Não foi possível exportar seus dados. Tente de novo.");
  }
});
