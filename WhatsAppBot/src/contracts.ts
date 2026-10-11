import type { BotConfiguration } from './bot-config.js';

export type ConnectMethod = 'qr' | 'pairCode';

export type ConnectionStatus =
  | 'idle'
  | 'starting'
  | 'awaitingPairing'
  | 'connected'
  | 'reconnecting'
  | 'stopped'
  | 'loggedOut'
  | 'error';

export interface BotProfile {
  purpose: 'personal' | 'community' | 'customerService' | 'other';
  purposeOther?: string;
  volumeIndex?: number;
  tone?: string;
  businessName?: string;
  businessHours?: string;
  provider?: string;
}

export type RuntimeEvent =
  | { type: 'status'; status: ConnectionStatus; attempt?: number }
  | { type: 'pairing'; method: ConnectMethod; value: string }
  | { type: 'error'; code: string; message: string }
  | { type: 'log'; level: 'INFO' | 'WARN' | 'ERROR'; message: string }
  | { type: 'message'; conversationId: string }
  | { type: 'conversation'; conversationId: string; displayName: string; direction: ConversationDirection; text: string; timestamp: number };

export type ConversationDirection = 'incoming' | 'bot' | 'command' | 'human' | 'handoff';

export interface ConversationMessage {
  id: string;
  direction: ConversationDirection;
  text: string;
  timestamp: number;
}

export interface ConversationSummary {
  id: string;
  displayName: string;
  lastMessage: string;
  lastDirection: ConversationDirection;
  lastActivity: number;
  messageCount: number;
  needsHuman: boolean;
}

export interface ConversationAnalytics {
  generatedAt: number;
  period: { days: 1 | 7; start: number; end: number; utcOffsetMinutes: number };
  totals: {
    incomingMessages: number;
    botReplies: number;
    humanReplies: number;
    activeConversations: number;
    needsHuman: number;
    responseCount: number;
    averageResponseMs: number;
    estimatedMinutesSaved: number;
  };
  hourlyIncoming: number[];
  hourlyBotReplies: number[];
  hourlyActiveConversations: number[];
  daily: Array<{ date: string; incoming: number; botReplies: number; humanReplies: number; activeConversations: number }>;
  topics: Array<{ label: string; count: number }>;
}

export interface ConversationLogStore {
  record(input: { remoteId: string; displayName: string; direction: ConversationDirection; text: string; timestamp?: number; retentionDays: number }): Promise<ConversationMessage>;
  list(limit: number): Promise<ConversationSummary[]>;
  messages(conversationId: string, limit: number): Promise<ConversationMessage[]>;
  analytics(days: 1 | 7, utcOffsetMinutes: number): Promise<ConversationAnalytics>;
  remoteId(conversationId: string): Promise<string | undefined>;
  summary(conversationId: string): Promise<ConversationSummary | undefined>;
  setNeedsHuman(conversationId: string, needsHuman: boolean): Promise<void>;
  clear(): Promise<void>;
}

export interface BotOptions {
  profile: BotProfile;
  method: ConnectMethod;
  /** International digits only, e.g. 628123456789. Required for pairCode. */
  phoneNumber?: string;
}

export interface ReplyProvider {
  generate(input: {
    profile: BotProfile;
    message: string;
    chatId: string;
    configuration: BotConfiguration;
    history?: ConversationMessage[];
    /** Safe diagnostic messages; credential values and message content must never be included. */
    onDiagnostic?: (level: 'INFO' | 'WARN' | 'ERROR', message: string) => void;
  }): Promise<string | null>;
}

export interface ProviderCredentialStore {
  set(providerId: string, apiKey: string): Promise<void>;
  has(providerId: string): Promise<boolean>;
  get(providerId: string): Promise<string | undefined>;
  remove(providerId: string): Promise<void>;
}

export interface SessionStore {
  read(): Promise<Record<string, unknown> | undefined>;
  write(value: Record<string, unknown>): Promise<void>;
  /** Permanently remove stored data and recoverable snapshots, e.g. on logout. */
  clear?(): Promise<void>;
}

export class BotError extends Error {
  constructor(message: string, readonly code: string) {
    super(message);
    this.name = 'BotError';
  }
}
