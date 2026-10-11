import assert from 'node:assert/strict';
import test from 'node:test';
import { defaultBotConfiguration } from './bot-config.js';
import { coreProfile, retrieveKnowledge, splitKnowledge } from './local-knowledge.js';

test('retrieval ranks only the matching local knowledge and keeps chunks bounded', () => {
  const configuration = defaultBotConfiguration({
    purpose: 'customerService',
    businessName: 'Kopi Pagi',
  });
  configuration.knowledge = [
    { kind: 'document', title: 'Menu minuman', content: 'Kopi susu gula aren Rp22.000.\n\nAmericano Rp18.000.' },
    { kind: 'faq', title: 'Jam buka', content: 'Toko buka setiap hari pukul 08.00 sampai 21.00.' },
  ];

  const result = retrieveKnowledge(configuration, 'berapa harga kopi susu?');
  assert.equal(result.length, 1);
  assert.match(result[0]!.content, /Rp22\.000/);
  assert.doesNotMatch(result[0]!.content, /08\.00/);
  assert.ok(splitKnowledge({ kind: 'text', title: 'Panjang', content: 'kata '.repeat(2_000) })
    .every((chunk) => chunk.content.length <= 1_800));
});

test('core profile is generated locally from the business configuration', () => {
  const profile = coreProfile(defaultBotConfiguration({
    purpose: 'community',
    businessName: 'Komunitas Lari Senja',
  }));
  assert.match(profile, /Komunitas Lari Senja/);
  assert.match(profile, /Komunitas/);
});
