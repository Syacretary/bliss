import { createServer, type IncomingMessage, type Server, type ServerResponse } from 'node:http';
import { timingSafeEqual } from 'node:crypto';
import { BotConfigurationStore } from './bot-config-store.js';
import { mergeBotConfiguration, normalizeBotConfiguration } from './bot-config.js';
import { BotRuntime } from './bot-runtime.js';
import { BotError } from './contracts.js';
import { ReplyProviderRegistry } from './reply-provider.js';
import type { ProviderCredentialStore } from './contracts.js';

export interface DashboardApiOptions {
  runtime: BotRuntime;
  configurationStore: BotConfigurationStore;
  providers: ReplyProviderRegistry;
  credentials: ProviderCredentialStore;
  accessToken: string;
  configurationReady?: Promise<unknown>;
}

function authorized(request: IncomingMessage, token: string): boolean {
  const supplied = request.headers.authorization?.replace(/^Bearer\s+/i, '') ?? '';
  const left = Buffer.from(supplied);
  const right = Buffer.from(token);
  return left.length === right.length && timingSafeEqual(left, right);
}

function respond(response: ServerResponse, status: number, payload: unknown): void {
  response.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
    'x-content-type-options': 'nosniff',
  });
  response.end(JSON.stringify(payload));
}

async function readJson(request: IncomingMessage, maxBytes = 32 * 1024): Promise<Record<string, unknown>> {
  let size = 0;
  const chunks: Buffer[] = [];
  for await (const part of request) {
    const chunk = Buffer.isBuffer(part) ? part : Buffer.from(part);
    size += chunk.length;
    if (size > maxBytes) throw new Error('REQUEST_TOO_LARGE');
    chunks.push(chunk);
  }
  let value: unknown;
  try {
    value = JSON.parse(Buffer.concat(chunks).toString('utf8'));
  } catch {
    throw new Error('INVALID_BODY');
  }
  if (typeof value !== 'object' || value === null || Array.isArray(value)) throw new Error('INVALID_BODY');
  return value as Record<string, unknown>;
}

/** Authenticated loopback API kept separate from Node/Android process bootstrap. */
export function createDashboardApi(options: DashboardApiOptions): Server {
  const { runtime, configurationStore, providers, credentials, accessToken } = options;
  const configurationReady = options.configurationReady ?? configurationStore.read().then((configuration) => runtime.configure(configuration));
  const eventClients = new Set<ServerResponse>();
  let configurationMutation: Promise<void> = Promise.resolve();

  function serializeConfigurationMutation<T>(action: () => Promise<T>): Promise<T> {
    const result = configurationMutation.then(action, action);
    configurationMutation = result.then(() => undefined, () => undefined);
    return result;
  }

  return createServer(async (request, response) => {
    const remoteAddress = request.socket.remoteAddress;
    if (remoteAddress !== '127.0.0.1' && remoteAddress !== '::ffff:127.0.0.1' && remoteAddress !== '::1') {
      respond(response, 403, { error: 'LOCAL_ONLY' });
      return;
    }
    if (!authorized(request, accessToken)) {
      respond(response, 401, { error: 'UNAUTHORIZED' });
      return;
    }

    const path = new URL(request.url ?? '/', 'http://127.0.0.1').pathname;
    try {
      if (request.method === 'GET' && path === '/v1/capabilities') {
        respond(response, 200, {
          configurationSchemaVersion: 2,
          replyProviders: providers.descriptors(),
          deferredFeatures: ['customCommands'],
          supportsHotConfiguration: true,
        });
        return;
      }
      if (request.method === 'GET' && path === '/v1/config') {
        await configurationReady;
        respond(response, 200, runtime.getConfiguration());
        return;
      }
      if (request.method === 'GET' && path === '/v1/plugin-store') {
        await configurationReady;
        const installed = new Map(runtime.getConfiguration().plugins.map((plugin) => [plugin.id, plugin]));
        respond(response, 200, {
          plugins: runtime.pluginStore().map((plugin) => ({
            ...plugin,
            installed: installed.has(plugin.id),
            enabled: installed.get(plugin.id)?.enabled ?? false,
            settings: installed.get(plugin.id)?.settings ?? {},
          })),
        });
        return;
      }
      if (request.method === 'PATCH' && path === '/v1/plugins') {
        await configurationReady;
        const body = await readJson(request);
        if (!Array.isArray(body.plugins)) throw new Error('INVALID_PLUGIN_CONFIGURATION');
        const result = await serializeConfigurationMutation(async () => {
          const updated = mergeBotConfiguration(runtime.getConfiguration(), { plugins: body.plugins });
          runtime.configure(updated);
          await configurationStore.write(updated);
          return { plugins: updated.plugins };
        });
        respond(response, 200, result);
        return;
      }
      if (request.method === 'GET' && path === '/v1/providers') {
        const descriptors = await Promise.all(providers.descriptors().map(async (provider) => ({
          ...provider,
          configured: provider.requiresApiKey ? await credentials.has(provider.id) : true,
        })));
        respond(response, 200, { providers: descriptors });
        return;
      }
      if (request.method === 'POST' && path === '/v1/test-reply') {
        await configurationReady;
        const body = await readJson(request);
        if (typeof body.message !== 'string' || !body.message.trim() || body.message.length > 4_000) {
          throw new Error('INVALID_TEST_MESSAGE');
        }
        const configuration = runtime.getConfiguration();
        const descriptor = providers.descriptor(configuration.provider.id);
        if (descriptor?.external && !configuration.privacy.allowExternalProcessing) {
          throw new BotError('External AI processing consent is required.', 'EXTERNAL_PROCESSING_CONSENT_REQUIRED');
        }
        if (descriptor?.requiresApiKey && !(await credentials.has(descriptor.id))) {
          throw new BotError('Provider API credential is missing.', 'AI_PROVIDER_CREDENTIAL_MISSING');
        }
        respond(response, 200, { reply: await runtime.testReply(body.message.trim()) });
        return;
      }
      const credentialMatch = path.match(/^\/v1\/providers\/([a-z0-9._-]+)\/credential$/i);
      if (credentialMatch && request.method === 'PUT') {
        const providerId = decodeURIComponent(credentialMatch[1]!);
        const descriptor = providers.descriptor(providerId);
        if (!descriptor || !descriptor.requiresApiKey) {
          respond(response, 404, { error: 'PROVIDER_CREDENTIAL_UNSUPPORTED' });
          return;
        }
        const body = await readJson(request);
        if (typeof body.apiKey !== 'string') throw new Error('INVALID_CREDENTIAL');
        await credentials.set(providerId, body.apiKey);
        respond(response, 200, { providerId, configured: true });
        return;
      }
      if (credentialMatch && request.method === 'DELETE') {
        const providerId = decodeURIComponent(credentialMatch[1]!);
        const descriptor = providers.descriptor(providerId);
        if (!descriptor || !descriptor.requiresApiKey) {
          respond(response, 404, { error: 'PROVIDER_CREDENTIAL_UNSUPPORTED' });
          return;
        }
        await credentials.remove(providerId);
        respond(response, 200, { providerId, configured: false });
        return;
      }
      if (request.method === 'PATCH' && path === '/v1/config') {
        await configurationReady;
        // Extracted local knowledge may be larger than ordinary control calls.
        // It remains on loopback and is persisted in the encrypted config store.
        const patch = await readJson(request, 3 * 1024 * 1024);
        const result = await serializeConfigurationMutation(async () => {
          const updated = mergeBotConfiguration(runtime.getConfiguration(), patch);
          if (!providers.has(updated.provider.id)) return { unavailableProvider: true as const };
          if (updated.commands.length) return { deferredFeatures: true as const };
          runtime.configure(updated);
          await configurationStore.write(updated);
          return { configuration: runtime.getConfiguration() };
        });
        if ('unavailableProvider' in result) {
          respond(response, 422, { error: 'PROVIDER_NOT_AVAILABLE', availableProviders: providers.ids() });
          return;
        }
        if ('deferredFeatures' in result) {
          respond(response, 422, { error: 'FEATURES_DEFERRED', features: ['customCommands'] });
          return;
        }
        respond(response, 200, result.configuration);
        return;
      }
      if (request.method === 'GET' && path === '/v1/health') {
        respond(response, 200, {
          ready: true,
          node: process.versions.node,
          uptimeSeconds: Math.floor(process.uptime()),
          whatsappStatus: runtime.connectionStatus,
        });
        return;
      }
      if (request.method === 'GET' && path === '/v1/status') {
        respond(response, 200, { status: runtime.connectionStatus, botNumber: runtime.botNumber ?? null });
        return;
      }
      if (request.method === 'GET' && path === '/v1/analytics') {
        await configurationReady;
        const query = new URL(request.url ?? '/', 'http://127.0.0.1').searchParams;
        const daysValue = Number(query.get('days') ?? '1');
        const offsetValue = Number(query.get('utcOffsetMinutes') ?? '0');
        if ((daysValue !== 1 && daysValue !== 7)
          || !Number.isInteger(offsetValue) || offsetValue < -840 || offsetValue > 840) {
          throw new Error('INVALID_ANALYTICS_RANGE');
        }
        respond(response, 200, {
          loggingEnabled: runtime.getConfiguration().privacy.logConversations,
          analytics: await runtime.conversationAnalytics(daysValue, offsetValue),
        });
        return;
      }
      if (request.method === 'GET' && path === '/v1/conversations') {
        const limitValue = Number(new URL(request.url ?? '/', 'http://127.0.0.1').searchParams.get('limit') ?? '50');
        if (!Number.isInteger(limitValue) || limitValue < 1 || limitValue > 100) throw new Error('INVALID_LIMIT');
        respond(response, 200, { conversations: await runtime.listConversations(limitValue) });
        return;
      }
      if (request.method === 'DELETE' && path === '/v1/conversations') {
        await runtime.clearConversationHistory();
        respond(response, 200, { cleared: true });
        return;
      }
      const conversationRoute = path.match(/^\/v1\/conversations\/([a-zA-Z0-9_-]{24})(?:\/(messages|takeover|resume|reply))?$/);
      if (conversationRoute) {
        const conversationId = conversationRoute[1]!;
        const action = conversationRoute[2];
        if (request.method === 'GET' && action === 'messages') {
          const limitValue = Number(new URL(request.url ?? '/', 'http://127.0.0.1').searchParams.get('limit') ?? '100');
          if (!Number.isInteger(limitValue) || limitValue < 1 || limitValue > 500) throw new Error('INVALID_LIMIT');
          respond(response, 200, { messages: await runtime.conversationMessages(conversationId, limitValue) });
          return;
        }
        if (request.method === 'POST' && action === 'takeover') {
          await runtime.setConversationTakeover(conversationId, true);
          respond(response, 200, { conversationId, needsHuman: true });
          return;
        }
        if (request.method === 'POST' && action === 'resume') {
          await runtime.setConversationTakeover(conversationId, false);
          respond(response, 200, { conversationId, needsHuman: false });
          return;
        }
        if (request.method === 'POST' && action === 'reply') {
          const body = await readJson(request);
          if (typeof body.text !== 'string' || body.text.length > 4_000) throw new Error('INVALID_REPLY');
          await runtime.sendHumanReply(conversationId, body.text);
          respond(response, 200, { conversationId, sent: true });
          return;
        }
      }
      if (request.method === 'GET' && path === '/v1/events') {
        if (eventClients.size >= 3) {
          respond(response, 429, { error: 'TOO_MANY_EVENT_CLIENTS' });
          return;
        }
        response.writeHead(200, { 'content-type': 'text/event-stream', 'cache-control': 'no-store', connection: 'keep-alive' });
        response.write(`data: ${JSON.stringify({ type: 'status', status: runtime.connectionStatus })}\n\n`);
        const subscription = (event: unknown) => response.write(`data: ${JSON.stringify(event)}\n\n`);
        runtime.on('event', subscription);
        eventClients.add(response);
        const heartbeat = setInterval(() => {
          response.write(`: keepalive ${Date.now()}\n\n`);
        }, 15_000);
        response.on('close', () => {
          clearInterval(heartbeat);
          eventClients.delete(response);
          runtime.off('event', subscription);
        });
        return;
      }
      if (request.method === 'POST' && path === '/v1/start') {
        const body = await readJson(request);
        await configurationReady;
        const result = await serializeConfigurationMutation(async () => {
          let configuration = body.configuration === undefined
            ? runtime.getConfiguration()
            : normalizeBotConfiguration(body.configuration);
          if (body.profile !== undefined) configuration = mergeBotConfiguration(configuration, { profile: body.profile });
          if (!providers.has(configuration.provider.id)) return { unavailableProvider: true as const };
          if (configuration.commands.length) return { deferredFeatures: true as const };
          const provider = providers.descriptor(configuration.provider.id)!;
          if (configuration.behavior.autoReply && provider.external && !configuration.privacy.allowExternalProcessing) {
            return { consentRequired: true as const };
          }
          if (configuration.behavior.autoReply && provider.requiresApiKey && !(await credentials.has(provider.id))) {
            return { credentialMissing: true as const };
          }
          runtime.configure(configuration);
          await configurationStore.write(configuration);
          return { configuration };
        });
        if ('unavailableProvider' in result) {
          respond(response, 422, { error: 'PROVIDER_NOT_AVAILABLE', availableProviders: providers.ids() });
          return;
        }
        if ('deferredFeatures' in result) {
          respond(response, 422, { error: 'FEATURES_DEFERRED', features: ['customCommands'] });
          return;
        }
        if ('consentRequired' in result) {
          respond(response, 422, { error: 'EXTERNAL_PROCESSING_CONSENT_REQUIRED' });
          return;
        }
        if ('credentialMissing' in result) {
          respond(response, 422, { error: 'PROVIDER_CREDENTIAL_REQUIRED' });
          return;
        }
        const configuration = result.configuration;
        const method = body.method === 'pairCode' ? 'pairCode' : 'qr';
        const pairing = await runtime.start({
          profile: configuration.profile,
          method,
          ...(typeof body.phoneNumber === 'string' ? { phoneNumber: body.phoneNumber } : {}),
        });
        respond(response, 200, { pairing, status: runtime.connectionStatus });
        return;
      }
      if (request.method === 'POST' && path === '/v1/stop') {
        await runtime.stop();
        respond(response, 200, { status: runtime.connectionStatus });
        return;
      }
      if (request.method === 'POST' && path === '/v1/logout') {
        await runtime.disconnectAccount();
        respond(response, 200, { status: runtime.connectionStatus });
        return;
      }
      respond(response, 404, { error: 'NOT_FOUND' });
    } catch (error) {
      const message = error instanceof Error ? error.message : 'INTERNAL_ERROR';
      const validationError = message.startsWith('Unsupported bot configuration')
        || /\b(is invalid|must be|needs a keyword|contains an unsupported value|duplicate ids or triggers|duplicate ids)\b/i.test(message);
      const status = message === 'REQUEST_TOO_LARGE' ? 413
        : message === 'CONVERSATION_NOT_FOUND' ? 404
          : error instanceof BotError ? (error.code === 'INVALID_PHONE_NUMBER' ? 422 : 409)
            : message === 'PROVIDER_CREDENTIAL_INVALID' || message === 'INVALID_CREDENTIAL' || message === 'INVALID_REPLY' || message === 'INVALID_LIMIT' || message === 'INVALID_ANALYTICS_RANGE' || message === 'INVALID_TEST_MESSAGE' || message === 'INVALID_BODY' ? 400
            : validationError ? 422
            : 500;
      respond(response, status, {
        error: status === 500
          ? 'INTERNAL_ERROR'
          : validationError
            ? 'INVALID_CONFIGURATION'
            : error instanceof BotError
              ? error.code
              : message.slice(0, 80),
      });
    }
  });
}
