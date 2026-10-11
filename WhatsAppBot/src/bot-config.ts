import type { BotProfile } from './contracts.js';

export interface ReplyRule {
  id: string;
  enabled: boolean;
  keywords: string[];
  response: string;
}

export interface CustomCommand {
  id: string;
  trigger: string;
  response: string;
  enabled: boolean;
}

export interface InstalledPlugin {
  id: string;
  enabled: boolean;
  settings: Record<string, string | number | boolean | string[]>;
}

export interface KnowledgeEntry {
  kind: 'faq' | 'document' | 'image' | 'text';
  title: string;
  content: string;
  /** Original filename is metadata only; source bytes are never uploaded to a provider. */
  fileName?: string;
}

/** Versioned, secret-free settings suitable for a local dashboard API. */
export interface BotConfiguration {
  schemaVersion: 2;
  profile: BotProfile;
  style: {
    preset: 'formal' | 'friendly' | 'concise' | 'custom';
    customText: string;
  };
  knowledge: KnowledgeEntry[];
  assistant: {
    displayName: string;
    defaultReply: string;
    rules: ReplyRule[];
  };
  behavior: {
    autoReply: boolean;
    cooldownSeconds: number;
    maxReplyLength: number;
  };
  commands: CustomCommand[];
  plugins: InstalledPlugin[];
  privacy: {
    logConversations: boolean;
    allowExternalProcessing: boolean;
    retentionDays: number;
  };
  provider: {
    id: string;
    model?: string;
    /** Reference to a native secure-storage entry; never a raw API key. */
    credentialRef?: string;
  };
}

export const DEFAULT_BOT_CONFIGURATION: BotConfiguration = {
  schemaVersion: 2,
  profile: { purpose: 'other' },
  style: { preset: 'friendly', customText: '' },
  knowledge: [],
  assistant: {
    displayName: 'Bliss',
    defaultReply: 'Hai! Terima kasih sudah menghubungi {{businessName}}. {{acknowledgement}} Ada yang bisa kami bantu?',
    rules: [],
  },
  behavior: { autoReply: true, cooldownSeconds: 15, maxReplyLength: 1000 },
  commands: [],
  plugins: [],
  privacy: { logConversations: true, allowExternalProcessing: false, retentionDays: 30 },
  provider: { id: 'local-template' },
};

const purposes = new Set(['personal', 'community', 'customerService', 'other']);
const maxText = 2_000;

function object(value: unknown, label: string): Record<string, unknown> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new Error(`${label} must be an object.`);
  }
  return value as Record<string, unknown>;
}

function text(value: unknown, label: string, max = maxText): string {
  if (typeof value !== 'string' || value.length > max) throw new Error(`${label} is invalid.`);
  return value.trim();
}

function boundedInteger(value: unknown, label: string, min: number, max: number): number {
  if (!Number.isInteger(value) || (value as number) < min || (value as number) > max) {
    throw new Error(`${label} must be between ${min} and ${max}.`);
  }
  return value as number;
}

export function defaultBotConfiguration(profile: BotProfile = DEFAULT_BOT_CONFIGURATION.profile): BotConfiguration {
  return {
    ...DEFAULT_BOT_CONFIGURATION,
    profile: { ...profile },
    style: { ...DEFAULT_BOT_CONFIGURATION.style },
    assistant: { ...DEFAULT_BOT_CONFIGURATION.assistant, rules: [] },
    behavior: { ...DEFAULT_BOT_CONFIGURATION.behavior },
    commands: [],
    plugins: [],
    privacy: { ...DEFAULT_BOT_CONFIGURATION.privacy },
    provider: { ...DEFAULT_BOT_CONFIGURATION.provider },
  };
}

/** Validate and canonicalize a complete configuration before it enters the runtime. */
export function normalizeBotConfiguration(value: unknown): BotConfiguration {
  const incoming = object(value, 'configuration');
  if (incoming.schemaVersion !== 1 && incoming.schemaVersion !== 2) throw new Error('Unsupported bot configuration version.');
  // v1 was shipped before the Dashboardv2 customization contract existed.
  const root = incoming.schemaVersion === 1
    ? { ...defaultBotConfiguration(), ...incoming, schemaVersion: 2 }
    : incoming;
  const profileInput = object(root.profile, 'profile');
  const purpose = profileInput.purpose;
  if (typeof purpose !== 'string' || !purposes.has(purpose)) throw new Error('profile.purpose is invalid.');
  const profile: BotProfile = {
    purpose: purpose as BotProfile['purpose'],
    ...(typeof profileInput.purposeOther === 'string' ? { purposeOther: text(profileInput.purposeOther, 'profile.purposeOther', 120) } : {}),
    ...(profileInput.volumeIndex === undefined ? {} : { volumeIndex: boundedInteger(profileInput.volumeIndex, 'profile.volumeIndex', 0, 20) }),
    ...(typeof profileInput.tone === 'string' ? { tone: text(profileInput.tone, 'profile.tone', 80) } : {}),
    ...(typeof profileInput.businessName === 'string' ? { businessName: text(profileInput.businessName, 'profile.businessName', 120) } : {}),
    ...(typeof profileInput.businessHours === 'string' ? { businessHours: text(profileInput.businessHours, 'profile.businessHours', 180) } : {}),
    ...(typeof profileInput.provider === 'string' ? { provider: text(profileInput.provider, 'profile.provider', 80) } : {}),
  };

  const assistantInput = object(root.assistant, 'assistant');
  if (!Array.isArray(assistantInput.rules) || assistantInput.rules.length > 100) throw new Error('assistant.rules is invalid.');
  const rules = assistantInput.rules.map((raw, index): ReplyRule => {
    const rule = object(raw, `assistant.rules[${index}]`);
    if (typeof rule.enabled !== 'boolean' || !Array.isArray(rule.keywords) || rule.keywords.length < 1 || rule.keywords.length > 20) {
      throw new Error(`assistant.rules[${index}] is invalid.`);
    }
    const keywords = rule.keywords.map((keyword) => text(keyword, 'rule keyword', 80)).filter(Boolean);
    if (!keywords.length) throw new Error(`assistant.rules[${index}] needs a keyword.`);
    return {
      id: text(rule.id, 'rule.id', 80),
      enabled: rule.enabled,
      keywords,
      response: text(rule.response, 'rule.response'),
    };
  });
  if (new Set(rules.map((rule) => rule.id)).size !== rules.length) throw new Error('assistant.rules has duplicate ids.');
  const behaviorInput = object(root.behavior, 'behavior');
  if (typeof behaviorInput.autoReply !== 'boolean') throw new Error('behavior.autoReply is invalid.');
  const providerInput = object(root.provider, 'provider');
  const providerId = text(providerInput.id, 'provider.id', 80);
  if (!/^[a-z0-9][a-z0-9._-]*$/i.test(providerId)) throw new Error('provider.id is invalid.');

  const styleInput = object(root.style, 'style');
  const stylePreset = styleInput.preset;
  if (stylePreset !== 'formal' && stylePreset !== 'friendly' && stylePreset !== 'concise' && stylePreset !== 'custom') {
    throw new Error('style.preset is invalid.');
  }
  const knowledgeInput = root.knowledge ?? [];
  if (!Array.isArray(knowledgeInput) || knowledgeInput.length > 100) throw new Error('knowledge is invalid.');
  let knowledgeCharacters = 0;
  const knowledge = knowledgeInput.map((raw, index): KnowledgeEntry => {
    const entry = object(raw, `knowledge[${index}]`);
    const kind = entry.kind;
    if (kind !== 'faq' && kind !== 'document' && kind !== 'image' && kind !== 'text') {
      throw new Error(`knowledge[${index}].kind is invalid.`);
    }
    const normalized: KnowledgeEntry = {
      kind,
      title: text(entry.title, `knowledge[${index}].title`, 200),
      content: text(entry.content, `knowledge[${index}].content`, 200_000),
      ...(typeof entry.fileName === 'string' ? { fileName: text(entry.fileName, `knowledge[${index}].fileName`, 240) } : {}),
    };
    knowledgeCharacters += normalized.title.length + normalized.content.length;
    if (knowledgeCharacters > 500_000) throw new Error('knowledge exceeds the 500,000 character limit.');
    return normalized;
  });

  if (!Array.isArray(root.commands) || root.commands.length > 100) throw new Error('commands is invalid.');
  const commands = root.commands.map((raw, index): CustomCommand => {
    const command = object(raw, `commands[${index}]`);
    const trigger = text(command.trigger, 'command.trigger', 42);
    if (!/^[/!][\p{L}\p{N}_-]{1,40}$/u.test(trigger) || typeof command.enabled !== 'boolean') throw new Error(`commands[${index}] is invalid.`);
    return { id: text(command.id, 'command.id', 80), trigger, response: text(command.response, 'command.response'), enabled: command.enabled };
  });
  if (new Set(commands.map((command) => command.id)).size !== commands.length
    || new Set(commands.map((command) => command.trigger.toLocaleLowerCase('id-ID'))).size !== commands.length) {
    throw new Error('commands contains duplicate ids or triggers.');
  }

  if (!Array.isArray(root.plugins) || root.plugins.length > 100) throw new Error('plugins is invalid.');
  const plugins = root.plugins.map((raw, index): InstalledPlugin => {
    const plugin = object(raw, `plugins[${index}]`);
    if (typeof plugin.enabled !== 'boolean') throw new Error(`plugins[${index}].enabled is invalid.`);
    const settingsInput = object(plugin.settings ?? {}, `plugins[${index}].settings`);
    const settings: InstalledPlugin['settings'] = {};
    for (const [key, setting] of Object.entries(settingsInput)) {
      if (typeof setting === 'string') settings[text(key, 'plugin setting key', 80)] = text(setting, 'plugin setting', 500);
      else if (typeof setting === 'boolean') settings[text(key, 'plugin setting key', 80)] = setting;
      else if (typeof setting === 'number' && Number.isFinite(setting)) settings[text(key, 'plugin setting key', 80)] = setting;
      else if (Array.isArray(setting) && setting.length <= 100 && setting.every((item) => typeof item === 'string')) {
        settings[text(key, 'plugin setting key', 80)] = setting.map((item) => text(item, 'plugin setting', 120));
      } else throw new Error(`plugins[${index}].settings contains an unsupported value.`);
    }
    return { id: text(plugin.id, 'plugin.id', 100), enabled: plugin.enabled, settings };
  });
  if (new Set(plugins.map((plugin) => plugin.id)).size !== plugins.length) throw new Error('plugins contains duplicate ids.');

  const privacyInput = object(root.privacy, 'privacy');
  if (typeof privacyInput.logConversations !== 'boolean' || typeof privacyInput.allowExternalProcessing !== 'boolean') {
    throw new Error('privacy settings are invalid.');
  }

  return {
    schemaVersion: 2,
    profile,
    style: {
      preset: stylePreset,
      customText: text(styleInput.customText, 'style.customText', 1_000),
    },
    knowledge,
    assistant: {
      displayName: text(assistantInput.displayName, 'assistant.displayName', 80),
      defaultReply: text(assistantInput.defaultReply, 'assistant.defaultReply'),
      rules,
    },
    behavior: {
      autoReply: behaviorInput.autoReply,
      cooldownSeconds: boundedInteger(behaviorInput.cooldownSeconds, 'behavior.cooldownSeconds', 0, 86_400),
      maxReplyLength: boundedInteger(behaviorInput.maxReplyLength, 'behavior.maxReplyLength', 1, 4_000),
    },
    commands,
    plugins,
    privacy: {
      logConversations: privacyInput.logConversations,
      allowExternalProcessing: privacyInput.allowExternalProcessing,
      retentionDays: boundedInteger(privacyInput.retentionDays, 'privacy.retentionDays', 1, 365),
    },
    provider: {
      id: providerId,
      ...(typeof providerInput.model === 'string' ? { model: text(providerInput.model, 'provider.model', 120) } : {}),
      ...(typeof providerInput.credentialRef === 'string' ? { credentialRef: text(providerInput.credentialRef, 'provider.credentialRef', 120) } : {}),
    },
  };
}

/** Merge dashboard partial updates without losing unrelated sections. */
export function mergeBotConfiguration(current: BotConfiguration, patch: unknown): BotConfiguration {
  const update = object(patch, 'patch');
  const merged = {
    ...current,
    ...update,
    profile: { ...current.profile, ...object(update.profile ?? {}, 'profile') },
    assistant: { ...current.assistant, ...object(update.assistant ?? {}, 'assistant') },
    behavior: { ...current.behavior, ...object(update.behavior ?? {}, 'behavior') },
    style: { ...current.style, ...object(update.style ?? {}, 'style') },
    privacy: { ...current.privacy, ...object(update.privacy ?? {}, 'privacy') },
    provider: { ...current.provider, ...object(update.provider ?? {}, 'provider') },
    commands: update.commands ?? current.commands,
    plugins: update.plugins ?? current.plugins,
  };
  return normalizeBotConfiguration(merged);
}
