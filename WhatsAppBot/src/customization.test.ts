import assert from 'node:assert/strict';
import test from 'node:test';
import { EncryptedConversationLogStore, opaqueConversationId } from './conversation-log-store.js';
import { matchCustomCommand } from './custom-commands.js';
import { defaultBotConfiguration, mergeBotConfiguration } from './bot-config.js';
import { loadPluginStore } from './plugin-registry.js';
import { DEFAULT_PROVIDER_MODELS, RemoteAiReplyProvider } from './ai-reply-providers.js';
import type { ProviderCredentialStore } from './contracts.js';
import type { SessionStore } from './contracts.js';

class MemoryStore implements SessionStore {
  value: Record<string, unknown> | undefined;
  async read() { return structuredClone(this.value); }
  async write(value: Record<string, unknown>) { this.value = structuredClone(value); }
}

test('conversation console exposes opaque IDs and preserves thread takeover state', async () => {
  const store = new EncryptedConversationLogStore(new MemoryStore());
  const remoteId = '628123456789@s.whatsapp.net';
  const id = opaqueConversationId(remoteId);
  await store.record({ remoteId, displayName: 'Ayu', direction: 'incoming', text: 'Halo', retentionDays: 30 });
  await store.setNeedsHuman(id, true);
  await store.record({ remoteId, displayName: 'Ayu', direction: 'bot', text: 'Hai', retentionDays: 30 });
  assert.equal(id.length, 24);
  assert.equal(id.includes('628123'), false);
  assert.equal((await store.summary(id))?.needsHuman, true);
  assert.deepEqual((await store.messages(id, 10)).map((item) => item.direction), ['incoming', 'bot']);
  assert.equal(await store.remoteId(id), remoteId);
});

test('human handoff is visible in conversation history but excluded from AI reply metrics', async () => {
  const store = new EncryptedConversationLogStore(new MemoryStore());
  const remoteId = '628111222333@s.whatsapp.net';
  const id = opaqueConversationId(remoteId);
  const now = Date.now();
  await store.record({ remoteId, displayName: 'Nia', direction: 'incoming', text: 'Halo', timestamp: now - 2_000, retentionDays: 30 });
  await store.setNeedsHuman(id, true);
  await store.record({ remoteId, displayName: 'Nia', direction: 'handoff', text: 'Tim kami akan membalas.', timestamp: now - 1_000, retentionDays: 30 });

  const analytics = await store.analytics(1, 0);
  assert.equal((await store.summary(id))?.needsHuman, true);
  assert.equal((await store.messages(id, 10)).at(-1)?.direction, 'handoff');
  assert.equal(analytics.totals.incomingMessages, 1);
  assert.equal(analytics.totals.botReplies, 0);
  assert.equal(analytics.totals.responseCount, 0);
});

test('local analytics count logged messages, reply time, daily buckets and topics', async () => {
  const store = new EncryptedConversationLogStore(new MemoryStore());
  const remoteId = '628123456789@s.whatsapp.net';
  const now = Date.now();
  await store.record({ remoteId, displayName: 'Ayu', direction: 'incoming', text: 'Berapa harga kopi susu?', timestamp: now - 10_000, retentionDays: 30 });
  await store.record({ remoteId, displayName: 'Ayu', direction: 'bot', text: 'Harganya Rp20.000.', timestamp: now - 5_000, retentionDays: 30 });
  await store.record({ remoteId, displayName: 'Ayu', direction: 'human', text: 'Saya bantu ya.', timestamp: now - 1_000, retentionDays: 30 });

  const analytics = await store.analytics(1, 0);
  assert.equal(analytics.totals.incomingMessages, 1);
  assert.equal(analytics.totals.botReplies, 1);
  assert.equal(analytics.totals.humanReplies, 1);
  assert.equal(analytics.totals.activeConversations, 1);
  assert.equal(analytics.totals.responseCount, 1);
  assert.equal(analytics.totals.averageResponseMs, 5_000);
  assert.equal(analytics.totals.estimatedMinutesSaved, 1);
  assert.equal(analytics.daily.reduce((total, day) => total + day.incoming, 0), 1);
  assert.ok(analytics.topics.some((topic) => topic.label === 'Harga'));
});

test('custom commands require exact trigger and interpolate only text placeholders', () => {
  const configuration = mergeBotConfiguration(defaultBotConfiguration({ purpose: 'customerService', businessName: 'Kopi Bliss' }), {
    commands: [{ id: 'hours', trigger: '!jam', response: 'Halo {{businessName}} — {{assistantName}} siap membantu.', enabled: true }],
  });
  assert.equal(matchCustomCommand('  !JAM ', configuration), 'Halo Kopi Bliss — Bliss siap membantu.');
  assert.equal(matchCustomCommand('!jam dong', configuration), undefined);
});

test('plugin store loads folder manifests; filter uses only customized, bounded settings', async () => {
  const registry = await loadPluginStore();
  const profile = { purpose: 'other' as const };
  const blocked = await registry.beforeReply([
    { id: 'filter', enabled: true, settings: { configured: true, blockedKeywords: 'spam', notice: 'Pesan ditahan.' } },
  ], { profile, message: 'Ini spam' });
  assert.deepEqual(blocked, { action: 'reply', text: 'Pesan ditahan.' });
  assert.deepEqual(registry.list().map((plugin) => plugin.id).sort(), ['autotyping', 'filter']);
  assert.throws(() => registry.validateInstalled([
    { id: 'autotyping', enabled: true, settings: {} },
  ]), /customized before activation/);
  await assert.rejects(() => registry.beforeReply([
    { id: 'arbitrary-code', enabled: true, settings: {} },
  ], { profile, message: 'Halo' }), /not registered/);
  const presence: string[] = [];
  const activeTyping = [{ id: 'autotyping', enabled: true, settings: { configured: true, showWhileGenerating: true } }];
  const sendPresence = async (value: 'composing' | 'paused') => { presence.push(value); };
  await registry.onGeneratingReply(activeTyping, { chatId: 'thread', message: 'Halo', sendPresence });
  await registry.afterReply(activeTyping, { chatId: 'thread', message: 'Halo', replyText: 'Hai', sendPresence });
  assert.deepEqual(presence, ['composing', 'paused']);
});

test('external provider sends nothing until explicit processing consent exists', async () => {
  let credentialReads = 0;
  const credentials: ProviderCredentialStore = {
    async set() {}, async has() { return false; }, async remove() {},
    async get() { credentialReads++; return 'unused-secret'; },
  };
  const configuration = defaultBotConfiguration();
  configuration.provider = { id: 'openai' };
  const provider = new RemoteAiReplyProvider('openai', credentials);
  assert.equal(await provider.generate({
    profile: configuration.profile,
    message: 'Pesan pribadi',
    chatId: 'should-not-be-sent',
    configuration,
  }), null);
  assert.equal(credentialReads, 0);
});

test('remote provider diagnostics confirm credential use without exposing its value', async () => {
  const secret = 'test-secret-that-must-never-be-logged';
  const credentials: ProviderCredentialStore = {
    async set() {}, async has() { return true; }, async remove() {},
    async get() { return secret; },
  };
  const configuration = defaultBotConfiguration();
  configuration.provider = { id: 'openai', model: 'test-model' };
  configuration.profile = {
    purpose: 'customerService',
    businessName: 'Kedai Kopi',
    businessHours: 'Senin–Minggu, 08.00–21.00 WIB',
  };
  configuration.privacy.allowExternalProcessing = true;
  const diagnostics: string[] = [];
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (_input, init) => {
    assert.equal(new Headers(init?.headers).get('authorization'), `Bearer ${secret}`);
    return new Response(JSON.stringify({ output_text: 'Balasan uji.' }), { status: 200 });
  };
  try {
    const reply = await new RemoteAiReplyProvider('openai', credentials).generate({
      profile: configuration.profile,
      message: 'Halo',
      chatId: 'test-chat',
      configuration,
      onDiagnostic: (_level, message) => diagnostics.push(message),
    });
    assert.equal(reply, 'Balasan uji.');
    assert.ok(diagnostics.some((line) => line.includes('tersedia dan berhasil dibaca')));
    assert.ok(diagnostics.some((line) => line.includes('request HTTPS')));
    assert.ok(diagnostics.some((line) => line.includes('merespons berhasil')));
    assert.equal(diagnostics.join('\n').includes(secret), false);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('Gemini default model ID and API key are sent in the request, not its URL', async () => {
  const secret = 'gemini-test-secret-value';
  const credentials: ProviderCredentialStore = {
    async set() {}, async has() { return true; }, async remove() {},
    async get() { return secret; },
  };
  const configuration = defaultBotConfiguration();
  configuration.provider = { id: 'gemini', model: DEFAULT_PROVIDER_MODELS.gemini };
  configuration.privacy.allowExternalProcessing = true;
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (input, init) => {
    const url = new URL(String(input));
    assert.equal(url.pathname, '/v1beta/models/gemini-3.1-flash-lite:generateContent');
    assert.equal(url.search, '');
    assert.equal(new Headers(init?.headers).get('x-goog-api-key'), secret);
    return new Response(JSON.stringify({
      candidates: [{ content: { parts: [{ text: 'Hai, ini balasan Gemini.' }] } }],
    }), { status: 200 });
  };
  try {
    const reply = await new RemoteAiReplyProvider('gemini', credentials).generate({
      profile: configuration.profile,
      message: 'Halo',
      chatId: 'test-chat',
      configuration,
    });
    assert.equal(reply, 'Hai, ini balasan Gemini.');
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('remote system prompt contains only studio tone and AI knowledge', async () => {
  const credentials: ProviderCredentialStore = {
    async set() {}, async has() { return true; }, async remove() {},
    async get() { return 'secret'; },
  };
  const configuration = defaultBotConfiguration();
  configuration.provider = { id: 'openai', model: 'test-model' };
  configuration.profile = {
    purpose: 'customerService',
    businessName: 'Kedai Kopi',
    businessHours: 'Senin–Minggu, 08.00–21.00 WIB',
  };
  configuration.privacy.allowExternalProcessing = true;
  configuration.style = { preset: 'custom', customText: 'Hangat dan langsung ke inti.' };
  configuration.knowledge = [
    { kind: 'faq', title: 'Jam buka', content: 'Setiap hari pukul 08.00–21.00.' },
    { kind: 'image', title: 'Menu minuman', content: 'Foto menu berisi kopi dan teh.' },
  ];
  const originalFetch = globalThis.fetch;
  let capturedInstructions = '';
  globalThis.fetch = async (_input, init) => {
    const body = JSON.parse(String(init?.body)) as { instructions: string };
    capturedInstructions = body.instructions;
    return new Response(JSON.stringify({ output_text: 'Siap.' }), { status: 200 });
  };
  try {
    await new RemoteAiReplyProvider('openai', credentials).generate({
      profile: configuration.profile,
      message: 'Kapan buka?',
      chatId: 'test-chat',
      configuration,
    });
    assert.equal(capturedInstructions, [
      'Gaya bicara: Hangat dan langsung ke inti.',
      'Pengetahuan AI:',
      'Nama: Kedai Kopi',
      'Jenis layanan: Layanan pelanggan',
      'Jam operasional: Senin–Minggu, 08.00–21.00 WIB',
      '[FAQ] Jam buka: Setiap hari pukul 08.00–21.00.',
    ].join('\n'));
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('provider defaults use current API model identifiers', () => {
  assert.deepEqual(DEFAULT_PROVIDER_MODELS, {
    openai: 'gpt-6-luna',
    gemini: 'gemini-3.1-flash-lite',
    anthropic: 'claude-haiku-5-5',
    deepseek: 'deepseek-flash',
    groq: 'openai/gpt-oss-20b',
  });
});
