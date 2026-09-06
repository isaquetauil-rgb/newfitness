import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { anthropicApiKey, callClaude } from "./anthropic";

admin.initializeApp();

const SYSTEM_PROMPT =
  "Você é o assistente de fitness do app NewFitness. Responda sempre em " +
  "português do Brasil, de forma curta, direta e motivadora. Você pode " +
  "ajudar com dúvidas sobre treino, dieta, suplementação e hábitos " +
  "saudáveis. Você não é médico nem nutricionista — para questões " +
  "clínicas, sempre recomende procurar um profissional.";

/**
 * Chat de texto com a IA. Espera { messages: [{role, content}], history? }.
 * Exige usuário autenticado.
 */
export const chatWithAI = onCall(
  { secrets: [anthropicApiKey] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "É preciso estar logado.");
    }

    const message = request.data?.message as string | undefined;
    const history = (request.data?.history ?? []) as Array<{
      role: "user" | "assistant";
      content: string;
    }>;

    if (!message || message.trim().length === 0) {
      throw new HttpsError("invalid-argument", "Mensagem vazia.");
    }

    const reply = await callClaude({
      system: SYSTEM_PROMPT,
      messages: [...history, { role: "user", content: message }],
      maxTokens: 500,
    });

    return { reply };
  }
);

/**
 * Analisa uma foto de refeição (base64) e devolve um comentário nutricional
 * simples. Espera { imageBase64, mediaType, mealType }.
 */
export const analyzeMealPhoto = onCall(
  { secrets: [anthropicApiKey] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "É preciso estar logado.");
    }

    const imageBase64 = request.data?.imageBase64 as string | undefined;
    const mediaType = (request.data?.mediaType as string) ?? "image/jpeg";
    const mealType = (request.data?.mealType as string) ?? "refeição";

    if (!imageBase64) {
      throw new HttpsError("invalid-argument", "Imagem não enviada.");
    }

    const analysis = await callClaude({
      system: SYSTEM_PROMPT,
      messages: [
        {
          role: "user",
          content: [
            {
              type: "text",
              text:
                `Esta é uma foto do meu ${mealType}. Descreva rapidamente ` +
                "o que você identifica no prato e dê um comentário " +
                "nutricional breve (2-3 frases), sem inventar valores " +
                "calóricos exatos — apenas uma estimativa qualitativa " +
                "(ex: refeição rica em proteína, pouca fibra, etc).",
            },
            {
              type: "image",
              source: { type: "base64", media_type: mediaType, data: imageBase64 },
            },
          ],
        },
      ],
      maxTokens: 400,
    });

    return { analysis };
  }
);

/**
 * Analisa uma foto de evolução do corpo (base64) e devolve um comentário
 * observacional (não é diagnóstico nem avaliação médica).
 */
export const analyzeBodyPhoto = onCall(
  { secrets: [anthropicApiKey] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "É preciso estar logado.");
    }

    const imageBase64 = request.data?.imageBase64 as string | undefined;
    const mediaType = (request.data?.mediaType as string) ?? "image/jpeg";

    if (!imageBase64) {
      throw new HttpsError("invalid-argument", "Imagem não enviada.");
    }

    const analysis = await callClaude({
      system: SYSTEM_PROMPT,
      messages: [
        {
          role: "user",
          content: [
            {
              type: "text",
              text:
                "Esta é uma foto minha de acompanhamento de evolução " +
                "física. Dê um comentário breve, respeitoso e motivador " +
                "(2-3 frases) sobre postura/composição aparente, deixando " +
                "claro que não substitui avaliação de um profissional.",
            },
            {
              type: "image",
              source: { type: "base64", media_type: mediaType, data: imageBase64 },
            },
          ],
        },
      ],
      maxTokens: 400,
    });

    return { analysis };
  }
);
