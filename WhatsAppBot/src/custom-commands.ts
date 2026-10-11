import type { BotConfiguration } from './bot-config.js';

export function matchCustomCommand(message: string, configuration: BotConfiguration): string | undefined {
  const command = message.trim().toLocaleLowerCase('id-ID');
  const match = configuration.commands.find((item) => item.enabled && item.trigger.toLocaleLowerCase('id-ID') === command);
  if (!match) return undefined;
  const businessName = configuration.profile.businessName?.trim() || 'kami';
  return match.response
    .replace(/\{\{businessName\}\}/g, businessName)
    .replace(/\{\{assistantName\}\}/g, configuration.assistant.displayName);
}
