import { readdir, readFile } from 'node:fs/promises';
import { resolve, dirname } from 'node:path';
import { pathToFileURL, fileURLToPath } from 'node:url';
import type { InstalledPlugin } from './bot-config.js';
import type { BotProfile } from './contracts.js';

export type PluginDecision = { action: 'continue'; message: string } | { action: 'suppress' } | { action: 'reply'; text: string };

export interface BotPlugin {
  readonly id: string;
  readonly name: string;
  readonly description: string;
  readonly version?: string;
  readonly permissions?: string[];
  readonly settingsSchema?: Array<{ key: string; label: string; type: 'boolean' | 'text' | 'number'; defaultValue: string | number | boolean }>;
  validateSettings?(settings: InstalledPlugin['settings']): boolean;
  beforeReply?(input: { profile: BotProfile; message: string; settings: InstalledPlugin['settings'] }): Promise<PluginDecision> | PluginDecision;
  onGeneratingReply?(input: { chatId: string; message: string; sendPresence: (type: 'composing' | 'paused') => Promise<void>; settings: InstalledPlugin['settings'] }): Promise<void> | void;
  afterReply?(input: { chatId: string; message: string; replyText: string; sendPresence: (type: 'composing' | 'paused') => Promise<void>; settings: InstalledPlugin['settings'] }): Promise<void> | void;
}

/** Registry accepts trusted, bundled modules only; dashboard data selects IDs and settings, never code. */
export class BotPluginRegistry {
  private readonly plugins = new Map<string, BotPlugin>();

  register(plugin: BotPlugin): this {
    if (!/^[a-z0-9][a-z0-9._-]*$/i.test(plugin.id) || this.plugins.has(plugin.id)) throw new Error('Plugin id is invalid or duplicated.');
    this.plugins.set(plugin.id, plugin);
    return this;
  }

  has(id: string): boolean {
    return this.plugins.has(id);
  }

  list(): Array<{ id: string; name: string; description: string; version?: string; permissions: string[]; settingsSchema: NonNullable<BotPlugin['settingsSchema']> }> {
    return [...this.plugins.values()].map((plugin) => ({
      id: plugin.id,
      name: plugin.name,
      description: plugin.description,
      ...(plugin.version ? { version: plugin.version } : {}),
      permissions: plugin.permissions ?? [],
      settingsSchema: plugin.settingsSchema ?? [],
    }));
  }

  validateInstalled(installed: InstalledPlugin[]): void {
    for (const setting of installed) {
      const plugin = this.plugins.get(setting.id);
      if (!plugin) throw new Error(`Plugin "${setting.id}" is not in the trusted plugin store.`);
      if (setting.enabled && !plugin.validateSettings?.(setting.settings)) {
        throw new Error(`Plugin "${setting.id}" must be customized before activation.`);
      }
      if (plugin.validateSettings && !plugin.validateSettings(setting.settings)) {
        throw new Error(`Plugin "${setting.id}" settings are invalid.`);
      }
    }
  }

  async beforeReply(installed: InstalledPlugin[], input: { profile: BotProfile; message: string }): Promise<PluginDecision> {
    let message = input.message;
    for (const setting of installed) {
      if (!setting.enabled) continue;
      const plugin = this.plugins.get(setting.id);
      if (!plugin) throw new Error(`Plugin "${setting.id}" is not registered.`);
      if (!plugin.beforeReply) continue;
      const result = await plugin.beforeReply({ ...input, message, settings: setting.settings });
      if (result.action !== 'continue') return result;
      message = result.message;
    }
    return { action: 'continue', message };
  }

  async onGeneratingReply(installed: InstalledPlugin[], input: { chatId: string; message: string; sendPresence: (type: 'composing' | 'paused') => Promise<void>; onError?: (pluginId: string, error: unknown) => void }): Promise<void> {
    for (const setting of installed) {
      if (!setting.enabled) continue;
      const plugin = this.plugins.get(setting.id);
      if (!plugin || !plugin.onGeneratingReply) continue;
      try {
        await plugin.onGeneratingReply({ ...input, settings: setting.settings });
      } catch (error) {
        input.onError?.(setting.id, error);
      }
    }
  }

  async afterReply(installed: InstalledPlugin[], input: { chatId: string; message: string; replyText: string; sendPresence: (type: 'composing' | 'paused') => Promise<void>; onError?: (pluginId: string, error: unknown) => void }): Promise<void> {
    for (const setting of installed) {
      if (!setting.enabled) continue;
      const plugin = this.plugins.get(setting.id);
      if (!plugin || !plugin.afterReply) continue;
      try {
        await plugin.afterReply({ ...input, settings: setting.settings });
      } catch (error) {
        input.onError?.(setting.id, error);
      }
    }
  }
}

interface PluginManifest {
  id: string;
  name: string;
  version: string;
  description: string;
  permissions: string[];
  settingsSchema: NonNullable<BotPlugin['settingsSchema']>;
}

/** Reads catalog metadata from plugin-store folders; implementation modules remain bundled/trusted app code. */
export async function loadPluginStore(directory = resolve(dirname(fileURLToPath(import.meta.url)), 'plugin-store')): Promise<BotPluginRegistry> {
  const registry = new BotPluginRegistry();
  const folders = (await readdir(directory, { withFileTypes: true }))
    .filter((entry) => entry.isDirectory())
    .sort((left, right) => left.name.localeCompare(right.name));
  for (const folder of folders) {
    const manifestPath = resolve(directory, folder.name, 'manifest.json');
    const manifest = JSON.parse(await readFile(manifestPath, 'utf8')) as PluginManifest;
    if (manifest.id !== folder.name || !/^[a-z0-9][a-z0-9._-]*$/i.test(manifest.id)
        || !Array.isArray(manifest.permissions) || !Array.isArray(manifest.settingsSchema)) {
      throw new Error(`Plugin manifest is invalid: ${folder.name}.`);
    }
    const implementationFolder = resolve(dirname(fileURLToPath(import.meta.url)), 'plugin-store', folder.name);
    let implementationPath = resolve(implementationFolder, 'index.js');
    try {
      await readFile(implementationPath);
    } catch {
      implementationPath = resolve(implementationFolder, 'index.ts');
    }
    const loaded = await import(pathToFileURL(implementationPath).href) as { default?: BotPlugin };
    if (!loaded.default || loaded.default.id !== manifest.id || loaded.default.name !== manifest.name
        || loaded.default.version !== manifest.version || loaded.default.description !== manifest.description
        || JSON.stringify(loaded.default.permissions ?? []) !== JSON.stringify(manifest.permissions)
        || JSON.stringify(loaded.default.settingsSchema ?? []) !== JSON.stringify(manifest.settingsSchema)) {
      throw new Error(`Plugin implementation does not match its manifest: ${manifest.id}.`);
    }
    registry.register(loaded.default);
  }
  return registry;
}
