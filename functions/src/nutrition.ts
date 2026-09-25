import * as admin from "firebase-admin";

/**
 * Grava a resposta da IA na conversa de nutrição DO PRÓPRIO usuário
 * (`users/{uid}/nutrition_chat`), com `role: "assistant"`.
 *
 * Só o servidor escreve mensagens `assistant` — as regras do Firestore não
 * deixam nenhum cliente criar esse papel. Antes o app gravava a resposta
 * que recebia da Function, o que permitia a qualquer aluno forjar uma
 * "resposta da IA" na conversa que a nutricionista acompanha.
 */
export async function saveNutritionReply(
  uid: string,
  reply: string
): Promise<string> {
  const content = reply.trim() || "Desculpe, não consegui responder agora.";
  await admin
    .firestore()
    .collection("users")
    .doc(uid)
    .collection("nutrition_chat")
    .add({ role: "assistant", content, createdAt: Date.now() });
  return content;
}
