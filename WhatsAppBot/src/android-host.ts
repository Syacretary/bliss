import { resolve } from 'node:path';
import { BotConfigurationStore } from './bot-config-store.js';
import { createDashboardApi } from './dashboard-api.js';
import { BotRuntime } from './bot-runtime.js';
import { EncryptedConversationLogStore } from './conversation-log-store.js';
import { EncryptedFileStore } from './encrypted-file-store.js';
import { DEFAULT_PROVIDER_MODELS, RemoteAiReplyProvider, REMOTE_PROVIDER_IDS } from './ai-reply-providers.js';
import { EncryptedProviderCredentialStore } from './provider-credential-store.js';
import { LocalStarterReplyProvider, ReplyProviderRegistry } from './reply-provider.js';
import { loadPluginStore } from './plugin-registry.js';

const [runtimeDirectory, dataDirectory, cacheDirectory, portArgument, accessToken] = process.argv.slice(2);
const sessionKey = process.env.BLISS_SESSION_KEY;
const port = Number(portArgument);
if (!runtimeDirectory || !dataDirectory || !cacheDirectory || !Number.isInteger(port) || typeof accessToken !== 'string' || !sessionKey) {
  throw new Error('Android runtime arguments are missing.');
}

process.chdir(runtimeDirectory);
process.env.TMPDIR = cacheDirectory;
process.env.HOME = dataDirectory;

const providers = new ReplyProviderRegistry()
  .register('local-template', new LocalStarterReplyProvider(), { name: 'Bliss offline', requiresApiKey: false, external: false });
const credentials = new EncryptedProviderCredentialStore(
  new EncryptedFileStore(resolve(dataDirectory, 'bliss-provider-credentials.enc'), sessionKey),
);
for (const id of REMOTE_PROVIDER_IDS) {
  const names: Record<typeof id, string> = {
    openai: 'OpenAI', gemini: 'Google Gemini', anthropic: 'Anthropic Claude', deepseek: 'DeepSeek', groq: 'Groq',
  };
  providers.register(id, new RemoteAiReplyProvider(id, credentials), {
    name: names[id], requiresApiKey: true, external: true, defaultModel: DEFAULT_PROVIDER_MODELS[id],
    ...(id === 'groq' ? { notice: 'Menggunakan GPT-OSS 20B pada Groq Free tier; kuota aktual mengikuti limit akun Groq.' } : {}),
  });
}
const configurationStore = new BotConfigurationStore(
  new EncryptedFileStore(resolve(dataDirectory, 'bliss-config.enc'), sessionKey),
);
const runtime = new BotRuntime(
  new EncryptedFileStore(resolve(dataDirectory, 'bliss-whatsapp.enc'), sessionKey),
  providers,
  new EncryptedConversationLogStore(new EncryptedFileStore(resolve(dataDirectory, 'bliss-conversations.enc'), sessionKey)),
  await loadPluginStore(resolve(runtimeDirectory, 'plugin-store')),
);
const configurationReady = configurationStore.read().then((configuration) => runtime.configure(configuration));
const api = createDashboardApi({ runtime, configurationStore, providers, credentials, accessToken, configurationReady });

api.on('error', () => { /* Keep secrets and transport details out of logcat. */ });
api.listen(port, '127.0.0.1');
