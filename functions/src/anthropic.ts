import { defineSecret } from "firebase-functions/params";
import { HttpsError } from "firebase-functions/v2/https";

// A chave fica guardada como "secret" do Firebase (nunca no código-fonte).
// Configuração: veja functions/README.md
export const anthropicApiKey = defineSecret("ANTHROPIC_API_KEY");

const ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages";

/** Funções de IA — cada uma tem o seu modelo. */
export type AiFeature = "chat" | "nutrition" | "mealPhoto" | "training";

/**
 * Modelo de cada função — ÚNICO lugar para trocar. Cada um pode ser
 * sobrescrito sem mexer no código por uma variável de ambiente das
 * Functions (ex: `AI_MODEL_CHAT=...` em `functions/.env`).
 */
const DEFAULT_MODELS: Record<AiFeature, string> = {
  chat: "claude-haiku-4-5-20251001",
  mealPhoto: "claude-haiku-4-5-20251001",
  nutrition: "claude-sonnet-5",
  training: "claude-sonnet-5",
};

const MODEL_ENV: Record<AiFeature, string> = {
  chat: "AI_MODEL_CHAT",
  mealPhoto: "AI_MODEL_MEAL_PHOTO",
  nutrition: "AI_MODEL_NUTRITION",
  training: "AI_MODEL_TRAINING",
};

export function modelFor(feature: AiFeature): string {
  return process.env[MODEL_ENV[feature]]?.trim() || DEFAULT_MODELS[feature];
}

/**
 * Tempo máximo de espera pela Anthropic (menor que o `timeoutSeconds` da
 * Function, para dar tempo de devolver um erro amigável). Mutável só para
 * os testes do emulador.
 */
export const AI_TIMEOUTS = {
  defaultMs: 45_000,
  nutritionMs: 100_000,
};

/**
 * Ferramenta server-side da própria Anthropic — a busca acontece na
 * infraestrutura dela e o resultado já volta dentro da mesma resposta.
 * `max_uses: 1` limita o custo (cada busca é cobrada à parte, e os
 * resultados entram como tokens de entrada).
 */
export const WEB_SEARCH_TOOL = {
  type: "web_search_20250305",
  name: "web_search",
  max_uses: 1,
};

interface ContentBlock {
  type: "text" | "image";
  text?: string;
  source?: {
    type: "base64";
    media_type: string;
    data: string;
  };
}

export interface AnthropicMessage {
  role: "user" | "assistant";
  content: string | ContentBlock[];
}

export interface ClaudeRequest {
  model: string;
  system?: string;
  messages: AnthropicMessage[];
  maxTokens: number;
  tools?: Array<Record<string, unknown>>;
  signal: AbortSignal;
}

/** Erro HTTP da API da Anthropic (ex: 429 limite, 529 sobrecarregada). */
export class ClaudeHttpError extends Error {
  constructor(readonly status: number, message: string) {
    super(message);
  }
}

/** Quem de fato fala com a Anthropic — trocável nos testes. */
export type ClaudeClient = (req: ClaudeRequest) => Promise<string>;

const fetchClaudeClient: ClaudeClient = async (req) => {
  const apiKey = anthropicApiKey.value();
  if (!apiKey) {
    throw new Error(
      "ANTHROPIC_API_KEY não configurada. Veja functions/README.md."
    );
  }

  const response = await fetch(ANTHROPIC_API_URL, {
    method: "POST",
    signal: req.signal,
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: req.model,
      max_tokens: req.maxTokens,
      system: req.system,
      messages: req.messages,
      ...(req.tools ? { tools: req.tools } : {}),
    }),
  });

  if (!response.ok) {
    const errText = await response.text();
    throw new ClaudeHttpError(
      response.status,
      `Erro da API Anthropic (${response.status}): ${errText}`
    );
  }

  const data = (await response.json()) as {
    content: Array<{ type: string; text?: string }>;
  };
  // Com busca na web, a resposta intercala blocos de busca e de texto —
  // só os de texto interessam (já vêm redigidos com o que foi encontrado).
  return data.content
    .filter((block) => block.type === "text")
    .map((block) => block.text ?? "")
    .join("\n")
    .trim();
};

let claudeClient: ClaudeClient = fetchClaudeClient;

/**
 * SÓ PARA TESTES: troca o cliente da Anthropic por um falso (`null` volta
 * ao real). Os testes nunca chamam a API de verdade.
 */
export function setClaudeClient(client: ClaudeClient | null): void {
  claudeClient = client ?? fetchClaudeClient;
}

class ClaudeTimeoutError extends Error {}

/**
 * Chama a Claude com o modelo da função, com timeout (AbortController) e
 * erros convertidos em `HttpsError` com mensagem amigável.
 */
export async function callClaude(params: {
  feature: AiFeature;
  system?: string;
  messages: AnthropicMessage[];
  maxTokens: number;
  tools?: Array<Record<string, unknown>>;
  timeoutMs?: number;
}): Promise<string> {
  const controller = new AbortController();
  const timeoutMs = params.timeoutMs ?? AI_TIMEOUTS.defaultMs;
  let timer: NodeJS.Timeout | undefined;
  const timeout = new Promise<never>((_, reject) => {
    timer = setTimeout(() => {
      controller.abort();
      reject(new ClaudeTimeoutError());
    }, timeoutMs);
  });

  try {
    return await Promise.race([
      claudeClient({
        model: modelFor(params.feature),
        system: params.system,
        messages: params.messages,
        maxTokens: params.maxTokens,
        tools: params.tools,
        signal: controller.signal,
      }),
      timeout,
    ]);
  } catch (err) {
    if (
      err instanceof ClaudeTimeoutError ||
      (err instanceof Error && err.name === "AbortError")
    ) {
      throw new HttpsError(
        "deadline-exceeded",
        "A IA demorou para responder. Tente de novo."
      );
    }
    if (err instanceof ClaudeHttpError && (err.status === 429 || err.status === 529)) {
      throw new HttpsError(
        "unavailable",
        "A IA está com muita procura agora. Tente de novo em alguns minutos."
      );
    }
    console.error("Falha ao chamar a Anthropic", err);
    throw new HttpsError(
      "internal",
      "Não foi possível falar com a IA agora. Tente de novo."
    );
  } finally {
    clearTimeout(timer);
  }
}
