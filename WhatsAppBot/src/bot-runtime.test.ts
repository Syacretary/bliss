import assert from 'node:assert/strict';
import test from 'node:test';
import { reconnectDelayMs } from './bot-runtime.js';

test('WhatsApp reconnect backoff grows with jitter and stays bounded', () => {
  assert.equal(reconnectDelayMs(1, () => 0), 800);
  assert.equal(reconnectDelayMs(1, () => 1), 1_200);
  assert.equal(reconnectDelayMs(2, () => 0), 1_600);
  assert.equal(reconnectDelayMs(5, () => 0), 12_800);
  assert.equal(reconnectDelayMs(8, () => 1), 60_000);
  assert.throws(() => reconnectDelayMs(0), RangeError);
});
