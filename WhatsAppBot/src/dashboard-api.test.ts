import assert from 'node:assert/strict';
import test from 'node:test';
import { BotConfigurationStore } from './bot-config-store.js';
import { createDashboardApi } from './dashboard-api.js';
import { BotRuntime } from './bot-runtime.js';
import { EncryptedConversationLogStore } from './conversation-log-store.js';
import { LocalStarterReplyProvider, ReplyProviderRegistry } from './reply-provider.js';
import { loadPluginStore } from './plugin-registry.js';
import type { ProviderCredentialStore, SessionStore } from './contracts.js';

class MemoryStore implements SessionStore {
  value: Record<string, unknown> | undefined;
  async read() { return structuredClone(this.value); }
  async write(value: Record<string, unknown>) { this.value = structuredClone(value); }
}

class MemoryCredentials implements ProviderCredentialStore {
  private readonly values = new Map<string, string>();
  async set(id: string, value: string) { this.values.set(id, value); }
  async has(id: string) { return this.values.has(id); }
  async get(id: string) { return this.values.get(id); }
  async remove(id: string) { this.values.delete(id); }
}

test('dashboard API exposes provider credential state but never the secret', async (context) => {
  const providers = new ReplyProviderRegistry()
    .register('local-template', new LocalStarterReplyProvider(), { name: 'Bliss offline' })
    .register('openai', new LocalStarterReplyProvider(), { name: 'OpenAI', requiresApiKey: true, external: true });
  const store = new MemoryStore();
  const credentials = new MemoryCredentials();
  const conversations = new EncryptedConversationLogStore(new MemoryStore());
  const runtime = new BotRuntime(new MemoryStore(), providers, conversations, await loadPluginStore());
  const api = createDashboardApi({
    runtime,
    configurationStore: new BotConfigurationStore(store),
    providers,
    credentials,
    accessToken: 'test-token',
  });
  await new Promise<void>((resolve) => api.listen(0, '127.0.0.1', resolve));
  context.after(() => new Promise<void>((resolve, reject) => api.close((error) => error ? reject(error) : resolve())));
  const address = api.address();
  assert.ok(address && typeof address !== 'string');
  const base = `http://127.0.0.1:${address.port}`;
  const headers = { authorization: 'Bearer test-token', 'content-type': 'application/json' };

  const health = await fetch(`${base}/v1/health`, { headers });
  const healthPayload = await health.json() as {
    ready: boolean;
    node: string;
    uptimeSeconds: number;
    whatsappStatus: string;
  };
  assert.equal(health.status, 200);
  assert.equal(healthPayload.ready, true);
  assert.ok(healthPayload.node.length > 0);
  assert.ok(healthPayload.uptimeSeconds >= 0);
  assert.equal(healthPayload.whatsappStatus, 'idle');

  const saved = await fetch(`${base}/v1/providers/openai/credential`, {
    method: 'PUT', headers, body: JSON.stringify({ apiKey: 'sk-example-secret-value' }),
  });
  assert.equal(saved.status, 200);
  assert.equal((await saved.text()).includes('sk-example-secret-value'), false);

  const listed = await fetch(`${base}/v1/providers`, { headers });
  const payload = await listed.text();
  assert.equal(listed.status, 200);
  assert.equal(payload.includes('sk-example-secret-value'), false);
  assert.match(payload, /"configured":true/);

  const capabilities = await fetch(`${base}/v1/capabilities`, { headers });
  const capabilitiesPayload = await capabilities.json() as { deferredFeatures: string[] };
  assert.deepEqual(capabilitiesPayload.deferredFeatures, ['customCommands']);

  const storeResponse = await fetch(`${base}/v1/plugin-store`, { headers });
  const storePayload = await storeResponse.json() as { plugins: Array<{ id: string; installed: boolean; enabled: boolean }> };
  assert.deepEqual(storePayload.plugins.map((item) => item.id).sort(), ['autotyping', 'filter']);
  assert.equal(storePayload.plugins.every((item) => !item.installed && !item.enabled), true);

  const installPlugin = await fetch(`${base}/v1/plugins`, {
    method: 'PATCH', headers,
    body: JSON.stringify({ plugins: [{ id: 'autotyping', enabled: false, settings: { configured: true, showWhileGenerating: true } }] }),
  });
  assert.equal(installPlugin.status, 200);
  assert.equal(runtime.getConfiguration().plugins[0]?.enabled, false);
  const enablePlugin = await fetch(`${base}/v1/plugins`, {
    method: 'PATCH', headers,
    body: JSON.stringify({ plugins: [{ id: 'autotyping', enabled: true, settings: { configured: true, showWhileGenerating: true } }] }),
  });
  assert.equal(enablePlugin.status, 200);
  const rejectUnconfiguredPlugin = await fetch(`${base}/v1/plugins`, {
    method: 'PATCH', headers,
    body: JSON.stringify({ plugins: [{ id: 'autotyping', enabled: true, settings: {} }] }),
  });
  assert.equal(rejectUnconfiguredPlugin.status, 422);

  const analyticsResponse = await fetch(`${base}/v1/analytics?days=7&utcOffsetMinutes=420`, { headers });
  assert.equal(analyticsResponse.status, 200);
  const analyticsPayload = await analyticsResponse.json() as {
    loggingEnabled: boolean;
    analytics: { period: { days: number; utcOffsetMinutes: number }; totals: { incomingMessages: number }; daily: unknown[] };
  };
  assert.equal(analyticsPayload.loggingEnabled, true);
  assert.equal(analyticsPayload.analytics.period.days, 7);
  assert.equal(analyticsPayload.analytics.period.utcOffsetMinutes, 420);
  assert.equal(analyticsPayload.analytics.totals.incomingMessages, 0);
  assert.equal(analyticsPayload.analytics.daily.length, 7);

  const invalidAnalyticsRange = await fetch(`${base}/v1/analytics?days=2`, { headers });
  assert.equal(invalidAnalyticsRange.status, 400);

  const deferred = await fetch(`${base}/v1/config`, {
    method: 'PATCH', headers,
    body: JSON.stringify({ commands: [{ id: 'promo', trigger: '!promo', response: 'Promo', enabled: true }] }),
  });
  assert.equal(deferred.status, 422);
  assert.deepEqual(await deferred.json(), { error: 'FEATURES_DEFERRED', features: ['customCommands'] });

  const consentRequired = await fetch(`${base}/v1/test-reply`, {
    method: 'POST', headers, body: JSON.stringify({ message: 'Halo' }),
  });
  assert.equal(consentRequired.status, 409);

  const configured = await fetch(`${base}/v1/config`, {
    method: 'PATCH', headers,
    body: JSON.stringify({
      provider: { id: 'openai', model: 'test-model' },
      privacy: { allowExternalProcessing: true },
    }),
  });
  assert.equal(configured.status, 200);
  const testReply = await fetch(`${base}/v1/test-reply`, {
    method: 'POST', headers, body: JSON.stringify({ message: 'Halo' }),
  });
  assert.equal(testReply.status, 200);
  assert.equal((await testReply.json() as { reply: string }).reply.length > 0, true);
});
