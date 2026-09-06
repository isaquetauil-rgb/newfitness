import { defineSecret } from "firebase-functions/params";

// A chave fica guardada como "secret" do Firebase (nunca no código-fonte).
// Configuração: veja functions/README.md
export const anthropicApiKey = defineSecret("ANTHROPIC_API_KEY");

const ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages";
const MODEL = "claude-sonnet-4-6";

interface ContentBlock {
  type: "text" | "image";
  text?: string;
  source?: {
    type: "base64";
    media_type: string;
    data: string;
  };
}

interface AnthropicMessage {
  role: "user" | "assistant";
  content: string | ContentBlock[];
}

/**
 * Chama a API de mensagens da Anthropic e retorna o texto da resposta.
 */
export async function callClaude(params: {
  system?: string;
  messages: AnthropicMessage[];
  maxTokens?: number;
}): Promise<string> {
  const apiKey = anthropicApiKey.value();
  if (!apiKey) {
    throw new Error(
      "ANTHROPIC_API_KEY não configurada. Veja functions/README.md."
    );
  }

  const response = await fetch(ANTHROPIC_API_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: MODEL,
      max_tokens: params.maxTokens ?? 1024,
      system: params.system,
      messages: params.messages,
    }),
  });

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`Erro da API Anthropic (${response.status}): ${errText}`);
  }

  const data = (await response.json()) as {
    content: Array<{ type: string; text?: string }>;
  };

  return data.content
    .filter((block) => block.type === "text")
    .map((block) => block.text ?? "")
    .join("\n")
    .trim();
}
