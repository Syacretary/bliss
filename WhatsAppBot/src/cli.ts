import { BotRuntime, EncryptedFileStore, NoReplyProvider, type BotProfile } from './index.js';

const key = process.env.BLISS_SESSION_KEY;
if (!key) throw new Error('Set BLISS_SESSION_KEY to a base64-encoded 32-byte key.');

const profile: BotProfile = {
  purpose: 'other',
  ...(process.env.BLISS_BOT_PURPOSE ? { purposeOther: process.env.BLISS_BOT_PURPOSE } : {}),
};
const store = new EncryptedFileStore(process.env.BLISS_SESSION_FILE ?? '.secrets/session.enc', key);
const runtime = new BotRuntime(store, new NoReplyProvider());

runtime.on('event', (event) => {
  if (event.type === 'status') process.stdout.write(`status: ${event.status}\n`);
});

const method = process.env.BLISS_CONNECT_METHOD === 'pairCode' ? 'pairCode' : 'qr';
const phoneNumber = process.env.BLISS_PHONE_NUMBER;
const value = await runtime.start({
  method,
  profile,
  ...(phoneNumber ? { phoneNumber } : {}),
});
if (value) {
  process.stdout.write(`${method === 'qr' ? 'Scan this QR value in WhatsApp' : 'Enter this pairing code in WhatsApp'}:\n${value}\n`);
} else {
  process.stdout.write('Existing WhatsApp session connected.\n');
}

for (const signal of ['SIGINT', 'SIGTERM'] as const) {
  process.once(signal, () => { void runtime.stop().finally(() => process.exit(0)); });
}
