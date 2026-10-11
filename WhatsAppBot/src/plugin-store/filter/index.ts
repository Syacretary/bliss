import type { BotPlugin } from '../../plugin-registry.js';

const plugin: BotPlugin = {
  id: 'filter',
  name: 'Filter Kata Kasar',
  version: '1.0.0',
  description: 'Menahan pesan yang berisi kata dalam daftar filter sebelum dikirim ke provider AI.',
  settingsSchema: [
    { key: 'blockedKeywords', label: 'Kata yang ditahan (pisahkan dengan koma)', type: 'text', defaultValue: '' },
    { key: 'notice', label: 'Pesan pengingat (kosongkan untuk tidak membalas)', type: 'text', defaultValue: 'Mohon gunakan bahasa yang sopan agar kami bisa membantu dengan baik.' },
  ],
  validateSettings(settings) {
    return settings.configured === true
      && typeof settings.blockedKeywords === 'string'
      && typeof settings.notice === 'string';
  },
  beforeReply({ message, settings }) {
    const keywords = String(settings.blockedKeywords ?? '').split(',').map((item) => item.trim().toLocaleLowerCase('id-ID')).filter(Boolean);
    if (!keywords.some((keyword) => message.toLocaleLowerCase('id-ID').includes(keyword))) {
      return { action: 'continue', message };
    }
    return typeof settings.notice === 'string' && settings.notice.trim()
      ? { action: 'reply', text: settings.notice.trim() }
      : { action: 'suppress' };
  },
};

export default plugin;
