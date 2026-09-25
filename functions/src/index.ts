import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { WEB_SEARCH_TOOL, anthropicApiKey, callClaude } from "./anthropic";
import { assertAiUsageAllowed, incrementAiUsage } from "./plans";
import { saveNutritionReply } from "./nutrition";

admin.initializeApp();

export { createSubscriptionCheckout, mercadoPagoWebhook } from "./mercadopago";
export { setStudentPlanTier } from "./plans";
export {
  ensureInviteCode,
  linkToProfessional,
  unlinkFromProfessional,
} from "./linking";
export {
  getAdminStats,
  reviewProfessionalRequest,
  setUserRole,
} from "./admin";

const SYSTEM_PROMPT =
  "Você é o assistente de fitness do app NewFitness. Responda sempre em " +
  "português do Brasil, de forma curta, direta e motivadora. Você pode " +
  "ajudar com dúvidas sobre treino, dieta, suplementação e hábitos " +
  "saudáveis. Você não é médico nem nutricionista — para questões " +
  "clínicas, sempre recomende procurar um profissional.";

const NUTRITION_SYSTEM_PROMPT =
  "Você é um assistente de nutrição do app NewFitness, em português do " +
  "Brasil. Responda dúvidas do aluno sobre alimentação, hábitos, " +
  "hidratação e suplementação de forma curta e prática. Você tem acesso a " +
  "busca na web — use-a quando a pergunta depender de informação atual ou " +
  "específica (ex: valor nutricional de um alimento/produto, uma notícia " +
  "recente, um estudo) em vez de responder só de memória; cite a fonte " +
  "quando usar a busca. Uma resposta sua SEMPRE pode ser corrigida ou " +
  "complementada depois pela nutricionista vinculada ao aluno (ela vê a " +
  "conversa) — deixe claro quando o assunto for específico da condição de " +
  "saúde do aluno (restrição alimentar, condição clínica, medicação) que a " +
  "orientação definitiva é dela, não sua. Você não substitui uma consulta " +
  "nem prescreve dieta.";

const INSTRUCTOR_SYSTEM_PROMPT =
  "Você é um assistente de um personal trainer no app NewFitness, em " +
  "português do Brasil. O instrutor pode pedir ideias gerais de " +
  "exercícios/treinos, ou contexto sobre um aluno específico (ex: uma dor " +
  "ou limitação relatada). Você não substitui avaliação médica ou " +
  "fisioterapêutica — se o pedido envolver dor, lesão ou condição de saúde, " +
  "reflita isso no campo `reason` de cada sugestão (ex: evitar determinado " +
  "movimento, e recomendar avaliação profissional). " +
  "Responda SEMPRE com um array JSON puro, sem nenhum texto fora dele e " +
  "sem markdown, com 3 a 4 objetos no formato exato: " +
  '{"exerciseName": string, "sets": number, "reps": string (ex: "10-12"), ' +
  '"restSeconds": number, "reason": string curta (1-2 frases)}.';

interface ExerciseSuggestion {
  exerciseName: string;
  sets: number;
  reps: string;
  restSeconds: number;
  reason: string;
}

/** Extrai o primeiro array JSON de um texto (a IA às vezes envolve em
 * markdown ou acrescenta texto antes/depois, mesmo quando instruída a não
 * fazer isso). */
function extractJsonArray(text: string): string | null {
  const start = text.indexOf("[");
  const end = text.lastIndexOf("]");
  if (start === -1 || end === -1 || end < start) return null;
  return text.slice(start, end + 1);
}

function parseSuggestions(text: string): ExerciseSuggestion[] {
  const jsonText = extractJsonArray(text);
  if (!jsonText) return [];
  try {
    const parsed = JSON.parse(jsonText);
    if (!Array.isArray(parsed)) return [];
    return parsed
      .filter(
        (item): item is Record<string, unknown> =>
          !!item && typeof item.exerciseName === "string"
      )
      .map((item) => ({
        exerciseName: String(item.exerciseName),
        sets: Number(item.sets) || 3,
        reps: String(item.reps ?? "10-12"),
        restSeconds: Number(item.restSeconds) || 60,
        reason: String(item.reason ?? ""),
      }));
  } catch {
    return [];
  }
}

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
 * Chat de nutrição — separado de `chatWithAI` porque a conversa fica numa
 * coleção isolada (`nutrition_chat`) que a nutricionista vinculada também
 * lê e pode complementar (ver `firestore.rules`). Só devolve o texto da
 * resposta; quem grava a mensagem no Firestore é o cliente (mesmo padrão
 * sem-escrita-no-servidor de `chatWithAI`/`ChatProvider`).
 *
 * Responde só com o conhecimento da Claude — não busca na internet nem
 * consulta uma base de nutrição própria (isso ficou fora desta versão, ver
 * conversa sobre o motivo).
 */
export const askNutritionAI = onCall(
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
      system: NUTRITION_SYSTEM_PROMPT,
      messages: [...history, { role: "user", content: message }],
      maxTokens: 500,
      tools: [WEB_SEARCH_TOOL],
    });

    // A resposta vai para a conversa pelo servidor (o cliente não pode mais
    // gravar mensagens `assistant`); o texto também volta para o app.
    const saved = await saveNutritionReply(request.auth.uid, reply);
    return { reply: saved };
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

    const { month } = await assertAiUsageAllowed(request.auth.uid, "mealPhoto");

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

    await incrementAiUsage(request.auth.uid, "mealPhoto", month);
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

    const { month } = await assertAiUsageAllowed(request.auth.uid, "bodyPhoto");

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

    await incrementAiUsage(request.auth.uid, "bodyPhoto", month);
    return { analysis };
  }
);

/**
 * Apoio de IA para instrutores montarem treinos: sugestão geral (sem
 * aluno associado) ou contextualizada a um aluno específico. Espera
 * { prompt: string, studentName?: string }. Retorna de 3 a 4 sugestões
 * estruturadas (`suggestions`) — o instrutor escolhe adicionar/substituir
 * um exercício direto no plano do aluno. Se a IA não devolver um JSON
 * válido (raro, mas acontece), `suggestions` vem vazio e `rawText` traz o
 * texto cru como fallback pra não perder a resposta.
 */
export const suggestTrainingPlan = onCall(
  { secrets: [anthropicApiKey] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "É preciso estar logado.");
    }

    const prompt = request.data?.prompt as string | undefined;
    const studentName = request.data?.studentName as string | undefined;

    if (!prompt || prompt.trim().length === 0) {
      throw new HttpsError("invalid-argument", "Pedido vazio.");
    }

    const userMessage = studentName
      ? `Contexto: aluno(a) "${studentName}". Pedido do instrutor: ${prompt}`
      : prompt;

    const rawText = await callClaude({
      system: INSTRUCTOR_SYSTEM_PROMPT,
      messages: [{ role: "user", content: userMessage }],
      maxTokens: 700,
    });

    const suggestions = parseSuggestions(rawText);
    return {
      suggestions,
      rawText: suggestions.length === 0 ? rawText : undefined,
    };
  }
);
