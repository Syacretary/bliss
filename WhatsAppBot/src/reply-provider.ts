import type { BotProfile, ReplyProvider } from './contracts.js';
import type { BotConfiguration } from './bot-config.js';

/** Adapter point for the configured AI provider; credentials belong in a native secure vault. */
export type ReplyGenerator = (input: {
  profile: BotProfile;
  message: string;
  chatId: string;
  configuration: BotConfiguration;
}) => Promise<string | null>;

export class ConfiguredReplyProvider implements ReplyProvider {
  constructor(private readonly generator: ReplyGenerator) {}

  generate(input: Parameters<ReplyProvider['generate']>[0]): Promise<string | null> {
    return this.generator(input);
  }
}

/** Safe default: the runtime remains connected but never sends autonomous replies. */
export class NoReplyProvider implements ReplyProvider {
  async generate(): Promise<null> {
    return null;
  }
}

/** Offline starter behavior; replace with a consented AI provider once credentials are configured. */
export class LocalStarterReplyProvider implements ReplyProvider {
  async generate(input: { profile: BotProfile; message: string; chatId: string; configuration: BotConfiguration }): Promise<string | null> {
    const { configuration, message, profile } = input;
    if (!configuration.behavior.autoReply) return null;
    const normalizedMessage = message.toLocaleLowerCase('id-ID');
    const rule = configuration.assistant.rules.find((candidate) =>
      candidate.enabled && candidate.keywords.some((keyword) => normalizedMessage.includes(keyword.toLocaleLowerCase('id-ID'))));
    const template = rule?.response ?? configuration.assistant.defaultReply;
    const formal = configuration.style.preset === 'formal'
      || (profile.tone?.toLocaleLowerCase('id-ID').includes('formal') ?? false);
    const values: Record<string, string> = {
      businessName: profile.businessName?.trim() || 'kami',
      assistantName: configuration.assistant.displayName,
      acknowledgement: formal ? 'Pesan Anda telah kami terima.' : 'Pesanmu sudah saya terima.',
      customerMessage: message,
    };
    return template.replace(/\{\{([a-zA-Z]+)\}\}/g, (placeholder, key: string) => values[key] ?? placeholder);
  }
}

/** Selects a reply module by configuration, allowing providers to be added independently. */
export class ReplyProviderRegistry implements ReplyProvider {
  private readonly providers = new Map<string, ReplyProvider>();
  private readonly metadata = new Map<string, { name: string; requiresApiKey: boolean; external: boolean; defaultModel?: string; notice?: string }>();

  register(id: string, provider: ReplyProvider, info: { name?: string; requiresApiKey?: boolean; external?: boolean; defaultModel?: string; notice?: string } = {}): this {
    if (!/^[a-z0-9][a-z0-9._-]*$/i.test(id) || this.providers.has(id)) throw new Error('Provider id is invalid or duplicated.');
    this.providers.set(id, provider);
    this.metadata.set(id, {
      name: info.name ?? id,
      requiresApiKey: info.requiresApiKey ?? false,
      external: info.external ?? false,
      ...(info.defaultModel ? { defaultModel: info.defaultModel } : {}),
      ...(info.notice ? { notice: info.notice } : {}),
    });
    return this;
  }

  has(id: string): boolean {
    return this.providers.has(id);
  }

  ids(): string[] {
    return [...this.providers.keys()];
  }

  descriptor(id: string): { id: string; name: string; requiresApiKey: boolean; external: boolean; defaultModel?: string; notice?: string } | undefined {
    const info = this.metadata.get(id);
    return info ? { id, ...info } : undefined;
  }

  descriptors(): Array<{ id: string; name: string; requiresApiKey: boolean; external: boolean }> {
    return [...this.metadata.keys()].map((id) => this.descriptor(id)!);
  }

  generate(input: Parameters<ReplyProvider['generate']>[0]): Promise<string | null> {
    const provider = this.providers.get(input.configuration.provider.id);
    if (!provider) throw new Error(`Reply provider "${input.configuration.provider.id}" is not registered.`);
    return provider.generate(input);
  }
}
