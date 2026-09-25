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
 * Ferramenta server-side da própria Anthropic — a busca acontece na
 * infraestrutura dela (não fazemos nenhuma chamada extra a um provedor de
 * busca), e o resultado já volta dentro da mesma resposta. `max_uses` limita
 * quantas buscas a Claude pode fazer numa única pergunta, pra não deixar o
 * custo (cada busca é cobrada à parte pela Anthropic) sem teto.
 */
export const WEB_SEARCH_TOOL = {
  type: "web_search_20250305",
  name: "web_search",
  max_uses: 3,
};

/**
 * Chama a API de mensagens da Anthropic e retorna o texto da resposta.
 * Quando `tools` inclui `WEB_SEARCH_TOOL`, a resposta pode intercalar
 * blocos de busca com blocos de texto — só concatenamos os de texto, que já
 * vêm redigidos pela Claude incorporando o que ela encontrou.
 */
export async function callClaude(params: {
  system?: string;
  messages: AnthropicMessage[];
  maxTokens?: number;
  tools?: Array<Record<string, unknown>>;
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
      ...(params.tools ? { tools: params.tools } : {}),
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
