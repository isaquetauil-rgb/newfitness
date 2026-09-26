import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import {
  AI_TIMEOUTS,
  AnthropicMessage,
  WEB_SEARCH_TOOL,
  anthropicApiKey,
  callClaude,
} from "./anthropic";
import {
  requireAiCaller,
  validateMealType,
  validateText,
  withAiQuota,
} from "./ai_guard";
import { saveNutritionReply } from "./nutrition";

/**
 * Functions de IA. Todas: login + e-mail verificado + papel permitido +
 * entrada validada + cota reservada antes da chamada (ver `ai_guard.ts`).
 * O modelo de cada uma fica em `anthropic.ts` (`modelFor`).
 */

const SYSTEM_PROMPT =
  "Você é o assistente de fitness do app NewFitness. Responda sempre em " +
  "português do Brasil, de forma curta, direta e motivadora. Você pode " +
  "ajudar com dúvidas sobre treino, dieta, suplementação e hábitos " +
  "saudáveis, mas dá SÓ orientação geral: você não é médico, personal " +
  "trainer nem nutricionista e não substitui esses profissionais. Quando " +
  "o assunto pedir avaliação individual (dor, lesão, condição clínica, " +
  "medicação, montar um treino ou uma dieta), lembre a pessoa de procurar " +
  "o personal ou a nutricionista dela.";

const NUTRITION_SYSTEM_PROMPT =
  "Você é um assistente de nutrição do app NewFitness, em português do " +
  "Brasil. Responda dúvidas do aluno sobre alimentação, hábitos, " +
  "hidratação e suplementação de forma curta e prática, dando SÓ " +
  "orientação geral. Você tem acesso a busca na web — use-a apenas quando " +
  "a pergunta depender de informação atual ou específica (ex: valor " +
  "nutricional de um produto) e cite a fonte. A nutricionista vinculada ao " +
  "aluno vê a conversa e pode corrigir ou complementar suas respostas. " +
  "Você não substitui a nutricionista nem uma consulta e não prescreve " +
  "dieta: quando o assunto for específico da saúde do aluno (restrição " +
  "alimentar, condição clínica, medicação), deixe claro que a orientação " +
  "definitiva é dela.";

const MEAL_PHOTO_SYSTEM_PROMPT =
  "Você comenta fotos de refeições no app NewFitness, em português do " +
  "Brasil, de forma curta e sem julgamentos. Dê só orientação geral; você " +
  "não substitui a nutricionista.";

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

/** Quantas mensagens anteriores da conversa vão para a IA. */
export const HISTORY_LIMIT = 10;

/**
 * Monta a conversa enviada à Claude a partir do FIRESTORE (o `history`
 * mandado pelo cliente é ignorado): as últimas `HISTORY_LIMIT` mensagens
 * antes da atual, em ordem, com papéis `user`/`assistant` alternados.
 * `roleOf` converte cada documento (ou `null` para ignorá-lo).
 */
async function conversationFor(
  collection: admin.firestore.CollectionReference,
  message: string,
  roleOf: (data: admin.firestore.DocumentData) =>
    | { role: "user" | "assistant"; content: string }
    | null
): Promise<AnthropicMessage[]> {
  const snap = await collection
    .orderBy("createdAt", "desc")
    .limit(HISTORY_LIMIT + 1)
    .get();
  const docs = snap.docs.map((d) => d.data()).reverse();

  // O app grava a pergunta antes de chamar a Function: não a repete.
  const last = docs[docs.length - 1];
  if (last && last.role === "user" && String(last.content ?? "").trim() === message) {
    docs.pop();
  }

  const turns: Array<{ role: "user" | "assistant"; content: string }> = [];
  for (const data of docs.slice(-HISTORY_LIMIT)) {
    const turn = roleOf(data);
    if (!turn || turn.content.trim().length === 0) continue;
    const prev = turns[turns.length - 1];
    if (prev && prev.role === turn.role) {
      prev.content += `\n\n${turn.content}`;
    } else {
      turns.push({ ...turn });
    }
  }
  // A conversa enviada precisa começar pelo usuário.
  while (turns.length > 0 && turns[0].role === "assistant") turns.shift();

  const lastTurn = turns[turns.length - 1];
  if (lastTurn && lastTurn.role === "user") {
    lastTurn.content += `\n\n${message}`;
  } else {
    turns.push({ role: "user", content: message });
  }
  return turns;
}

function userDoc(uid: string) {
  return admin.firestore().collection("users").doc(uid);
}

/**
 * Chat de texto com a IA, para todos os papéis. Espera `{ message }`.
 */
export const chatWithAI = onCall(
  { secrets: [anthropicApiKey], timeoutSeconds: 60 },
  async (request) => {
    const caller = await requireAiCaller(
      request,
      ["student", "instructor", "nutritionist"],
      "Seu perfil não tem acesso ao chat com IA."
    );
    const message = validateText(request.data?.message, "Mensagem vazia.");
    const messages = await conversationFor(
      userDoc(caller.uid).collection("chat_messages"),
      message,
      (d) => ({
        role: d.role === "assistant" ? "assistant" : "user",
        content: String(d.content ?? ""),
      })
    );

    const reply = await withAiQuota(caller, "chat", () =>
      callClaude({
        feature: "chat",
        system: SYSTEM_PROMPT,
        messages,
        maxTokens: 500,
      })
    );
    return { reply };
  }
);

/**
 * Chat de nutrição — só aluno. A conversa (`nutrition_chat`) também é lida
 * e complementada pela nutricionista vinculada; a resposta da IA é gravada
 * pelo servidor. Espera `{ message }`.
 */
export const askNutritionAI = onCall(
  { secrets: [anthropicApiKey], timeoutSeconds: 120 },
  async (request) => {
    const caller = await requireAiCaller(
      request,
      ["student"],
      "O assistente de nutrição é só para alunos."
    );
    const message = validateText(request.data?.message, "Mensagem vazia.");
    const messages = await conversationFor(
      userDoc(caller.uid).collection("nutrition_chat"),
      message,
      (d) => {
        const content = String(d.content ?? "");
        if (d.role === "assistant") return { role: "assistant", content };
        if (d.role === "nutritionist") {
          return { role: "user", content: `[Mensagem da nutricionista]: ${content}` };
        }
        return { role: "user", content };
      }
    );

    const reply = await withAiQuota(caller, "nutrition", () =>
      callClaude({
        feature: "nutrition",
        system: NUTRITION_SYSTEM_PROMPT,
        messages,
        maxTokens: 500,
        tools: [WEB_SEARCH_TOOL],
        timeoutMs: AI_TIMEOUTS.nutritionMs,
      })
    );

    // Só o servidor grava mensagens `assistant` (regras do Firestore).
    const saved = await saveNutritionReply(caller.uid, reply);
    return { reply: saved };
  }
);

const IMAGE_TYPES = ["image/jpeg", "image/png", "image/webp"];
const MAX_IMAGE_BYTES = 5 * 1024 * 1024;

/**
 * Analisa uma foto de refeição (base64) e devolve um comentário
 * nutricional simples — só aluno. Espera { imageBase64, mediaType,
 * mealType }.
 */
export const analyzeMealPhoto = onCall(
  { secrets: [anthropicApiKey], timeoutSeconds: 60 },
  async (request) => {
    const caller = await requireAiCaller(
      request,
      ["student"],
      "A análise de refeição é só para alunos."
    );
    const imageBase64 = request.data?.imageBase64;
    const mediaType = request.data?.mediaType ?? "image/jpeg";
    const mealLabel = validateMealType(request.data?.mealType);
    if (typeof imageBase64 !== "string" || imageBase64.length === 0) {
      throw new HttpsError("invalid-argument", "Imagem não enviada.");
    }
    if (typeof mediaType !== "string" || !IMAGE_TYPES.includes(mediaType)) {
      throw new HttpsError("invalid-argument", "Formato de imagem não suportado.");
    }
    if (Buffer.byteLength(imageBase64, "base64") > MAX_IMAGE_BYTES) {
      throw new HttpsError("invalid-argument", "A foto passa de 5 MB.");
    }

    const analysis = await withAiQuota(caller, "mealPhoto", () =>
      callClaude({
        feature: "mealPhoto",
        system: MEAL_PHOTO_SYSTEM_PROMPT,
        messages: [
          {
            role: "user",
            content: [
              {
                type: "text",
                text:
                  `Esta é uma foto do meu ${mealLabel}. Descreva rapidamente ` +
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
      })
    );
    return { analysis };
  }
);

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
 * Apoio de IA para instrutores montarem treinos — só instrutor. Espera
 * `{ prompt, studentUid? }`: com `studentUid`, o aluno precisa estar
 * vinculado ao instrutor e o NOME vem do perfil dele (não do cliente).
 * Retorna de 3 a 4 sugestões (`suggestions`); se a IA não devolver um JSON
 * válido, `rawText` traz o texto cru.
 */
export const suggestTrainingPlan = onCall(
  { secrets: [anthropicApiKey], timeoutSeconds: 60 },
  async (request) => {
    const caller = await requireAiCaller(
      request,
      ["instructor"],
      "A sugestão de treino com IA é só para instrutores."
    );
    const prompt = validateText(request.data?.prompt, "Pedido vazio.");

    let studentName: string | null = null;
    const studentUid = request.data?.studentUid;
    if (studentUid !== undefined && studentUid !== null) {
      if (typeof studentUid !== "string" || studentUid.length === 0) {
        throw new HttpsError("invalid-argument", "Aluno inválido.");
      }
      const student = await userDoc(studentUid).get();
      if (!student.exists || student.get("instructorId") !== caller.uid) {
        throw new HttpsError(
          "permission-denied",
          "Esse aluno não está vinculado a você."
        );
      }
      studentName = String(student.get("name") ?? "").trim() || "aluno";
    }

    const userMessage = studentName
      ? `Contexto: aluno(a) "${studentName}". Pedido do instrutor: ${prompt}`
      : prompt;

    const rawText = await withAiQuota(caller, "training", () =>
      callClaude({
        feature: "training",
        system: INSTRUCTOR_SYSTEM_PROMPT,
        messages: [{ role: "user", content: userMessage }],
        maxTokens: 700,
      })
    );

    const suggestions = parseSuggestions(rawText);
    return {
      suggestions,
      rawText: suggestions.length === 0 ? rawText : undefined,
    };
  }
);
