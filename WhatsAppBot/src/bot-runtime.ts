import { EventEmitter } from 'node:events';
import { DisconnectReason, type WAMessage, type WASocket } from 'baileys';
import { BaileysSession } from './baileys-session.js';
import { defaultBotConfiguration, normalizeBotConfiguration, type BotConfiguration } from './bot-config.js';
import { BotError, type BotOptions, type ConnectionStatus, type ConversationAnalytics, type ConversationDirection, type ConversationLogStore, type ConversationMessage, type ReplyProvider, type RuntimeEvent, type SessionStore } from './contracts.js';
import { opaqueConversationId } from './conversation-log-store.js';
import type { BotPluginRegistry } from './plugin-registry.js';

const MAX_RECONNECT_ATTEMPTS = 8;
const STABLE_CONNECTION_MS = 30_000;
const REPLY_TIMEOUT_MS = 25_000;
const HANDOFF_REMINDER_MS = 30 * 60_000;

export function reconnectDelayMs(attempt: number, random = Math.random): number {
  if (!Number.isInteger(attempt) || attempt < 1) {
    throw new RangeError('Reconnect attempt must be a positive integer.');
  }
  const ceiling = 60_000;
  const exponential = Math.min(ceiling, 1_000 * 2 ** (attempt - 1));
  const jitter = 0.8 + Math.min(1, Math.max(0, random())) * 0.4;
  return Math.min(ceiling, Math.round(exponential * jitter));
}

/** Local-first bot lifecycle. It deliberately responds only to direct, new text messages. */
export class BotRuntime extends EventEmitter {
  private options: BotOptions | undefined = undefined;
  private status: ConnectionStatus = 'idle';
  private session: BaileysSession | undefined = undefined;
  private socket: WASocket | undefined = undefined;
  private stopRequested = false;
  private pairingRequested = false;
  private reconnectAttempts = 0;
  private reconnectTimer: NodeJS.Timeout | undefined = undefined;
  private stableConnectionTimer: NodeJS.Timeout | undefined = undefined;
  private readonly seenMessages = new Map<string, number>();
  private readonly lastReplyAt = new Map<string, number>();
  private readonly automaticHandoffs = new Map<string, number>();
  private readonly chatQueues = new Map<string, Promise<void>>();
  private configuration: BotConfiguration = defaultBotConfiguration();

  constructor(
    private readonly sessionStore: SessionStore,
    private readonly replies: ReplyProvider,
    private readonly conversationLogs?: ConversationLogStore,
    private readonly plugins?: BotPluginRegistry,
  ) {
    super();
  }

  get connectionStatus(): ConnectionStatus {
    return this.status;
  }

  getConfiguration(): BotConfiguration {
    return structuredClone(this.configuration);
  }

  pluginStore() {
    return this.plugins?.list() ?? [];
  }

  /** Hot-apply dashboard changes without reconnecting the WhatsApp socket. */
  configure(configuration: unknown): BotConfiguration {
    const normalized = normalizeBotConfiguration(configuration);
    this.plugins?.validateInstalled(normalized.plugins);
    this.configuration = normalized;
    if (this.options) this.options = { ...this.options, profile: this.configuration.profile };
    return this.getConfiguration();
  }

  async listConversations(limit = 50) {
    return this.conversationLogs?.list(limit) ?? [];
  }

  async conversationMessages(conversationId: string, limit = 100): Promise<ConversationMessage[]> {
    return this.conversationLogs?.messages(conversationId, limit) ?? [];
  }

  async conversationAnalytics(days: 1 | 7, utcOffsetMinutes: number): Promise<ConversationAnalytics> {
    if (!this.conversationLogs) {
      throw new BotError('Conversation history is not configured.', 'CONVERSATION_STORE_UNAVAILABLE');
    }
    return this.conversationLogs.analytics(days, utcOffsetMinutes);
  }

  async testReply(message: string): Promise<string> {
    const configuration = this.configuration;
    if (!configuration.privacy.allowExternalProcessing) {
      throw new BotError('External AI processing consent is required.', 'EXTERNAL_PROCESSING_CONSENT_REQUIRED');
    }
    const profile = this.options?.profile ?? configuration.profile;
    this.log('INFO', `Uji AI dimulai · provider ${configuration.provider.id} · model ${configuration.provider.model ?? 'default'}.`);
    let timeout: NodeJS.Timeout | undefined;
    try {
      const text = await Promise.race([
        this.replies.generate({
          profile,
          message: message.slice(0, 6_000),
          chatId: 'dashboard-test',
          configuration,
          onDiagnostic: (level, diagnostic) => this.log(level, diagnostic),
        }),
        new Promise<null>((resolve) => { timeout = setTimeout(() => resolve(null), REPLY_TIMEOUT_MS); }),
      ]).finally(() => { if (timeout) clearTimeout(timeout); });
      if (!text?.trim()) throw new BotError('AI provider returned an empty reply.', 'AI_PROVIDER_EMPTY_RESPONSE');
      this.log('INFO', 'Uji AI berhasil menghasilkan respons.');
      return text.trim().slice(0, configuration.behavior.maxReplyLength);
    } catch (error) {
      if (error instanceof BotError) throw error;
      const reason = error instanceof Error && /^[A-Z][A-Z0-9_]+$/.test(error.message)
        ? error.message
        : 'AI_PROVIDER_REQUEST_FAILED';
      this.log('ERROR', `Uji AI gagal · ${reason}.`);
      throw new BotError('AI provider request failed.', reason);
    }
  }

  async clearConversationHistory(): Promise<void> {
    if (!this.conversationLogs) throw new BotError('Conversation history is not configured.', 'CONVERSATION_STORE_UNAVAILABLE');
    await this.conversationLogs.clear();
  }

  async setConversationTakeover(conversationId: string, needsHuman: boolean): Promise<void> {
    if (!this.conversationLogs) throw new BotError('Conversation history is not configured.', 'CONVERSATION_STORE_UNAVAILABLE');
    await this.conversationLogs.setNeedsHuman(conversationId, needsHuman);
  }

  async sendHumanReply(conversationId: string, text: string): Promise<void> {
    const safeText = text.trim().slice(0, this.configuration.behavior.maxReplyLength);
    if (!safeText) throw new BotError('Reply text is empty.', 'EMPTY_REPLY');
    if (!this.socket || this.status !== 'connected') throw new BotError('WhatsApp is not connected.', 'NOT_CONNECTED');
    const remoteId = await this.conversationLogs?.remoteId(conversationId);
    if (!remoteId) throw new BotError('Conversation was not found.', 'CONVERSATION_NOT_FOUND');
    await this.socket.sendMessage(remoteId, { text: safeText });
    const summary = await this.conversationLogs!.summary(conversationId);
    await this.recordConversation(remoteId, summary?.displayName ?? 'Kontak', 'human', safeText);
    await this.conversationLogs!.setNeedsHuman(conversationId, true);
  }

  /** Resolves with QR/pair code, or undefined if an existing session connects directly. */
  async start(options: BotOptions): Promise<string | undefined> {
    if (this.status !== 'idle' && this.status !== 'stopped' && this.status !== 'error' && this.status !== 'loggedOut') {
      throw new BotError('Bot is already starting or connected.', 'ALREADY_RUNNING');
    }
    if (options.method === 'pairCode') {
      const number = options.phoneNumber ?? '';
      if (!/^\d{8,15}$/.test(number)) {
        throw new BotError('Pairing code requires an international phone number using digits only.', 'INVALID_PHONE_NUMBER');
      }
    }
    this.options = options;
    this.configuration = normalizeBotConfiguration({ ...this.configuration, profile: options.profile });
    this.stopRequested = false;
    this.pairingRequested = false;
    this.reconnectAttempts = 0;
    const model = this.configuration.provider.model?.trim() || '(default model)';
    this.log('INFO', `Bot mulai · provider ${this.configuration.provider.id} · model ${model} · auto-reply ${this.configuration.behavior.autoReply ? 'aktif' : 'nonaktif'} · commands ${this.configuration.commands.length} · plugins ${this.configuration.plugins.length}.`);
    if (this.configuration.commands.length) {
      this.log('WARN', 'Perintah kustom terkonfigurasi tetapi belum dieksekusi oleh runtime ini.');
    }
    this.setStatus('starting');

    return new Promise<string | undefined>((resolve, reject) => {
      let settled = false;
      const timeout = setTimeout(() => finish(new BotError('Timed out while waiting for the QR or pairing code.', 'PAIRING_TIMEOUT')), 45_000);
      const onPairing = (event: RuntimeEvent) => {
        if (event.type !== 'pairing' || settled) return;
        settled = true;
        clearTimeout(timeout);
        this.off('event', onPairing);
        this.off('event', onEvent);
        resolve(event.value);
      };
      const onEvent = (event: RuntimeEvent) => {
        if (event.type === 'status' && event.status === 'connected' && !settled) {
          settled = true;
          clearTimeout(timeout);
          this.off('event', onPairing);
          this.off('event', onEvent);
          resolve(undefined);
        } else if (event.type === 'status' && event.status === 'loggedOut' && !settled) {
          finish(new BotError(
            'WhatsApp session expired. Link the account again.',
            'SESSION_LOGGED_OUT',
          ));
        } else if (event.type === 'error' && !settled) {
          finish(new BotError(event.message, event.code));
        }
      };
      const finish = (error: Error) => {
        if (settled) return;
        settled = true;
        clearTimeout(timeout);
        this.off('event', onPairing);
        this.off('event', onEvent);
        reject(error);
        if (error instanceof BotError && error.code === 'PAIRING_TIMEOUT') void this.stop();
      };
      this.on('event', onPairing);
      this.on('event', onEvent);
      void this.openSocket();
    });
  }

  async stop(): Promise<void> {
    this.stopRequested = true;
    if (this.reconnectTimer) clearTimeout(this.reconnectTimer);
    this.reconnectTimer = undefined;
    if (this.stableConnectionTimer) clearTimeout(this.stableConnectionTimer);
    this.stableConnectionTimer = undefined;
    this.session?.end();
    this.socket = undefined;
    this.setStatus('stopped');
  }

  async disconnectAccount(): Promise<void> {
    this.stopRequested = true;
    if (this.reconnectTimer) clearTimeout(this.reconnectTimer);
    this.reconnectTimer = undefined;
    if (this.stableConnectionTimer) clearTimeout(this.stableConnectionTimer);
    this.stableConnectionTimer = undefined;
    try {
      await this.socket?.logout();
    } finally {
      this.socket = undefined;
      this.setStatus('loggedOut');
    }
  }

  get botNumber(): string | undefined {
    const id = this.socket?.user?.id;
    return id?.split(':')[0]?.split('@')[0];
  }

  private async openSocket(): Promise<void> {
    if (this.stopRequested || !this.options) return;
    try {
      const session = new BaileysSession(this.sessionStore);
      this.session = session;
      const socket = await session.open();
      this.socket = socket;
      if (!socket.authState.creds.registered) this.pairingRequested = false;
      socket.ev.on('connection.update', ({ connection, qr, lastDisconnect }) => {
        if (qr) void this.handlePairing(socket, qr);
        if (connection === 'open') {
          if (this.stableConnectionTimer) clearTimeout(this.stableConnectionTimer);
          this.stableConnectionTimer = setTimeout(() => {
            this.stableConnectionTimer = undefined;
            this.reconnectAttempts = 0;
          }, STABLE_CONNECTION_MS);
          this.setStatus('connected');
        } else if (connection === 'connecting') {
          if (this.reconnectAttempts > 0) this.setStatus('reconnecting', this.reconnectAttempts);
        } else if (connection === 'close') {
          if (this.stableConnectionTimer) clearTimeout(this.stableConnectionTimer);
          this.stableConnectionTimer = undefined;
          const code = this.disconnectCode(lastDisconnect?.error);
          if (code === DisconnectReason.loggedOut) {
            void this.session?.clear();
            this.setStatus('loggedOut');
            this.emitEvent({
              type: 'error',
              code: 'SESSION_LOGGED_OUT',
              message: 'Sesi WhatsApp berakhir. Tautkan ulang akun untuk melanjutkan.',
            });
            return;
          }
          if (!this.stopRequested) this.scheduleReconnect();
        }
      });
      socket.ev.on('messages.upsert', ({ type, messages }) => {
        if (type !== 'notify') return;
        for (const message of messages) this.enqueueMessage(message);
      });
    } catch (error) {
      this.log('WARN', `Gagal membuka koneksi WhatsApp; akan mencoba ulang (${this.safeDisconnectCode(error)}).`);
      this.scheduleReconnect();
    }
  }

  private async handlePairing(socket: WASocket, qr: string): Promise<void> {
    const options = this.options;
    if (!options) return;
    this.setStatus('awaitingPairing');
    if (options.method === 'qr') {
      this.emitEvent({ type: 'pairing', method: 'qr', value: qr });
      return;
    }
    if (this.pairingRequested || socket.authState.creds.registered) return;
    this.pairingRequested = true;
    try {
      const value = await socket.requestPairingCode(options.phoneNumber!);
      this.emitEvent({ type: 'pairing', method: 'pairCode', value });
    } catch {
      this.pairingRequested = false;
      this.setStatus('error');
      this.emitEvent({ type: 'error', code: 'PAIRING_FAILED', message: 'Could not create WhatsApp pairing data.' });
      void this.stop();
    }
  }

  private enqueueMessage(message: WAMessage): void {
    const key = message.key;
    const chatId = key.remoteJid;
    if (!chatId || key.fromMe || (!chatId.endsWith('@s.whatsapp.net') && !chatId.endsWith('@lid'))) return;
    const id = key.id;
    if (!id || this.seenMessages.has(id)) return;
    const body = this.messageText(message);
    if (!body) return;
    const now = Date.now();
    this.seenMessages.set(id, now);
    this.pruneMaps(now);
    const previous = this.chatQueues.get(chatId) ?? Promise.resolve();
    const displayName = typeof message.pushName === 'string' && message.pushName.trim()
      ? message.pushName.trim().slice(0, 100)
      : chatId.split('@')[0] || 'Kontak';
    const next = previous.catch(() => undefined).then(() => this.processMessage(chatId, body, displayName)).catch(() => undefined);
    this.chatQueues.set(chatId, next);
    void next.finally(() => {
      if (this.chatQueues.get(chatId) === next) this.chatQueues.delete(chatId);
    });
  }

  private async processMessage(chatId: string, body: string, displayName: string): Promise<void> {
    const now = Date.now();
    const configuration = this.configuration;
    const profile = this.options?.profile;
    this.log('INFO', 'Pesan WhatsApp diterima; memeriksa pengaturan balasan.');
    if (!profile) {
      this.log('WARN', 'Pesan diterima, tetapi profil bot tidak tersedia; balasan dilewati.');
      return;
    }
    const conversationId = opaqueConversationId(chatId);
    const history = configuration.privacy.logConversations && this.conversationLogs
      ? await this.conversationLogs.messages(conversationId, 8)
      : [];
    await this.recordConversation(chatId, displayName, 'incoming', body);
    this.emitEvent({ type: 'message', conversationId });
    const summary = configuration.privacy.logConversations && this.conversationLogs
      ? await this.conversationLogs.summary(conversationId)
      : undefined;
    const memoryHandoffAt = this.automaticHandoffs.get(chatId);
    if (!summary?.needsHuman && memoryHandoffAt !== undefined) {
      if (Date.now() - memoryHandoffAt >= HANDOFF_REMINDER_MS) {
        this.automaticHandoffs.set(chatId, Date.now());
        await this.sendHandoffMessage(chatId, displayName,
          'Pesanmu sudah tercatat dan masih dalam antrean tim kami. Kami akan menghubungimu sesegera mungkin.');
      } else {
        this.log('INFO', 'Balasan otomatis dilewati: percakapan menunggu tindak lanjut operator.');
      }
      return;
    }
    if (summary?.needsHuman) {
      const lastHandoff = [...history].reverse().find((message) => message.direction === 'handoff');
      const lastHuman = [...history].reverse().find((message) => message.direction === 'human');
      if (lastHandoff && (!lastHuman || lastHuman.timestamp < lastHandoff.timestamp)
          && Date.now() - lastHandoff.timestamp >= HANDOFF_REMINDER_MS) {
        await this.sendHandoffMessage(chatId, displayName,
          'Pesanmu sudah tercatat dan masih dalam antrean tim kami. Kami akan menghubungimu sesegera mungkin.');
      } else {
        this.log('INFO', 'Balasan otomatis dilewati: percakapan menunggu tindak lanjut operator.');
      }
      return;
    }
    if (!configuration.behavior.autoReply) {
      this.log('INFO', 'Balasan otomatis dilewati: auto-reply nonaktif.');
      return;
    }

    const cooldownRemaining = configuration.behavior.cooldownSeconds * 1_000 - (now - (this.lastReplyAt.get(chatId) ?? 0));
    if (cooldownRemaining > 0) {
      this.log('WARN', `Balasan ditahan oleh cooldown ${configuration.behavior.cooldownSeconds} detik · sisa sekitar ${Math.ceil(cooldownRemaining / 1_000)} detik.`);
      return;
    }

    if (this.plugins) {
      try {
        const decision = await this.plugins.beforeReply(configuration.plugins, { profile, message: body.slice(0, 6_000) });
        if (decision.action === 'suppress') {
          this.log('INFO', 'Pesan ditahan oleh plugin yang dikonfigurasi pengguna.');
          return;
        }
        if (decision.action === 'reply') {
          await this.sendBotReply(chatId, displayName, decision.text, 'command');
          return;
        }
      } catch {
        this.log('ERROR', 'Plugin praproses gagal; pesan diteruskan tanpa perubahan plugin.');
      }
    }

    let aiGenerated = false;
    const typingMessage = body;
    let typingReply = '';
    const sendPresence = async (type: 'composing' | 'paused') => {
      await this.socket?.sendPresenceUpdate(type, chatId);
    };
    try {
      await this.plugins?.onGeneratingReply(configuration.plugins, {
        chatId, message: body, sendPresence,
        onError: (pluginId) => this.log('WARN', `Plugin ${pluginId} gagal mengirim status mengetik.`),
      });
      let timeout: NodeJS.Timeout | undefined;
      let timedOut = false;
      const text = await Promise.race([
        this.replies.generate({
          profile, message: body.slice(0, 6_000), chatId, configuration, history,
          onDiagnostic: (level, message) => this.log(level, message),
        }),
        new Promise<null>((resolve) => { timeout = setTimeout(() => { timedOut = true; resolve(null); }, REPLY_TIMEOUT_MS); }),
      ]).finally(() => { if (timeout) clearTimeout(timeout); });
      if (timedOut) {
        this.log('ERROR', `Provider tidak merespons dalam ${REPLY_TIMEOUT_MS / 1_000} detik; percakapan dialihkan ke operator.`);
        await this.handoffAfterFailure(chatId, displayName, history);
        return;
      }
      if (!text?.trim()) {
        this.log('WARN', 'Provider tidak menghasilkan teks balasan; percakapan dialihkan ke operator.');
        await this.handoffAfterFailure(chatId, displayName, history);
        return;
      }
      aiGenerated = true;
      typingReply = text;
      await this.sendBotReply(chatId, displayName, text);
    } catch (error) {
      if (aiGenerated) {
        this.log('ERROR', 'Respons AI berhasil dibuat, tetapi gagal dikirim melalui WhatsApp.');
        return;
      }
      const reason = error instanceof Error && /^[A-Z][A-Z0-9_]+$/.test(error.message)
        ? error.message
        : 'UNEXPECTED_PROVIDER_ERROR';
      this.log('ERROR', `Pembuatan balasan gagal · ${reason}.`);
      this.emitEvent({ type: 'error', code: 'REPLY_FAILED', message: 'Balasan tidak dapat dibuat. Periksa provider dan koneksi.' });
      await this.handoffAfterFailure(chatId, displayName, history);
    } finally {
      await this.plugins?.afterReply(configuration.plugins, {
        chatId, message: typingMessage, replyText: typingReply, sendPresence,
        onError: (pluginId) => this.log('WARN', `Plugin ${pluginId} gagal mengakhiri status mengetik.`),
      });
    }
  }

  private async handoffAfterFailure(
    chatId: string,
    displayName: string,
    history: ConversationMessage[],
  ): Promise<void> {
    const conversationId = opaqueConversationId(chatId);
    this.automaticHandoffs.set(chatId, Date.now());
    let handoffQueued = false;
    if (this.configuration.privacy.logConversations && this.conversationLogs) {
      try {
        await this.conversationLogs.setNeedsHuman(conversationId, true);
        handoffQueued = true;
      } catch {
        this.log('WARN', 'Status tindak lanjut operator tidak dapat disimpan ke riwayat.');
      }
    }
    const ongoing = history.some((message) => message.direction === 'incoming'
      || message.direction === 'bot' || message.direction === 'human');
    const businessName = this.configuration.profile.businessName?.trim() || 'tim bisnis kami';
    const customerMessage = handoffQueued
      ? ongoing
        ? `Terima kasih, pesanmu sudah kami catat dan diteruskan ke ${businessName} agar percakapan ini bisa dilanjutkan dengan tepat. Tim kami akan segera menghubungimu kembali.`
        : `Halo! Terima kasih sudah menghubungi ${businessName}. Pesanmu sudah kami terima dan tim kami akan membalas secepatnya.`
      : ongoing
        ? 'Terima kasih, pesan tambahanmu sudah kami terima. Balasan kami mungkin sedikit tertunda, tetapi kami akan segera kembali membantu.'
        : 'Halo, terima kasih sudah menghubungi kami. Balasan kami mungkin sedikit tertunda, tetapi kami akan segera kembali membantu.';
    this.log('WARN', 'Pesan tindak lanjut manusia dikirim; balasan otomatis untuk percakapan ini ditahan.');
    await this.sendHandoffMessage(chatId, displayName, customerMessage);
  }

  private async sendHandoffMessage(chatId: string, displayName: string, text: string): Promise<void> {
    if (this.stopRequested || !this.socket) return;
    try {
      await this.socket.sendMessage(chatId, { text });
      await this.recordConversation(chatId, displayName, 'handoff', text);
    } catch {
      this.log('ERROR', 'Pesan tindak lanjut tidak dapat dikirim melalui WhatsApp.');
    }
  }

  private async sendBotReply(chatId: string, displayName: string, text: string, direction: ConversationDirection = 'bot'): Promise<void> {
    if (this.stopRequested || !this.socket) return;
    const safeText = text.trim().slice(0, this.configuration.behavior.maxReplyLength);
    if (!safeText) return;
    await this.socket.sendMessage(chatId, { text: safeText });
    this.log('INFO', 'Balasan AI berhasil dikirim ke WhatsApp.');
    this.lastReplyAt.set(chatId, Date.now());
    await this.recordConversation(chatId, displayName, direction, safeText);
  }

  private async recordConversation(remoteId: string, displayName: string, direction: ConversationDirection, text: string): Promise<void> {
    const timestamp = Date.now();
    const conversationId = opaqueConversationId(remoteId);
    if (this.configuration.privacy.logConversations && this.conversationLogs) {
      try {
        await this.conversationLogs.record({
          remoteId,
          displayName,
          direction,
          text,
          timestamp,
          retentionDays: this.configuration.privacy.retentionDays,
        });
      } catch {
        // History persistence failures must not take down a connected bot or leak message data.
      }
    }
    this.emitEvent({ type: 'conversation', conversationId, displayName, direction, text, timestamp });
  }

  private messageText(message: WAMessage): string | undefined {
    const content = message.message;
    if (!content) return undefined;
    const text = content.conversation
      ?? content.extendedTextMessage?.text
      ?? content.imageMessage?.caption
      ?? content.videoMessage?.caption;
    return typeof text === 'string' && text.trim() ? text.trim() : undefined;
  }

  private scheduleReconnect(): void {
    if (this.stopRequested || this.reconnectTimer) return;
    this.reconnectAttempts += 1;
    if (this.reconnectAttempts > MAX_RECONNECT_ATTEMPTS) {
      this.setStatus('error');
      this.emitEvent({
        type: 'error',
        code: 'RECONNECT_EXHAUSTED',
        message: 'Koneksi WhatsApp gagal pulih setelah beberapa percobaan. Periksa jaringan lalu coba mulai ulang bot.',
      });
      this.log('ERROR', 'Batas percobaan koneksi ulang tercapai. Mulai ulang bot setelah memeriksa jaringan.');
      return;
    }
    this.setStatus('reconnecting', this.reconnectAttempts);
    const delay = reconnectDelayMs(this.reconnectAttempts);
    this.log('INFO', `Mencoba menyambungkan ulang dalam ${Math.ceil(delay / 1_000)} detik (percobaan ${this.reconnectAttempts}/${MAX_RECONNECT_ATTEMPTS}).`);
    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = undefined;
      this.session?.end();
      void this.openSocket();
    }, delay);
  }

  private disconnectCode(error: unknown): number | undefined {
    if (typeof error !== 'object' || error === null || !('output' in error)) return undefined;
    const output = (error as { output?: { statusCode?: unknown } }).output;
    return typeof output?.statusCode === 'number' ? output.statusCode : undefined;
  }

  private safeDisconnectCode(error: unknown): string {
    const code = this.disconnectCode(error);
    return code === undefined ? 'koneksi terputus' : `kode ${code}`;
  }

  private pruneMaps(now: number): void {
    for (const [id, at] of this.seenMessages) if (now - at > 15 * 60_000) this.seenMessages.delete(id);
    while (this.seenMessages.size > 2_000) this.seenMessages.delete(this.seenMessages.keys().next().value!);
    for (const [chat, at] of this.lastReplyAt) if (now - at > 60 * 60_000) this.lastReplyAt.delete(chat);
    for (const [chat, at] of this.automaticHandoffs) if (now - at > 24 * 60 * 60_000) this.automaticHandoffs.delete(chat);
  }

  private setStatus(status: ConnectionStatus, attempt?: number): void {
    this.status = status;
    this.emitEvent(attempt === undefined ? { type: 'status', status } : { type: 'status', status, attempt });
  }

  private log(level: 'INFO' | 'WARN' | 'ERROR', message: string): void {
    this.emitEvent({ type: 'log', level, message });
  }

  private emitEvent(event: RuntimeEvent): void {
    this.emit('event', event);
  }
}
