import type { BotPlugin } from '../../plugin-registry.js';

const plugin: BotPlugin = {
  id: 'autotyping',
  name: 'Auto-Typing Indicator',
  version: '1.0.0',
  description: 'Menampilkan status sedang mengetik saat Bliss menyiapkan balasan WhatsApp.',
  permissions: ['whatsapp.presence'],
  settingsSchema: [
    { key: 'showWhileGenerating', label: 'Tampilkan status sedang mengetik saat Bliss menyiapkan balasan', type: 'boolean', defaultValue: true },
  ],
  validateSettings(settings) {
    return settings.configured === true && typeof settings.showWhileGenerating === 'boolean';
  },
  async onGeneratingReply({ settings, sendPresence }) {
    if (settings.showWhileGenerating === true) await sendPresence('composing');
  },
  async afterReply({ settings, sendPresence }) {
    if (settings.showWhileGenerating === true) await sendPresence('paused');
  },
};

export default plugin;
