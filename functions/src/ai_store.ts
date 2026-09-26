import * as admin from "firebase-admin";
import { HttpsError } from "firebase-functions/v2/https";

/**
 * Gravações das Functions de IA no Firestore/Storage — o cliente não pode
 * gravar respostas da IA (regras do Firestore), só o servidor.
 */

/**
 * Grava a resposta da IA no chat geral DO PRÓPRIO usuário
 * (`users/{uid}/chat_messages`), com `role: "assistant"`.
 */
export async function saveChatReply(uid: string, reply: string): Promise<string> {
  const content = reply.trim() || "Desculpe, não consegui responder agora.";
  await admin
    .firestore()
    .collection("users")
    .doc(uid)
    .collection("chat_messages")
    .add({ role: "assistant", content, createdAt: Date.now() });
  return content;
}

export const MEAL_IMAGE_TYPES = ["image/jpeg", "image/png", "image/webp"];
export const MAX_MEAL_IMAGE_BYTES = 5 * 1024 * 1024;

/**
 * Caminho no Storage a partir da URL de download gravada pelo app
 * (`.../o/<caminho codificado>?alt=media&token=...`). Só aceita arquivos
 * da pasta de refeições do próprio usuário.
 */
export function mealPhotoStoragePath(uid: string, imageUrl: unknown): string | null {
  if (typeof imageUrl !== "string") return null;
  const match = /\/o\/([^?#]+)/.exec(imageUrl);
  if (!match) return null;
  let path: string;
  try {
    path = decodeURIComponent(match[1]);
  } catch {
    return null;
  }
  if (!path.startsWith(`users/${uid}/meal_photos/`) || path.includes("..")) {
    return null;
  }
  return path;
}

/**
 * Baixa a foto da refeição do bucket padrão (Admin SDK), validando tipo
 * (jpeg/png/webp) e tamanho (até 5 MB) ANTES do download.
 */
export async function loadMealImage(
  path: string
): Promise<{ data: string; mediaType: string }> {
  const file = admin.storage().bucket().file(path);
  let metadata: { contentType?: string; size?: string | number };
  try {
    [metadata] = await file.getMetadata();
  } catch {
    throw new HttpsError("not-found", "A foto não foi encontrada no armazenamento.");
  }
  const mediaType = String(metadata.contentType ?? "");
  if (!MEAL_IMAGE_TYPES.includes(mediaType)) {
    throw new HttpsError(
      "invalid-argument",
      "Formato de foto não suportado (use JPEG, PNG ou WebP)."
    );
  }
  if (Number(metadata.size ?? 0) > MAX_MEAL_IMAGE_BYTES) {
    throw new HttpsError("invalid-argument", "A foto passa de 5 MB.");
  }
  const [buffer] = await file.download();
  return { data: buffer.toString("base64"), mediaType };
}
