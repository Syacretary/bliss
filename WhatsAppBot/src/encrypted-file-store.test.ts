import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { EncryptedFileStore } from './encrypted-file-store.js';

const key = Buffer.alloc(32, 7).toString('base64');

async function withStore(run: (path: string, store: EncryptedFileStore) => Promise<void>): Promise<void> {
  const directory = await mkdtemp(join(tmpdir(), 'bliss-store-test-'));
  const path = join(directory, 'session.enc');
  try { await run(path, new EncryptedFileStore(path, key)); }
  finally { await rm(directory, { recursive: true, force: true }); }
}

test('encrypted store writes and reads authenticated data', async () => {
  await withStore(async (_path, store) => {
    await store.write({ counter: 1 });
    assert.deepEqual(await store.read(), { counter: 1 });
  });
});

test('corrupt primary is recovered from the encrypted snapshot and repaired', async () => {
  await withStore(async (path, store) => {
    await store.write({ counter: 1 });
    await store.write({ counter: 2 });
    const damaged = await readFile(path);
    damaged[damaged.length - 1] ^= 0xff;
    await writeFile(path, damaged);

    assert.deepEqual(await store.read(), { counter: 1 });
    assert.deepEqual(await store.read(), { counter: 1 });
  });
});

test('corrupt primary with no valid backup fails explicitly instead of resetting data', async () => {
  await withStore(async (path, store) => {
    await store.write({ counter: 1 });
    const damaged = await readFile(path);
    damaged[0] ^= 0xff;
    await writeFile(path, damaged);
    await assert.rejects(store.read(), (error: NodeJS.ErrnoException) => error.code === 'ENCRYPTED_STORE_CORRUPT');
  });
});

test('clear removes the primary and recovery snapshot so logout cannot restore a session', async () => {
  await withStore(async (_path, store) => {
    await store.write({ authenticated: true });
    await store.write({ authenticated: true, refreshed: true });
    await store.clear();
    assert.equal(await store.read(), undefined);
  });
});
