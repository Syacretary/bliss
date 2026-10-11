import { defaultBotConfiguration, normalizeBotConfiguration, type BotConfiguration } from './bot-config.js';
import type { SessionStore } from './contracts.js';

/** Stores non-secret bot preferences separately from the Baileys auth state. */
export class BotConfigurationStore {
  constructor(private readonly store: SessionStore) {}

  async read(): Promise<BotConfiguration> {
    const record = await this.store.read();
    const value = record?.configuration;
    return value === undefined ? defaultBotConfiguration() : normalizeBotConfiguration(value);
  }

  async write(configuration: BotConfiguration): Promise<void> {
    await this.store.write({ configuration: normalizeBotConfiguration(configuration) });
  }
}
