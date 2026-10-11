abstract interface class DashboardRepository {
  Future<void> connectEvents();
  Future<DashboardAnalytics> analytics({
    required int days,
    required int utcOffsetMinutes,
  });
  Future<List<DashboardConversation>> conversations({int limit = 100});
  Future<List<DashboardMessage>> messages(String conversationId,
      {int limit = 100});
  Future<DashboardConnection> connection();
  Future<Map<String, Object?>> botConfiguration();
  Future<List<Map<String, Object?>>> pluginStore();
  Future<void> savePlugins(List<Map<String, Object?>> plugins);
  Future<Set<String>> configuredProviders();
  Future<void> configureBot({
    required Map<String, Object?> configuration,
    required String providerId,
    String? apiKey,
  });
  Future<String> testReply(String message);
  Future<void> startBot();
  Future<void> stopBot();
  Future<void> setTakeover(String conversationId, bool enabled);
  Future<void> reply(String conversationId, String text);
  Stream<Map<String, Object?>> get events;
}

class DashboardConnection {
  const DashboardConnection({required this.status, this.phone});
  final String status;
  final String? phone;
  bool get isConnected => status == 'connected';
}

class DashboardConversation {
  const DashboardConversation({
    required this.id,
    required this.displayName,
    required this.lastMessage,
    required this.lastDirection,
    required this.lastActivity,
    required this.messageCount,
    required this.needsHuman,
  });

  final String id;
  final String displayName;
  final String lastMessage;
  final String lastDirection;
  final int lastActivity;
  final int messageCount;
  final bool needsHuman;

  factory DashboardConversation.fromJson(Map<String, Object?> json) =>
      DashboardConversation(
        id: json['id'] as String? ?? '',
        displayName: json['displayName'] as String? ?? 'Kontak',
        lastMessage: json['lastMessage'] as String? ?? '',
        lastDirection: json['lastDirection'] as String? ?? 'incoming',
        lastActivity: (json['lastActivity'] as num?)?.toInt() ?? 0,
        messageCount: (json['messageCount'] as num?)?.toInt() ?? 0,
        needsHuman: json['needsHuman'] as bool? ?? false,
      );
}

class DashboardMessage {
  const DashboardMessage({
    required this.id,
    required this.direction,
    required this.text,
    required this.timestamp,
  });

  final String id;
  final String direction;
  final String text;
  final int timestamp;

  factory DashboardMessage.fromJson(Map<String, Object?> json) =>
      DashboardMessage(
        id: json['id'] as String? ?? '',
        direction: json['direction'] as String? ?? 'incoming',
        text: json['text'] as String? ?? '',
        timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
      );
}

class DashboardTopic {
  const DashboardTopic(this.label, this.count);
  final String label;
  final int count;
}

class DashboardDay {
  const DashboardDay({
    required this.date,
    required this.incoming,
    required this.botReplies,
    required this.humanReplies,
    required this.activeConversations,
  });
  final String date;
  final int incoming;
  final int botReplies;
  final int humanReplies;
  final int activeConversations;

  factory DashboardDay.fromJson(Map<String, Object?> json) => DashboardDay(
        date: json['date'] as String? ?? '',
        incoming: (json['incoming'] as num?)?.toInt() ?? 0,
        botReplies: (json['botReplies'] as num?)?.toInt() ?? 0,
        humanReplies: (json['humanReplies'] as num?)?.toInt() ?? 0,
        activeConversations:
            (json['activeConversations'] as num?)?.toInt() ?? 0,
      );
}

class DashboardAnalytics {
  const DashboardAnalytics({
    required this.loggingEnabled,
    required this.incomingMessages,
    required this.botReplies,
    required this.humanReplies,
    required this.activeConversations,
    required this.needsHuman,
    required this.responseCount,
    required this.averageResponseMs,
    required this.estimatedMinutesSaved,
    required this.hourlyIncoming,
    required this.hourlyBotReplies,
    required this.hourlyActiveConversations,
    required this.daily,
    required this.topics,
  });

  final bool loggingEnabled;
  final int incomingMessages;
  final int botReplies;
  final int humanReplies;
  final int activeConversations;
  final int needsHuman;
  final int responseCount;
  final int averageResponseMs;
  final int estimatedMinutesSaved;
  final List<int> hourlyIncoming;
  final List<int> hourlyBotReplies;
  final List<int> hourlyActiveConversations;
  final List<DashboardDay> daily;
  final List<DashboardTopic> topics;

  factory DashboardAnalytics.fromJson(Map<String, Object?> root) {
    final payload = root['analytics'] is Map<String, Object?>
        ? root['analytics'] as Map<String, Object?>
        : <String, Object?>{};
    final totals = payload['totals'] is Map<String, Object?>
        ? payload['totals'] as Map<String, Object?>
        : <String, Object?>{};
    final hourly = payload['hourlyIncoming'] is List
        ? (payload['hourlyIncoming'] as List)
            .map((value) => (value as num?)?.toInt() ?? 0)
            .toList(growable: false)
        : const <int>[];
    List<int> readHourly(String key) => payload[key] is List
        ? (payload[key] as List)
            .map((value) => (value as num?)?.toInt() ?? 0)
            .toList(growable: false)
        : const <int>[];
    final daily = payload['daily'] is List
        ? (payload['daily'] as List)
            .whereType<Map<String, Object?>>()
            .map(DashboardDay.fromJson)
            .toList(growable: false)
        : const <DashboardDay>[];
    final topics = payload['topics'] is List
        ? (payload['topics'] as List)
            .whereType<Map<String, Object?>>()
            .map((item) => DashboardTopic(
                  item['label'] as String? ?? '',
                  (item['count'] as num?)?.toInt() ?? 0,
                ))
            .toList(growable: false)
        : const <DashboardTopic>[];
    int total(String key) => (totals[key] as num?)?.toInt() ?? 0;

    return DashboardAnalytics(
      loggingEnabled: root['loggingEnabled'] as bool? ?? false,
      incomingMessages: total('incomingMessages'),
      botReplies: total('botReplies'),
      humanReplies: total('humanReplies'),
      activeConversations: total('activeConversations'),
      needsHuman: total('needsHuman'),
      responseCount: total('responseCount'),
      averageResponseMs: total('averageResponseMs'),
      estimatedMinutesSaved: total('estimatedMinutesSaved'),
      hourlyIncoming: hourly,
      hourlyBotReplies: readHourly('hourlyBotReplies'),
      hourlyActiveConversations: readHourly('hourlyActiveConversations'),
      daily: daily,
      topics: topics,
    );
  }
}
