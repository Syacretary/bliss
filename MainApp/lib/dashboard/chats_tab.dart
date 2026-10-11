import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../onboarding/common.dart';
import 'dash_state.dart';
import 'dash_widgets.dart';
import 'dashboard_repository.dart';

const _avatarColors = [
  Color(0xFFBFEFC0),
  Color(0xFFFFE9A8),
  Color(0xFFFFD3C7),
  Color(0xFFCDEBFF),
  Color(0xFFE3D4FF)
];

class ChatTile extends StatelessWidget {
  const ChatTile({super.key, required this.st, required this.index});
  final DashState st;
  final int index;
  @override
  Widget build(BuildContext context) {
    final c = st.chats[index];
    final urgent = c.kind == ChatKind.needsYou;
    final taken = st.takenOver.contains(index);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DCard(
        padding: const EdgeInsets.all(14),
        radius: 24,
        onTap: c.id == null ? null : () => _showConversation(context, st, c),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 50,
            height: 50,
            child: Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: _avatarColors[
                        c.name.hashCode.abs() % _avatarColors.length],
                    shape: BoxShape.circle),
                child: Text(c.name[0],
                    style: tStyle(19,
                        w: FontWeight.w800, color: Palette.greenDark)),
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: Icon(
                    urgent
                        ? Icons.priority_high_rounded
                        : Icons.auto_awesome_rounded,
                    size: 16,
                    color:
                        urgent ? const Color(0xFFB4452A) : Palette.greenDark),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tStyle(15.5, w: FontWeight.w800))),
                Text(c.time, style: tStyle(12, color: Colors.black38)),
              ]),
              const SizedBox(height: 2),
              Text(c.message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      tStyle(13.5, color: Colors.black54, w: FontWeight.w500)),
              const SizedBox(height: 8),
              if (urgent)
                Row(children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: taken
                              ? Palette.green.withOpacity(.3)
                              : const Color(0xFFFFE1D8),
                          borderRadius: BorderRadius.circular(10)),
                      child: Text(
                          taken ? 'Kamu yang balas' : 'Belum dijawab bot',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tStyle(12,
                              w: FontWeight.w700,
                              color: taken
                                  ? Palette.greenDark
                                  : const Color(0xFFB4452A))),
                    ),
                  ),
                  const Spacer(),
                  if (!taken)
                    FilledButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        st.setConversationTakeover(index, true);
                      },
                      style: FilledButton.styleFrom(
                          backgroundColor: Palette.ink,
                          minimumSize: const Size(0, 34),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: Text('Ambil alih',
                          style: tStyle(12.5,
                              w: FontWeight.w700, color: Colors.white)),
                    ),
                ])
              else if (c.reply != null)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                      color: Palette.bubbleOut,
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Mascot(size: 20, blue: false),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(c.reply ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: tStyle(12.5,
                                    w: FontWeight.w500, height: 1.3))),
                      ]),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class ChatsTab extends StatefulWidget {
  const ChatsTab({super.key, required this.st});
  final DashState st;
  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab> {
  int filter = 0;
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.st,
      builder: (context, _) {
        final st = widget.st;
        final view = st.consoleMode ? 1 : 0;
        final all = st.chats;
        final ids = [
          for (var i = 0; i < all.length; i++)
            if (filter == 0 ||
                (filter == 1 && all[i].kind == ChatKind.needsYou) ||
                (filter == 2 && all[i].kind == ChatKind.ai))
              i
        ];
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(view == 0 ? 'Percakapan' : 'Console bot',
                      style: tStyle(30, w: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    view == 0
                        ? '${st.needsYouCount} butuh kamu · ${all.where((chat) => chat.kind == ChatKind.ai).length} terjawab'
                        : 'Aktivitas runtime WhatsApp secara realtime',
                    style: sub(context).copyWith(fontSize: 14.5),
                  ),
                  const SizedBox(height: 14),
                  if (st.developerMockMode) ...[
                    const SizedBox(height: 12),
                    const SampleDataNotice(),
                  ] else if (st.dashboardError != null) ...[
                    const SizedBox(height: 12),
                    DashboardDataNotice(
                        text: st.dashboardError!, onRetry: st.refresh),
                  ] else if (!st.loggingEnabled) ...[
                    const SizedBox(height: 12),
                    const DashboardDataNotice(
                        text:
                            'Log percakapan nonaktif; isi pesan tidak ditampilkan di console.'),
                  ],
                  const SizedBox(height: 12),
                  if (view == 0)
                    SegToggle(
                      labels: const ['Semua', 'Perlu kamu', 'Dijawab AI'],
                      index: filter,
                      onChanged: (i) => setState(() => filter = i),
                      width: double.infinity,
                    ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: view == 0
                    ? _ChatList(
                        key: const ValueKey('chat-list'),
                        state: st,
                        ids: ids,
                      )
                    : _ConsolePanel(
                        key: const ValueKey('console-panel'),
                        state: st,
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ChatList extends StatelessWidget {
  const _ChatList({super.key, required this.state, required this.ids});
  final DashState state;
  final List<int> ids;

  @override
  Widget build(BuildContext context) => ids.isEmpty
      ? SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
          child: _Empty(
            loading: state.dashboardLoading,
            loggingEnabled: state.loggingEnabled,
            error: state.dashboardError,
            onRetry: state.refresh,
          ),
        )
      : ListView.builder(
          key: const PageStorageKey('chats'),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
          itemCount: ids.length,
          itemBuilder: (context, index) =>
              ChatTile(st: state, index: ids[index]),
        );
}

class _ConsolePanel extends StatelessWidget {
  const _ConsolePanel({super.key, required this.state});
  final DashState state;

  @override
  Widget build(BuildContext context) {
    final lines = state.consoleLines;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: ColoredBox(
          color: const Color(0xFF111A14),
          child: Column(
            children: [
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFF1B2820),
                  border: Border(bottom: BorderSide(color: Color(0xFF2B3B30))),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: state.activeWa.isConnected
                            ? const Color(0xFF69E26B)
                            : const Color(0xFFFFC857),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        state.developerMockMode
                            ? 'BLISS RUNTIME · MOCK'
                            : 'BLISS RUNTIME · ${state.activeWa.isConnected ? 'LIVE' : 'OFFLINE'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tStyle(11,
                            w: FontWeight.w800, color: const Color(0xFFD7E5D9)),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Hapus log di layar',
                      visualDensity: VisualDensity.compact,
                      onPressed: state.developerMockMode || lines.isEmpty
                          ? null
                          : state.clearConsole,
                      icon: const Icon(Icons.delete_sweep_outlined,
                          size: 20, color: Color(0xFF9FB0A2)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: lines.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.terminal_rounded,
                                  size: 34, color: Color(0xFF69E26B)),
                              const SizedBox(height: 12),
                              Text(
                                state.dashboardLoading
                                    ? 'Menghubungkan ke runtime…'
                                    : 'Menunggu aktivitas bot',
                                style: tStyle(15,
                                    w: FontWeight.w700,
                                    color: const Color(0xFFE4ECE5)),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Event status dan pesan baru akan muncul di sini.',
                                textAlign: TextAlign.center,
                                style: tStyle(12,
                                    color: const Color(0xFF9FB0A2),
                                    height: 1.4),
                              ),
                              if (!state.activeWa.isConnected) ...[
                                const SizedBox(height: 14),
                                TextButton.icon(
                                  onPressed: state.refresh,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Coba sambungkan ulang'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        itemCount: lines.length,
                        itemBuilder: (context, index) =>
                            _ConsoleLine(line: lines[lines.length - 1 - index]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsoleLine extends StatelessWidget {
  const _ConsoleLine({required this.line});
  final RuntimeConsoleLine line;

  @override
  Widget build(BuildContext context) {
    final color = switch (line.level) {
      'ERROR' || 'WARN' => const Color(0xFFFF8B78),
      'IN' => const Color(0xFF7CC8FF),
      'AI' => const Color(0xFF69E26B),
      'YOU' || 'CMD' => const Color(0xFFFFC857),
      'OK' => const Color(0xFF69E26B),
      _ => const Color(0xFF9FB0A2),
    };
    final time = line.timestamp;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}',
            style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: Color(0xFF748579)),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 38,
            child: Text('[${line.level}]',
                style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: SelectableText(
              line.message,
              style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  height: 1.45,
                  color: Color(0xFFD7E5D9)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(
      {this.loading = false,
      this.loggingEnabled = true,
      this.error,
      this.onRetry});
  final bool loading;
  final bool loggingEnabled;
  final String? error;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(children: [
          if (loading)
            const CircularProgressIndicator(color: Palette.greenDark)
          else
            const Mascot(size: 72, blue: false),
          const SizedBox(height: 16),
          Text(
              loading
                  ? 'Memuat percakapan'
                  : error != null
                      ? 'Data belum tersedia'
                      : loggingEnabled
                          ? 'Belum ada percakapan'
                          : 'Log dinonaktifkan',
              style: tStyle(20, w: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
              loading
                  ? 'Percakapan lokal sedang dimuat.'
                  : error ??
                      (loggingEnabled
                          ? 'Pesan masuk yang tercatat akan muncul di sini.'
                          : 'Aktifkan log di pengaturan privasi untuk menyimpan pesan baru.'),
              textAlign: TextAlign.center,
              style: sub(context).copyWith(fontSize: 14.5)),
          if (error != null && onRetry != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba lagi')),
          ],
        ]),
      );
}

void _showConversation(BuildContext context, DashState state, ChatItem chat) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _ConversationDetail(state: state, chat: chat),
  );
}

class _ConversationDetail extends StatefulWidget {
  const _ConversationDetail({required this.state, required this.chat});
  final DashState state;
  final ChatItem chat;

  @override
  State<_ConversationDetail> createState() => _ConversationDetailState();
}

class _ConversationDetailState extends State<_ConversationDetail> {
  final _replyController = TextEditingController();
  late Future<List<DashboardMessage>> _messages =
      widget.state.loadMessages(widget.chat.id!);
  bool _sending = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _replyController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.state.sendReply(widget.chat.id!, text);
      if (!mounted) return;
      _replyController.clear();
      setState(() {
        _sending = false;
        _messages = widget.state.loadMessages(widget.chat.id!);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error is StateError
            ? error.message.toString()
            : 'Pesan belum dapat dikirim. Coba lagi.'),
      ));
    }
  }

  Future<void> _toggleTakeover() async {
    final index = widget.state.chats.indexOf(widget.chat);
    if (index < 0) return;
    try {
      await widget.state.setConversationTakeover(
          index, !widget.state.takenOver.contains(index));
      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error is StateError
            ? error.message.toString()
            : 'Status percakapan belum dapat diubah.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = widget.state.chats.indexOf(widget.chat);
    final taken = index >= 0 && widget.state.takenOver.contains(index);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .82,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.chat.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tStyle(20, w: FontWeight.w800)),
                    Text('${widget.chat.messageCount} pesan · log lokal',
                        style: tStyle(12, color: Colors.black54)),
                  ]),
            ),
            TextButton(
              onPressed: _toggleTakeover,
              child: Text(taken ? 'Serahkan ke bot' : 'Ambil alih'),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded),
            ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<List<DashboardMessage>>(
            future: _messages,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Palette.greenDark));
              }
              if (snapshot.hasError) {
                return Center(
                    child: Text('Log pesan belum dapat dimuat.',
                        style: tStyle(14, color: Colors.black54)));
              }
              final messages = snapshot.data ?? const <DashboardMessage>[];
              if (messages.isEmpty) {
                return Center(
                    child: Text('Belum ada log untuk percakapan ini.',
                        style: tStyle(14, color: Colors.black54)));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(18),
                itemCount: messages.length,
                itemBuilder: (context, i) =>
                    _MessageBubble(message: messages[i]),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                16, 10, 12, MediaQuery.viewInsetsOf(context).bottom + 12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _replyController,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Balas sebagai operator',
                    filled: true,
                    fillColor: const Color(0xFFF1F5F0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final DashboardMessage message;

  @override
  Widget build(BuildContext context) {
    final outgoing = message.direction != 'incoming';
    final label = switch (message.direction) {
      'bot' => 'Bliss',
      'human' => 'Operator',
      'command' => 'Perintah',
      'handoff' => 'Tim Bliss',
      _ => 'Kontak',
    };
    final time = DateTime.fromMillisecondsSinceEpoch(message.timestamp);
    return Align(
      alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: outgoing ? Palette.bubbleOut : const Color(0xFFF0F2EF),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style:
                  tStyle(10.5, w: FontWeight.w800, color: Palette.greenDark)),
          const SizedBox(height: 3),
          Text(message.text, style: tStyle(14, w: FontWeight.w500)),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
                '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                style: tStyle(10, color: Colors.black45)),
          ),
        ]),
      ),
    );
  }
}
