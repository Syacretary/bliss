import type { BotConfiguration, KnowledgeEntry } from './bot-config.js';
import type { BotProfile, ConversationMessage, ProviderCredentialStore, ReplyProvider } from './contracts.js';
import { coreProfile, retrieveKnowledge } from './local-knowledge.js';

type RemoteProviderId = 'openai' | 'gemini' | 'anthropic' | 'deepseek' | 'groq';

const modelDefaults: Record<RemoteProviderId, string> = {
  openai: 'gpt-6-luna',
  gemini: 'gemini-3.1-flash-lite',
  anthropic: 'claude-haiku-5-5',
  deepseek: 'deepseek-flash',
  groq: 'openai/gpt-oss-20b',
};

type JsonObject = Record<string, unknown>;

function asObject(value: unknown): JsonObject | undefined {
  return typeof value === 'object' && value !== null && !Array.isArray(value) ? value as JsonObject : undefined;
}

function asText(value: unknown): string | undefined {
  return typeof value === 'string' && value.trim() ? value.trim() : undefined;
}

function systemInstructions(configuration: BotConfiguration, retrieved: KnowledgeEntry[]): string {
  const style = configuration.style;
  const tone = style.preset === 'custom'
    ? style.customText.trim() || 'Ramah'
    : ({ formal: 'Formal', friendly: 'Ramah', concise: 'To the point' } as const)[style.preset];
  const knowledge = retrieved
    .map((item) => `[${item.kind.toLocaleUpperCase('id-ID')}] ${item.title}: ${item.content}`)
    .join('\n');
  const core = coreProfile(configuration);
  return [`Gaya bicara: ${tone}`, 'Pengetahuan AI:', core, knowledge].filter(Boolean).join('\n');
}

function historyText(history: ConversationMessage[] | undefined, message: string): string {
  // Keep recent context useful while avoiding unbounded cost from unusually long messages.
  const lines = (history ?? []).slice(-6).map((item) =>
    `${item.direction === 'incoming' ? 'Pelanggan' : 'Asisten'}: ${item.text.slice(-1_000)}`,
  );
  lines.push(`Pelanggan: ${message}`);
  return lines.join('\n').slice(-7_000);
}

async function postJson(url: string, headers: Record<string, string>, body: unknown): Promise<JsonObject> {
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json', ...headers },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(20_000),
  });
  if (!response.ok) throw new Error(`AI_PROVIDER_HTTP_${response.status}`);
  const result = asObject(await response.json());
  if (!result) throw new Error('AI_PROVIDER_RESPONSE_INVALID');
  return result;
}

function openAiCompatibleText(response: JsonObject): string | undefined {
  const choices = response.choices;
  if (!Array.isArray(choices)) return undefined;
  const message = asObject(asObject(choices[0])?.message);
  return asText(message?.content);
}

function responseText(response: JsonObject): string | undefined {
  const output = response.output;
  if (!Array.isArray(output)) return undefined;
  const parts: string[] = [];
  for (const item of output) {
    const content = asObject(item)?.content;
    if (!Array.isArray(content)) continue;
    for (const block of content) {
      const value = asObject(block);
      if (value?.type === 'output_text' && typeof value.text === 'string') parts.push(value.text);
    }
  }
  return asText(parts.join('\n'));
}

/** Remote LLM adapter. It sends content only after explicit external-processing consent. */
export class RemoteAiReplyProvider implements ReplyProvider {
  constructor(private readonly providerId: RemoteProviderId, private readonly credentials: ProviderCredentialStore) {}

  async generate(input: Parameters<ReplyProvider['generate']>[0]): Promise<string | null> {
    if (!input.configuration.privacy.allowExternalProcessing) {
      input.onDiagnostic?.('WARN', 'Request AI dilewati: izin pemrosesan eksternal belum diberikan.');
      return null;
    }
    const apiKey = await this.credentials.get(this.providerId);
    input.onDiagnostic?.(apiKey ? 'INFO' : 'ERROR', `Kredensial API ${this.providerId}: ${apiKey ? 'tersedia dan berhasil dibaca' : 'tidak ditemukan'} (nilai disembunyikan).`);
    if (!apiKey) throw new Error('AI_PROVIDER_CREDENTIAL_MISSING');
    const model = input.configuration.provider.model?.trim() || modelDefaults[this.providerId];
    input.onDiagnostic?.('INFO', `Memanggil provider AI ${this.providerId} · model ${model}.`);
    const retrieved = retrieveKnowledge(input.configuration, input.message);
    const retrievedCount = retrieved.length;
    const instructions = systemInstructions(input.configuration, retrieved);
    input.onDiagnostic?.('INFO', `Retrieval lokal memilih ${retrievedCount} potongan pengetahuan; isi sumber tidak dicatat ke log.`);
    const conversation = historyText(input.history, input.message);
    const maxOutput = Math.max(64, Math.ceil(input.configuration.behavior.maxReplyLength / 3));

    if (this.providerId === 'openai') {
      const result = await this.request('https://api.openai.com/v1/responses', { authorization: `Bearer ${apiKey}` }, {
        model,
        instructions,
        input: conversation,
        max_output_tokens: maxOutput,
        store: false,
      }, input.onDiagnostic);
      return responseText(result) ?? asText(result.output_text) ?? null;
    }
    if (this.providerId === 'gemini') {
      const result = await this.request(
        `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`,
        { 'x-goog-api-key': apiKey },
        {
          systemInstruction: { parts: [{ text: instructions }] },
          contents: [{ role: 'user', parts: [{ text: conversation }] }],
          generationConfig: { maxOutputTokens: maxOutput },
        }, input.onDiagnostic,
      );
      const candidates = result.candidates;
      const parts = asObject(Array.isArray(candidates) ? asObject(candidates[0])?.content : undefined)?.parts;
      if (!Array.isArray(parts)) return null;
      return asText(parts.map((part) => asText(asObject(part)?.text) ?? '').filter(Boolean).join('\n')) ?? null;
    }
    if (this.providerId === 'anthropic') {
      const result = await this.request('https://api.anthropic.com/v1/messages', {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      }, {
        model,
        max_tokens: maxOutput,
        system: instructions,
        messages: [{ role: 'user', content: conversation }],
      }, input.onDiagnostic);
      const content = result.content;
      if (!Array.isArray(content)) return null;
      return asText(content.map((part) => {
        const value = asObject(part);
        return value?.type === 'text' ? asText(value.text) ?? '' : '';
      }).filter(Boolean).join('\n')) ?? null;
    }

    const baseUrl = this.providerId === 'deepseek' ? 'https://api.deepseek.com/chat/completions' : 'https://api.groq.com/openai/v1/chat/completions';
    const result = await this.request(baseUrl, { authorization: `Bearer ${apiKey}` }, {
      model,
      messages: [
        { role: 'system', content: instructions },
        { role: 'user', content: conversation },
      ],
      max_tokens: maxOutput,
      ...(this.providerId === 'deepseek'
        ? { thinking: { type: 'disabled' }, tool_choice: 'none' }
        : this.providerId === 'groq'
          ? { reasoning_effort: 'low', reasoning_format: 'hidden', tool_choice: 'none' }
          : { tool_choice: 'none' }),
    }, input.onDiagnostic);
    return openAiCompatibleText(result) ?? null;
  }

  private async request(
    url: string,
    headers: Record<string, string>,
    body: unknown,
    onDiagnostic?: (level: 'INFO' | 'WARN' | 'ERROR', message: string) => void,
  ): Promise<JsonObject> {
    const startedAt = Date.now();
    try {
      onDiagnostic?.('INFO', `Mengirim request HTTPS ke ${this.providerId}; kredensial tidak dicatat.`);
      const result = await postJson(url, headers, body);
      // Deliberately report only the outcome and duration, never headers or request body.
      onDiagnostic?.('INFO', `Provider ${this.providerId} merespons berhasil dalam ${Date.now() - startedAt} ms.`);
      return result;
    } catch (error) {
      const reason = error instanceof Error && /^AI_PROVIDER_[A-Z0-9_]+$/.test(error.message)
        ? error.message
        : 'NETWORK_OR_PROVIDER_ERROR';
      onDiagnostic?.('ERROR', `Request provider ${this.providerId} gagal · ${reason}. API key tetap disembunyikan.`);
      throw Object.assign(new Error(reason), { diagnosticReason: reason, durationMs: Date.now() - startedAt });
    }
  }
}

export const REMOTE_PROVIDER_IDS: readonly RemoteProviderId[] = ['openai', 'gemini', 'anthropic', 'deepseek', 'groq'];
export const DEFAULT_PROVIDER_MODELS: Readonly<Record<RemoteProviderId, string>> = modelDefaults;
