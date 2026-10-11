import makeWASocket, {
  BufferJSON,
  initAuthCreds,
  makeCacheableSignalKeyStore,
  type AuthenticationState,
  type SignalDataTypeMap,
  type WASocket,
} from 'baileys';
import { pino } from 'pino';
import { BotError, type SessionStore } from './contracts.js';

const logger = pino({ level: 'silent' });

function encode(value: unknown): string {
  return JSON.stringify(value, BufferJSON.replacer);
}

function decode<T>(value: string): T {
  return JSON.parse(value, BufferJSON.reviver) as T;
}

export class BaileysSession {
  private saveQueue: Promise<void> = Promise.resolve();
  private state!: AuthenticationState;
  private socket!: WASocket;
  private keyMap: Record<string, Record<string, unknown>> = {};

  constructor(private readonly store: SessionStore) {}

  async open(): Promise<WASocket> {
    const stored = await this.store.read();
    const creds = stored?.creds
      ? decode<AuthenticationState['creds']>(String(stored.creds))
      : initAuthCreds();
    this.keyMap = stored?.keys ? decode<Record<string, Record<string, unknown>>>(String(stored.keys)) : {};

    const keys = {
      get: async <T extends keyof SignalDataTypeMap>(type: T, ids: string[]) => {
        const bucket = this.keyMap[type] ?? {};
        const result: { [id: string]: SignalDataTypeMap[T] } = {};
        for (const id of ids) {
          const item = bucket[id];
          if (item !== undefined) result[id] = decode<SignalDataTypeMap[T]>(String(item));
        }
        return result;
      },
      set: async (data: { [T in keyof SignalDataTypeMap]?: { [id: string]: SignalDataTypeMap[T] | null } }) => {
        for (const [type, entries] of Object.entries(data)) {
          const bucket = (this.keyMap[type] ??= {});
          for (const [id, value] of Object.entries(entries ?? {})) {
            if (value === null) delete bucket[id];
            else bucket[id] = encode(value);
          }
        }
        await this.persist();
      },
    };
    this.state = { creds, keys };
    this.socket = makeWASocket({
      auth: { creds, keys: makeCacheableSignalKeyStore(keys, logger) },
      logger,
      markOnlineOnConnect: false,
      syncFullHistory: false,
      shouldSyncHistoryMessage: () => false,
      emitOwnEvents: false,
    });
    this.socket.ev.on('creds.update', () => { void this.persist(); });
    await this.persist();
    return this.socket;
  }

  async persist(): Promise<void> {
    this.saveQueue = this.saveQueue.catch(() => undefined).then(async () => {
      const snapshot: Record<string, unknown> = {
        creds: encode(this.state.creds),
        keys: encode(this.keyMap),
      };
      await this.store.write(snapshot);
    });
    return this.saveQueue;
  }

  getSocket(): WASocket {
    if (!this.socket) throw new BotError('WhatsApp socket is not open.', 'SOCKET_NOT_OPEN');
    return this.socket;
  }

  end(): void {
    this.socket?.end(undefined);
  }

  async clear(): Promise<void> {
    await this.saveQueue.catch(() => undefined);
    if (this.store.clear) await this.store.clear();
    else await this.store.write({});
  }
}
