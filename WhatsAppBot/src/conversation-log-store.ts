import { createHash, randomUUID } from 'node:crypto';
import type { ConversationAnalytics, ConversationDirection, ConversationLogStore, ConversationMessage, ConversationSummary, SessionStore } from './contracts.js';

interface StoredConversation {
  id: string;
  remoteId: string;
  displayName: string;
  needsHuman: boolean;
  messages: ConversationMessage[];
}

const MAX_MESSAGES = 3_000;
const MAX_CONVERSATIONS = 500;
const DAY_MS = 86_400_000;
const TOPIC_STOP_WORDS = new Set([
  'yang', 'dan', 'atau', 'untuk', 'dengan', 'dari', 'dalam', 'pada', 'ini', 'itu',
  'saya', 'aku', 'kami', 'kita', 'anda', 'kamu', 'dia', 'mereka', 'nya', 'ke',
  'di', 'ada', 'apa', 'apakah', 'bagaimana', 'berapa', 'kapan', 'dimana', 'mana',
  'halo', 'hai', 'kak', 'min', 'dong', 'ya', 'kah', 'bisa', 'boleh', 'mohon',
  'tolong', 'terima', 'kasih', 'makasih', 'kakak', 'sudah', 'belum', 'tidak',
  'enggak', 'nggak', 'gak', 'aja', 'saja', 'pakai', 'buat', 'mau', 'akan',
]);

export function opaqueConversationId(remoteId: string): string {
  return createHash('sha256').update(remoteId).digest('base64url').slice(0, 24);
}

/** Encrypted append-only conversation history with bounded retention and opaque UI IDs. */
export class EncryptedConversationLogStore implements ConversationLogStore {
  private queue: Promise<void> = Promise.resolve();

  constructor(private readonly store: SessionStore) {}

  async record(input: { remoteId: string; displayName: string; direction: ConversationDirection; text: string; timestamp?: number; retentionDays: number }): Promise<ConversationMessage> {
    return this.mutate(async (items) => {
      const timestamp = input.timestamp ?? Date.now();
      const conversationId = opaqueConversationId(input.remoteId);
      let conversation = items.find((item) => item.id === conversationId);
      if (!conversation) {
        conversation = { id: conversationId, remoteId: input.remoteId, displayName: input.displayName || 'Kontak', needsHuman: false, messages: [] };
        items.push(conversation);
      }
      if (input.displayName && input.displayName !== 'Kontak') conversation.displayName = input.displayName.slice(0, 100);
      const message: ConversationMessage = {
        id: randomUUID(),
        direction: input.direction,
        text: input.text.slice(0, 4_000),
        timestamp,
      };
      conversation.messages.push(message);
      const cutoff = timestamp - input.retentionDays * 86_400_000;
      for (const item of items) item.messages = item.messages.filter((entry) => entry.timestamp >= cutoff);
      for (let index = items.length - 1; index >= 0; index--) if (!items[index]!.messages.length) items.splice(index, 1);
      let count = items.reduce((total, item) => total + item.messages.length, 0);
      while (count > MAX_MESSAGES) {
        const oldest = items.reduce<StoredConversation | undefined>((previous, item) => {
          if (!item.messages.length) return previous;
          return !previous || item.messages[0]!.timestamp < previous.messages[0]!.timestamp ? item : previous;
        }, undefined);
        if (!oldest) break;
        oldest.messages.shift();
        count--;
        if (!oldest.messages.length) items.splice(items.indexOf(oldest), 1);
      }
      while (items.length > MAX_CONVERSATIONS) {
        const oldest = items.reduce((previous, item) => item.messages.at(-1)!.timestamp < previous.messages.at(-1)!.timestamp ? item : previous);
        items.splice(items.indexOf(oldest), 1);
      }
      return { value: message, items };
    });
  }

  async list(limit: number): Promise<ConversationSummary[]> {
    await this.queue;
    const items = await this.readItems();
    return items
      .filter((item) => item.messages.length > 0)
      .map((item): ConversationSummary => {
        const last = item.messages.at(-1)!;
        return {
          id: item.id,
          displayName: item.displayName,
          lastMessage: last.text,
          lastDirection: last.direction,
          lastActivity: last.timestamp,
          messageCount: item.messages.length,
          needsHuman: item.needsHuman,
        };
      })
      .sort((a, b) => b.lastActivity - a.lastActivity)
      .slice(0, Math.max(1, Math.min(100, Math.floor(limit))));
  }

  async messages(conversationId: string, limit: number): Promise<ConversationMessage[]> {
    await this.queue;
    const conversation = (await this.readItems()).find((item) => item.id === conversationId);
    if (!conversation) return [];
    return conversation.messages.slice(-Math.max(1, Math.min(500, Math.floor(limit))));
  }

  async analytics(days: 1 | 7, utcOffsetMinutes: number): Promise<ConversationAnalytics> {
    await this.queue;
    const now = Date.now();
    const offsetMs = Math.max(-840, Math.min(840, Math.trunc(utcOffsetMinutes))) * 60_000;
    const localNow = new Date(now + offsetMs);
    const localMidnight = Date.UTC(
      localNow.getUTCFullYear(), localNow.getUTCMonth(), localNow.getUTCDate(),
    );
    const start = localMidnight - (days - 1) * DAY_MS - offsetMs;
    const items = await this.readItems();
    const activeItems = items
      .map((item) => ({
        ...item,
        messages: item.messages
          .filter((message) => message.timestamp >= start && message.timestamp <= now)
          .sort((a, b) => a.timestamp - b.timestamp),
      }))
      .filter((item) => item.messages.length > 0);
    const hourlyIncoming = Array<number>(24).fill(0);
    const hourlyBotReplies = Array<number>(24).fill(0);
    const hourlyConversations = Array.from({ length: 24 }, () => new Set<string>());
    const daily = Array.from({ length: days }, (_, index) => {
      const date = new Date(localMidnight - (days - index - 1) * DAY_MS)
        .toISOString().slice(0, 10);
      return { date, incoming: 0, botReplies: 0, humanReplies: 0, activeConversations: 0 };
    });
    const dailyConversations = daily.map(() => new Set<string>());
    const dailyIndex = new Map(daily.map((bucket, index) => [bucket.date, index]));
    const topicCounts = new Map<string, number>();
    let incomingMessages = 0;
    let botReplies = 0;
    let humanReplies = 0;
    let responseCount = 0;
    let totalResponseMs = 0;

    for (const item of activeItems) {
      for (let index = 0; index < item.messages.length; index++) {
        const message = item.messages[index]!;
        const localDate = new Date(message.timestamp + offsetMs);
        const bucketIndex = dailyIndex.get(localDate.toISOString().slice(0, 10));
        const hour = localDate.getUTCHours();
        hourlyConversations[hour]!.add(item.id);
        if (bucketIndex !== undefined) dailyConversations[bucketIndex]!.add(item.id);
        if (message.direction === 'incoming') {
          incomingMessages++;
          hourlyIncoming[localDate.getUTCHours()]!++;
          if (bucketIndex !== undefined) daily[bucketIndex]!.incoming++;
          const tokens = message.text.toLocaleLowerCase('id-ID')
            .normalize('NFKD')
            .replace(/[\u0300-\u036f]/g, '')
            .replace(/[^\p{L}\p{N}\s]/gu, ' ')
            .split(/\s+/u)
            .filter((word) => word.length >= 3 && !TOPIC_STOP_WORDS.has(word));
          for (const word of new Set(tokens)) topicCounts.set(word, (topicCounts.get(word) ?? 0) + 1);

          // Pair each incoming message only with the first reply before the
          // next incoming one; this avoids counting one reply multiple times.
          for (let replyIndex = index + 1; replyIndex < item.messages.length; replyIndex++) {
            const reply = item.messages[replyIndex]!;
            if (reply.direction === 'incoming') break;
            if (reply.direction === 'bot' || reply.direction === 'human') {
              responseCount++;
              totalResponseMs += Math.max(0, reply.timestamp - message.timestamp);
              break;
            }
          }
        } else if (message.direction === 'bot') {
          botReplies++;
          hourlyBotReplies[hour]!++;
          if (bucketIndex !== undefined) daily[bucketIndex]!.botReplies++;
        } else if (message.direction === 'human') {
          humanReplies++;
          if (bucketIndex !== undefined) daily[bucketIndex]!.humanReplies++;
        }
      }
    }
    for (let index = 0; index < daily.length; index++) {
      daily[index]!.activeConversations = dailyConversations[index]!.size;
    }

    const topics = [...topicCounts.entries()]
      .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0], 'id-ID'))
      .slice(0, 5)
      .map(([label, count]) => ({ label: `${label[0]!.toLocaleUpperCase('id-ID')}${label.slice(1)}`, count }));
    return {
      generatedAt: now,
      period: { days, start, end: now, utcOffsetMinutes: Math.trunc(offsetMs / 60_000) },
      totals: {
        incomingMessages,
        botReplies,
        humanReplies,
        activeConversations: activeItems.length,
        needsHuman: activeItems.filter((item) => item.needsHuman).length,
        responseCount,
        averageResponseMs: responseCount ? Math.round(totalResponseMs / responseCount) : 0,
        // Product estimate uses the existing onboarding assumption: about 45s
        // saved for every automated bot reply. Human replies are excluded.
        estimatedMinutesSaved: Math.round(botReplies * 0.75),
      },
      hourlyIncoming,
      hourlyBotReplies,
      hourlyActiveConversations: hourlyConversations.map((conversations) => conversations.size),
      daily,
      topics,
    };
  }

  async summary(conversationId: string): Promise<ConversationSummary | undefined> {
    await this.queue;
    const conversation = (await this.readItems()).find((item) => item.id === conversationId);
    const last = conversation?.messages.at(-1);
    if (!conversation || !last) return undefined;
    return {
      id: conversation.id,
      displayName: conversation.displayName,
      lastMessage: last.text,
      lastDirection: last.direction,
      lastActivity: last.timestamp,
      messageCount: conversation.messages.length,
      needsHuman: conversation.needsHuman,
    };
  }

  async remoteId(conversationId: string): Promise<string | undefined> {
    await this.queue;
    return (await this.readItems()).find((item) => item.id === conversationId)?.remoteId;
  }

  async setNeedsHuman(conversationId: string, needsHuman: boolean): Promise<void> {
    await this.mutate(async (items) => {
      const conversation = items.find((item) => item.id === conversationId);
      if (!conversation) throw new Error('CONVERSATION_NOT_FOUND');
      conversation.needsHuman = needsHuman;
      return { value: undefined, items };
    });
  }

  async clear(): Promise<void> {
    await this.queue.catch(() => undefined);
    await this.store.write({ conversations: [] });
  }

  private async readItems(): Promise<StoredConversation[]> {
    const data = await this.store.read();
    return Array.isArray(data?.conversations) ? data.conversations as StoredConversation[] : [];
  }

  private mutate<T>(action: (items: StoredConversation[]) => Promise<{ value: T; items: StoredConversation[] }>): Promise<T> {
    const operation = this.queue.then(async () => {
      const result = await action(await this.readItems());
      await this.store.write({ conversations: result.items });
      return result.value;
    });
    this.queue = operation.then(() => undefined, () => undefined);
    return operation;
  }
}
