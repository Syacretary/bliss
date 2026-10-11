import assert from 'node:assert/strict';
import test from 'node:test';
import { defaultBotConfiguration, mergeBotConfiguration, normalizeBotConfiguration } from './bot-config.js';
import { LocalStarterReplyProvider, ReplyProviderRegistry } from './reply-provider.js';

test('dashboard patches preserve unrelated settings and are canonicalized', () => {
  const current = defaultBotConfiguration({ purpose: 'customerService', businessName: 'Kopi Senja' });
  const next = mergeBotConfiguration(current, {
    assistant: { displayName: 'Nara', rules: [{ id: 'hours', enabled: true, keywords: ['jam buka'], response: 'Kami buka pukul 09.00.' }] },
  });

  assert.equal(next.profile.businessName, 'Kopi Senja');
  assert.equal(next.assistant.displayName, 'Nara');
  assert.equal(next.behavior.autoReply, true);
});

test('invalid provider secret fields are not retained in normalized configuration', () => {
  const input = {
    ...defaultBotConfiguration(),
    apiKey: 'must-not-be-stored',
    provider: { id: 'local-template', apiKey: 'also-not-stored' },
  };
  const normalized = normalizeBotConfiguration(input);
  assert.equal('apiKey' in normalized, false);
  assert.equal('apiKey' in normalized.provider, false);
});

test('reply provider applies keyword rules and interpolates business settings', async () => {
  const configuration = mergeBotConfiguration(defaultBotConfiguration({ purpose: 'customerService', businessName: 'Kopi Senja' }), {
    assistant: {
      rules: [{ id: 'menu', enabled: true, keywords: ['menu', 'daftar produk'], response: 'Ini menu {{businessName}}.' }],
    },
  });
  const provider = new ReplyProviderRegistry().register('local-template', new LocalStarterReplyProvider());
  const response = await provider.generate({
    profile: configuration.profile,
    message: 'Boleh kirim MENU?',
    chatId: 'local-test',
    configuration,
  });
  assert.equal(response, 'Ini menu Kopi Senja.');
});

test('disabled automation returns no reply', async () => {
  const configuration = mergeBotConfiguration(defaultBotConfiguration(), { behavior: { autoReply: false } });
  const provider = new LocalStarterReplyProvider();
  assert.equal(await provider.generate({ profile: configuration.profile, message: 'Halo', chatId: 'local-test', configuration }), null);
});

test('v1 configuration migrates to the Dashboardv2 contract', () => {
  const legacy = {
    schemaVersion: 1,
    profile: { purpose: 'customerService', businessName: 'Toko Bliss' },
    assistant: { displayName: 'Nara', defaultReply: 'Halo', rules: [] },
    behavior: { autoReply: true, cooldownSeconds: 4, maxReplyLength: 500 },
    provider: { id: 'local-template' },
  };
  const migrated = normalizeBotConfiguration(legacy);
  assert.equal(migrated.schemaVersion, 2);
  assert.equal(migrated.profile.businessName, 'Toko Bliss');
  assert.equal(migrated.style.preset, 'friendly');
  assert.equal(migrated.privacy.allowExternalProcessing, false);
});

test('nested dashboard customization patches preserve sibling style and privacy settings', () => {
  const current = defaultBotConfiguration();
  const next = mergeBotConfiguration(current, {
    style: { preset: 'custom', customText: 'Gunakan bahasa sederhana.' },
    privacy: { allowExternalProcessing: true },
    commands: [{ id: 'promo', trigger: '!promo', response: 'Promo {{businessName}}', enabled: true }],
  });
  assert.deepEqual(next.style, { preset: 'custom', customText: 'Gunakan bahasa sederhana.' });
  assert.equal(next.privacy.logConversations, current.privacy.logConversations);
  assert.equal(next.commands[0]?.trigger, '!promo');
});

test('legacy emoji and response length slider values are ignored and AI knowledge is retained', () => {
  const legacy = {
    ...defaultBotConfiguration(),
    style: { preset: 'friendly', customText: '', emojiLevel: 0.9, responseLength: 0.1 },
    knowledge: [{ kind: 'faq', title: 'Jam buka', content: 'Setiap hari pukul 08.00.' }],
  };
  const normalized = normalizeBotConfiguration(legacy);
  assert.deepEqual(normalized.style, { preset: 'friendly', customText: '' });
  assert.deepEqual(normalized.knowledge, legacy.knowledge);
});
