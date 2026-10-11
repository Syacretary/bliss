import type { BotConfiguration, KnowledgeEntry } from './bot-config.js';

const stopWords = new Set([
  'apa', 'ada', 'adalah', 'agar', 'akan', 'atau', 'bisa', 'dan', 'dari', 'dengan',
  'di', 'ini', 'itu', 'ke', 'kami', 'kamu', 'karena', 'lebih', 'mau', 'oleh',
  'pada', 'para', 'saya', 'yang', 'untuk', 'ya', 'the', 'is', 'are', 'can',
]);

function terms(value: string): string[] {
  return value.toLocaleLowerCase('id-ID')
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .match(/[\p{L}\p{N}]{2,}/gu)
    ?.filter((term) => !stopWords.has(term)) ?? [];
}

/** Split around paragraph/sentence boundaries, only falling back to words for long lines. */
export function splitKnowledge(entry: KnowledgeEntry, maxCharacters = 1_800): KnowledgeEntry[] {
  const paragraphs = entry.content.split(/\n\s*\n|(?<=\n)/u).map((part) => part.trim()).filter(Boolean);
  const chunks: string[] = [];
  let current = '';
  const append = (part: string) => {
    const next = current ? `${current}\n${part}` : part;
    if (next.length <= maxCharacters) {
      current = next;
      return;
    }
    if (current) chunks.push(current);
    current = '';
    if (part.length <= maxCharacters) {
      current = part;
      return;
    }
    let fragment = '';
    for (const word of part.split(/\s+/u)) {
      const candidate = fragment ? `${fragment} ${word}` : word;
      if (candidate.length > maxCharacters && fragment) {
        chunks.push(fragment);
        fragment = word;
      } else fragment = candidate;
    }
    current = fragment;
  };
  for (const paragraph of paragraphs.length ? paragraphs : [entry.content]) append(paragraph);
  if (current) chunks.push(current);
  return chunks.map((content, index) => ({
    ...entry,
    title: chunks.length > 1 ? `${entry.title} · ${index + 1}` : entry.title,
    content,
  }));
}

/** Small, dependency-free local lexical retrieval; no embedding API or database needed. */
export function retrieveKnowledge(configuration: BotConfiguration, query: string): KnowledgeEntry[] {
  const queryTerms = [...new Set(terms(query))];
  if (!queryTerms.length) return [];
  const querySet = new Set(queryTerms);
  const scored = configuration.knowledge.flatMap((entry) => splitKnowledge(entry).map((chunk) => {
    const bodyTerms = terms(chunk.content);
    const titleTerms = terms(chunk.title);
    let score = 0;
    for (const term of querySet) {
      if (titleTerms.includes(term)) score += 3;
      const count = bodyTerms.filter((candidate) => candidate === term).length;
      score += Math.min(2, count) * 1.25;
      if (term.length >= 4 && chunk.content.toLocaleLowerCase('id-ID').includes(term)) score += 0.35;
    }
    const coverage = querySet.size ? querySet.size / bodyTerms.length : 0;
    return { chunk, score: score + Math.min(0.5, coverage) };
  }))
    .filter((item) => item.score >= 1.25)
    .sort((a, b) => b.score - a.score)
    .slice(0, 4);
  let budget = 7_000;
  const selected: KnowledgeEntry[] = [];
  for (const { chunk } of scored) {
    const cost = chunk.title.length + chunk.content.length;
    if (cost > budget) continue;
    selected.push(chunk);
    budget -= cost;
  }
  return selected;
}

export function coreProfile(configuration: BotConfiguration): string {
  const profile = configuration.profile;
  const purpose = profile.purpose === 'customerService'
    ? 'Layanan pelanggan'
    : profile.purpose === 'community'
      ? 'Komunitas'
      : profile.purpose === 'personal'
        ? 'Asisten pribadi'
        : profile.purposeOther?.trim() || 'Bisnis';
  const lines = [
    profile.businessName ? `Nama: ${profile.businessName}` : '',
    `Jenis layanan: ${purpose}`,
    profile.businessHours ? `Jam operasional: ${profile.businessHours}` : '',
    profile.volumeIndex === undefined ? '' : `Volume pesan harian: sekitar ${profile.volumeIndex}`,
  ].filter(Boolean);
  return lines.join('\n');
}
