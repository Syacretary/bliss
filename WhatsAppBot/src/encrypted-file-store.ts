import { createCipheriv, createDecipheriv, randomBytes } from 'node:crypto';
import { mkdir, open, readFile, rename, rm } from 'node:fs/promises';
import { dirname } from 'node:path';
import type { SessionStore } from './contracts.js';

const MAGIC = Buffer.from('BLISSWA1');
const IV_LENGTH = 12;
const TAG_LENGTH = 16;

/** AES-256-GCM store with atomic replacement and one recoverable encrypted snapshot. */
export class EncryptedFileStore implements SessionStore {
  private readonly key: Buffer;
  private writeQueue: Promise<void> = Promise.resolve();
  private get backupPath(): string { return `${this.filePath}.bak`; }

  constructor(private readonly filePath: string, encodedKey: string) {
    this.key = Buffer.from(encodedKey, 'base64');
    if (this.key.length !== 32) {
      throw new Error('BLISS_SESSION_KEY must be a base64-encoded 32-byte key.');
    }
  }

  async read(): Promise<Record<string, unknown> | undefined> {
    let primary: Buffer | undefined;
    try {
      primary = await readFile(this.filePath);
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error;
    }
    if (primary) {
      try {
        return this.decode(primary);
      } catch (primaryError) {
        const backup = await this.readBackup();
        if (!backup) throw this.corruptError(primaryError);
        // Repair the primary without rotating the corrupt bytes into the backup.
        await this.atomicWrite(this.filePath, backup.bytes);
        return backup.value;
      }
    }

    const backup = await this.readBackup();
    if (!backup) return undefined;
    await this.atomicWrite(this.filePath, backup.bytes);
    return backup.value;
  }

  write(value: Record<string, unknown>): Promise<void> {
    const operation = this.writeQueue.catch(() => undefined).then(async () => {
      const payload = this.encode(value);
      await mkdir(dirname(this.filePath), { recursive: true, mode: 0o700 });
      try {
        const current = await readFile(this.filePath);
        // Never replace a damaged file with fresh credentials/config by accident.
        this.decode(current);
        await this.atomicWrite(this.backupPath, current);
      } catch (error) {
        if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error;
      }
      await this.atomicWrite(this.filePath, payload);
    });
    this.writeQueue = operation;
    return operation;
  }

  /** Explicit logout: remove both snapshots so a prior authenticated session cannot return. */
  async clear(): Promise<void> {
    await this.writeQueue.catch(() => undefined);
    await Promise.all([this.filePath, this.backupPath, `${this.filePath}.tmp`].map(path =>
      rm(path, { force: true }),
    ));
  }

  private encode(value: Record<string, unknown>): Buffer {
    const iv = randomBytes(IV_LENGTH);
    const cipher = createCipheriv('aes-256-gcm', this.key, iv);
    const encrypted = Buffer.concat([cipher.update(JSON.stringify(value)), cipher.final()]);
    return Buffer.concat([MAGIC, iv, cipher.getAuthTag(), encrypted]);
  }

  private decode(data: Buffer): Record<string, unknown> {
    if (data.length < MAGIC.length + IV_LENGTH + TAG_LENGTH || !data.subarray(0, MAGIC.length).equals(MAGIC)) {
      throw new Error('invalid header or truncated encrypted file');
    }
    const ivStart = MAGIC.length;
    const tagStart = ivStart + IV_LENGTH;
    const decipher = createDecipheriv('aes-256-gcm', this.key, data.subarray(ivStart, tagStart));
    decipher.setAuthTag(data.subarray(tagStart, tagStart + TAG_LENGTH));
    const plain = Buffer.concat([decipher.update(data.subarray(tagStart + TAG_LENGTH)), decipher.final()]);
    const parsed: unknown = JSON.parse(plain.toString('utf8'));
    if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
      throw new Error('decrypted content is not an object');
    }
    return parsed as Record<string, unknown>;
  }

  private async readBackup(): Promise<{ bytes: Buffer; value: Record<string, unknown> } | undefined> {
    try {
      const bytes = await readFile(this.backupPath);
      return { bytes, value: this.decode(bytes) };
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code === 'ENOENT') return undefined;
      throw this.corruptError(error);
    }
  }

  private corruptError(cause: unknown): Error {
    const error = new Error('Encrypted local data is damaged and no valid recovery snapshot is available.');
    error.name = 'EncryptedStoreCorruptError';
    (error as Error & { code: string; cause: unknown }).code = 'ENCRYPTED_STORE_CORRUPT';
    (error as Error & { cause: unknown }).cause = cause;
    return error;
  }

  private async atomicWrite(path: string, data: Buffer): Promise<void> {
    await mkdir(dirname(path), { recursive: true, mode: 0o700 });
    const temporary = `${path}.${process.pid}.${randomBytes(8).toString('hex')}.tmp`;
    try {
      const handle = await open(temporary, 'wx', 0o600);
      try {
        await handle.writeFile(data);
        await handle.sync();
      } finally {
        await handle.close();
      }
      await rename(temporary, path);
      // Directory fsync makes the rename durable on filesystems that support it.
      try {
        const directory = await open(dirname(path), 'r');
        try { await directory.sync(); } finally { await directory.close(); }
      } catch {
        // Some Android filesystems do not allow opening/syncing directories.
      }
    } finally {
      await rm(temporary, { force: true });
    }
  }
}
