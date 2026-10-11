import type { ProviderCredentialStore, SessionStore } from './contracts.js';

/** Provider keys are encrypted at rest and never serialized by dashboard read endpoints. */
export class EncryptedProviderCredentialStore implements ProviderCredentialStore {
  private queue: Promise<void> = Promise.resolve();

  constructor(private readonly store: SessionStore) {}

  async set(providerId: string, apiKey: string): Promise<void> {
    if (!/^[a-z0-9][a-z0-9._-]*$/i.test(providerId) || apiKey.trim().length < 8 || apiKey.length > 4_096) {
      throw new Error('PROVIDER_CREDENTIAL_INVALID');
    }
    await this.mutate(async (credentials) => { credentials[providerId] = apiKey.trim(); });
  }

  async has(providerId: string): Promise<boolean> {
    await this.queue;
    const credentials = await this.readCredentials();
    return typeof credentials[providerId] === 'string';
  }

  async get(providerId: string): Promise<string | undefined> {
    await this.queue;
    const value = (await this.readCredentials())[providerId];
    return typeof value === 'string' ? value : undefined;
  }

  async remove(providerId: string): Promise<void> {
    await this.mutate(async (credentials) => { delete credentials[providerId]; });
  }

  private async readCredentials(): Promise<Record<string, unknown>> {
    const data = await this.store.read();
    const credentials = data?.credentials;
    return typeof credentials === 'object' && credentials !== null && !Array.isArray(credentials)
      ? credentials as Record<string, unknown>
      : {};
  }

  private async mutate(action: (credentials: Record<string, unknown>) => Promise<void>): Promise<void> {
    const operation = this.queue.then(async () => {
      const credentials = await this.readCredentials();
      await action(credentials);
      await this.store.write({ credentials });
    });
    this.queue = operation.then(() => undefined, () => undefined);
    return operation;
  }
}
