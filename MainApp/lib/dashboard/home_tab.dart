import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../onboarding/common.dart';
import '../onboarding/models.dart';
import '../onboarding/screens_setup.dart';
import 'chats_tab.dart';
import 'dash_state.dart';
import 'dash_widgets.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.st, required this.goTab});
  final DashState st;
  final void Function(int) goTab;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) => ListView(
        key: const PageStorageKey('home'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          if (st.developerMockMode) ...[
            const SampleDataNotice(),
            const SizedBox(height: 12),
          ] else if (st.dashboardError != null) ...[
            DashboardDataNotice(text: st.dashboardError!, onRetry: st.refresh),
            const SizedBox(height: 12),
          ] else if (!st.loggingEnabled) ...[
            const DashboardDataNotice(
                text: 'Pencatatan log nonaktif; statistik tidak diperbarui.'),
            const SizedBox(height: 12),
          ],
          _Header(st: st, onBell: () => goTab(1)),
          const SizedBox(height: 14),
          _Hero(st: st),
          const SizedBox(height: 14),
          if (st.justHitMilestone) ...[
            _MilestoneBanner(st: st),
            const SizedBox(height: 14),
          ],
          _Insights(st: st, goTab: goTab),
          const SectionTitle('Aksi cepat'),
          _QuickActions(st: st, goTab: goTab),
          const SectionTitle('Ringkasan'),
          _Kpis(st: st, goTab: goTab),
          const SizedBox(height: 14),
          _ChartCard(st: st),
          const SectionTitle('Paling sering ditanyakan'),
          _Topics(st: st),
          SectionTitle('Percakapan terbaru',
              action: 'Lihat semua', onAction: () => goTab(1)),
          for (final entry in st.chats.take(3).indexed)
            ChatTile(st: st, index: entry.$1),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.st, required this.onBell});
  final DashState st;
  final VoidCallback onBell;

  @override
  Widget build(BuildContext context) => Row(children: [
        const Mascot(size: 48),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _showWaManagerSheet(context, st),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Flexible(
                    child: Text(st.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tStyle(20, w: FontWeight.w800))),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    size: 22, color: Palette.greenDark),
              ]),
              const SizedBox(height: 2),
              Row(children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                      color: st.activeWa.isConnected
                          ? Palette.greenDark
                          : Colors.orangeAccent,
                      shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text(st.activeWa.phone,
                    style: tStyle(12,
                        color: Palette.greenText, w: FontWeight.w600)),
              ]),
            ]),
          ),
        ),
        GestureDetector(
          onTap: onBell,
          child: Stack(clipBehavior: Clip.none, children: [
            Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.85),
                    shape: BoxShape.circle),
                child: const Icon(Icons.notifications_none_rounded,
                    color: Palette.ink)),
            if (st.needsYouCount > 0)
              Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                          color: const Color(0xFFEB5A3C),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2)))),
          ]),
        ),
      ]);
}

class _Hero extends StatelessWidget {
  const _Hero({required this.st});
  final DashState st;

  /// Warna Bliss Score — netral abu saat belum ada data, bukan merah.
  Color _scoreColor(int score, bool hasData) {
    if (!hasData) return Colors.white38;
    if (score >= 85) return Palette.green;
    if (score >= 65) return const Color(0xFFD4C84A);
    if (score >= 40) return Colors.deepOrangeAccent;
    return Colors.white70; // belum pernah merah saat baru setup
  }

  @override
  Widget build(BuildContext context) {
    final on = st.botOn;
    final reconnecting = st.runtimeStatus == 'reconnecting';
    final needsRelink = st.runtimeStatus == 'loggedOut';
    final runtimeFailed = st.runtimeStatus == 'error';
    final activeVisual = on || reconnecting;

    final score = st.blissScore;
    final hasData = st.developerMockMode || st.incomingMessages > 0;
    final pct = hasData ? (score / 100.0) : 0.0;
    final scoreColor = _scoreColor(score, hasData);

    // Teks kontekstual — tanpa emoji
    final String briefTitle = reconnecting
        ? 'Menyambungkan ulang...'
        : runtimeFailed || needsRelink
            ? 'Koneksi perlu dipulihkan'
            : st.dailyBriefTitle;
    final String briefSub = reconnecting
        ? 'Bliss sedang mencoba menyambungkan ulang secara otomatis.'
        : runtimeFailed
            ? 'Periksa internet dan baterai, lalu aktifkan kembali.'
            : needsRelink
                ? 'Sesi WhatsApp berakhir. Tautkan ulang untuk melanjutkan.'
                : st.dailyBriefSub;

    return ClipRRect(
      borderRadius: BorderRadius.circular(34),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: activeVisual
                  ? const [Color(0xFF14301F), Color(0xFF0C1710)]
                  : const [Color(0xFF30352F), Color(0xFF1B1F1C)]),
        ),
        child: Stack(children: [
          Positioned.fill(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 600),
              opacity: activeVisual ? 1 : 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.7, -0.7),
                    radius: 1.4,
                    colors: [
                      Palette.green.withOpacity(0.45),
                      Palette.green.withOpacity(0.15),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              // ── Baris atas: Ring Gauge + Teks ──
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                // Ring gauge menampilkan Bliss Score
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: pct),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => SizedBox(
                    width: 88,
                    height: 88,
                    child: CustomPaint(
                      painter: _ScoreRingPainter(v, scoreColor),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 500),
                              child: Text(
                                hasData ? '$score' : '--',
                                key: ValueKey(score),
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1),
                              ),
                            ),
                            Text('Bliss',
                                style: tStyle(9,
                                    color: Colors.white54,
                                    w: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status dot + label
                        Row(children: [
                          PulseDot(
                              color: on
                                  ? Palette.green
                                  : reconnecting
                                      ? Colors.amberAccent
                                      : Colors.orangeAccent,
                              active: activeVisual),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                                reconnecting
                                    ? 'Menyambungkan ulang'
                                    : runtimeFailed
                                        ? 'Perlu tindakan'
                                        : needsRelink
                                            ? 'Tautkan ulang'
                                            : on
                                                ? 'Online'
                                                : 'Dijeda',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tStyle(12,
                                    w: FontWeight.w700,
                                    color: activeVisual
                                        ? Palette.green
                                        : Colors.orangeAccent)),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        // Judul kontekstual (daily brief)
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            briefTitle,
                            key: ValueKey(briefTitle),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: tStyle(16,
                                w: FontWeight.w800,
                                color: Colors.white,
                                height: 1.25),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Sub-teks kontekstual
                        Text(
                            briefSub,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: tStyle(12,
                                color: Palette.mint,
                                w: FontWeight.w500,
                                height: 1.35)),
                        const SizedBox(height: 8),
                        // Bliss Score label kecil
                        Text(
                          hasData
                              ? st.blissScoreLabel
                              : 'Menunggu pesan pertama',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tStyle(11.5,
                              color: scoreColor, w: FontWeight.w700),
                        ),
                      ]),
                ),
              ]),
              const SizedBox(height: 14),
              // ── Progress bar tipis Bliss Score ──
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(children: [
                  Container(
                      height: 5,
                      color: Colors.white.withOpacity(.12)),
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: pct),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => FractionallySizedBox(
                      widthFactor: v,
                      child: Container(
                          height: 5,
                          decoration: BoxDecoration(
                            color: scoreColor,
                            borderRadius: BorderRadius.circular(6),
                          )),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              // ── Toggle on/off ──
              _BotSwitch(
                  on: on,
                  runtimeStatus: st.runtimeStatus,
                  busy: st.botTransitioning ||
                      st.dashboardLoading ||
                      st.runtimeStatus == 'reconnecting' ||
                      st.runtimeStatus == 'starting',
                  loading: st.dashboardLoading,
                  onChanged: st.toggleBot),
              if (st.botActionError != null) ...[
                const SizedBox(height: 8),
                Text(st.botActionError!,
                    textAlign: TextAlign.center,
                    style: tStyle(11.5,
                        w: FontWeight.w600, color: const Color(0xFFFFB5A8))),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

class _BotSwitch extends StatelessWidget {
  const _BotSwitch(
      {required this.on,
      required this.runtimeStatus,
      required this.busy,
      required this.loading,
      required this.onChanged});
  final bool on;
  final String runtimeStatus;
  final bool busy;
  final bool loading;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: busy
            ? null
            : () {
                HapticFeedback.mediumImpact();
                onChanged(!on);
              },
        child: Container(
          height: 60,
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(.08),
              borderRadius: BorderRadius.circular(30)),
          child: Stack(alignment: Alignment.center, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 70),
              child: Text(
                  busy
                      ? (loading
                          ? 'Memeriksa koneksi…'
                          : runtimeStatus == 'reconnecting'
                              ? 'Menyambungkan ulang…'
                              : (on ? 'Menjeda bot…' : 'Mengaktifkan bot…'))
                      : (on
                          ? 'Bot aktif · ketuk untuk jeda'
                          : 'Ketuk untuk aktifkan'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tStyle(13.5, color: Colors.white70)),
            ),
            AnimatedAlign(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutBack,
              alignment: on ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                      color: on ? Palette.green : Colors.white24,
                      shape: BoxShape.circle),
                  child: busy
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Palette.ink),
                        )
                      : Icon(Icons.power_settings_new_rounded,
                          color: on ? Palette.ink : Colors.white70),
                ),
              ),
            ),
          ]),
        ),
      );
}

class _Insights extends StatefulWidget {
  const _Insights({required this.st, required this.goTab});
  final DashState st;
  final void Function(int) goTab;
  @override
  State<_Insights> createState() => _InsightsState();
}

class _InsightsState extends State<_Insights> {
  final pc = PageController(viewportFraction: .94);
  int page = 0;
  @override
  void dispose() {
    pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.st;
    final b = st.busyStart;
    final items = st.developerMockMode
        ? [
            (
              Icons.forum_outlined,
              '${st.needsYouCount} pelanggan butuh kamu',
              'Bot tidak yakin menjawab. Balas sekarang sebelum mereka menunggu lama.',
              'Buka percakapan',
              1
            ),
            (
              Icons.psychology_outlined,
              'Ajari bot info baru',
              '5 pertanyaan minggu ini belum terjawab tuntas.',
              'Tambah Pengetahuan',
              2
            ),
            (
              Icons.schedule_rounded,
              'Paling ramai jam $b–${b + 2}',
              st.busyCovered
                  ? 'Jadwal aktif sudah mencakup jam ini.'
                  : 'Jam ini di luar jadwal aktif bot.',
              'Atur jadwal',
              2
            ),
          ]
        : [
            (
              Icons.forum_outlined,
              '${st.needsYouCount} percakapan perlu ditinjau',
              st.needsYouCount > 0
                  ? 'Percakapan ini belum memiliki balasan bot; buka untuk menindaklanjuti.'
                  : 'Tidak ada percakapan yang menunggu tindak lanjut.',
              'Buka percakapan',
              1
            ),
            (
              Icons.auto_awesome_outlined,
              '${st.botReplies} balasan bot tercatat',
              st.responseCount == 0
                  ? 'Balasan otomatis akan diringkas setelah log tersedia.'
                  : 'Rata-rata waktu respons ${(st.averageResponseMs / 1000).round()} detik berdasarkan log lokal.',
              'Lihat ringkasan',
              0
            ),
            (
              Icons.schedule_rounded,
              st.incomingMessages == 0
                  ? 'Pola pesan belum tersedia'
                  : 'Paling ramai jam $b–${b + 2}',
              st.incomingMessages == 0
                  ? 'Grafik waktu aktif terbentuk setelah pesan tercatat.'
                  : '${st.hourly[b]} pesan masuk pada jam tersibuk; ${st.busyCovered ? 'jadwal bot mencakup waktunya.' : 'jadwal bot belum mencakup seluruh rentang.'}',
              'Lihat statistik',
              0
            ),
          ];
    return Column(children: [
      SizedBox(
        height: 168,
        child: PageView.builder(
          controller: pc,
          itemCount: items.length,
          onPageChanged: (i) => setState(() => page = i),
          itemBuilder: (_, i) {
            final it = items[i];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: DCard(
                radius: 28,
                color: i == 0
                    ? const Color(0xFFFFF1D6)
                    : Colors.white.withOpacity(.85),
                child: Row(children: [
                  Icon(it.$1, size: 34, color: Palette.greenDark),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(it.$2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tStyle(16, w: FontWeight.w800)),
                          const SizedBox(height: 3),
                          Text(it.$3,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: tStyle(12.5,
                                  color: Colors.black54,
                                  w: FontWeight.w500,
                                  height: 1.3)),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => widget.goTab(it.$5),
                            child: Text('${it.$4}  ›',
                                style: tStyle(13.5,
                                    color: Palette.greenDark,
                                    w: FontWeight.w800)),
                          ),
                        ]),
                  ),
                ]),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < items.length; i++)
          AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: page == i ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                  color: page == i ? Palette.green : Palette.greenSoft,
                  borderRadius: BorderRadius.circular(6))),
      ]),
    ]);
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.st, required this.goTab});
  final DashState st;
  final void Function(int) goTab;
  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String label, Color bg, VoidCallback onTap) =>
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: SizedBox(
            width: 78,
            child: Column(children: [
              Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                      color: bg, borderRadius: BorderRadius.circular(22)),
                  child: Icon(icon, color: Palette.ink, size: 28)),
              const SizedBox(height: 8),
              Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tStyle(12, w: FontWeight.w700, height: 1.2)),
            ]),
          ),
        );
    return SizedBox(
      height: 100,
      child: ListView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          children: [
            item(
                Icons.chat_bubble_outline_rounded,
                'Uji bot',
                Palette.green.withOpacity(.55),
                () => showTestSheet(context, st)),
            const SizedBox(width: 12),
            item(Icons.pause_circle_outline_rounded, 'Jeda 1 jam',
                const Color(0xFFFFE9A8), () {
              if (!st.botOn) return;
              unawaited(st.pauseOneHour());
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(
                    content: const Text('Bot dijeda 1 jam'),
                    action: SnackBarAction(
                        label: 'Batalkan',
                        onPressed: () => st.toggleBot(true))));
            }),
            const SizedBox(width: 12),
            item(Icons.school_outlined, 'Ajari bot', const Color(0xFFCDEBFF),
                () => goTab(2)),
            const SizedBox(width: 12),
            item(Icons.palette_outlined, 'Ganti gaya', const Color(0xFFFFD3C7),
                () => goTab(2)),
            const SizedBox(width: 12),
            item(Icons.forum_outlined, 'Percakapan', const Color(0xFFE3D4FF),
                () => goTab(1)),
          ]),
    );
  }
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.st, required this.goTab});
  final DashState st;
  final void Function(int) goTab;
  @override
  Widget build(BuildContext context) {
    final items = st.kpis;
    final colors = [
      Palette.green,
      const Color(0xFFFFC857),
      const Color(0xFF6EC6FF)
    ];
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) const SizedBox(width: 10),
        Expanded(
          child: _Kpi(
            icon: items[i].$1,
            tint: colors[i],
            label: items[i].$2,
            value: items[i].$3,
            delta: items[i].$4,
            data: items[i].$5,
            format:
                (items[i].$2 == 'Waktu hemat' || items[i].$2.contains('Waktu'))
                    ? fmtMinutes
                    : null,
            onTap: () => goTab(i == 1 ? 1 : (i == 2 ? 1 : 0)),
          ),
        ),
      ],
    ]);
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(
      {required this.icon,
      required this.tint,
      required this.label,
      required this.value,
      required this.delta,
      required this.data,
      this.format,
      this.onTap});
  final IconData icon;
  final Color tint;
  final String label;
  final double value;
  final int? delta;
  final List<double> data;
  final String Function(double)? format;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => DCard(
        padding: const EdgeInsets.all(14),
        radius: 24,
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                    color: tint.withOpacity(.3), shape: BoxShape.circle),
                child: Icon(icon, size: 16, color: Palette.ink)),
            const Spacer(),
            if (delta != null)
              Flexible(
                child: FittedBox(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                        color: Palette.green.withOpacity(.25),
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.arrow_upward_rounded,
                          size: 11, color: Palette.greenDark),
                      Text('$delta%',
                          style: tStyle(11,
                              w: FontWeight.w800, color: Palette.greenDark))
                    ]),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 12),
          FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: CountUp(
                  value: value,
                  format: format,
                  style: tStyle(25, w: FontWeight.w800))),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tStyle(12, color: Colors.black54, w: FontWeight.w600)),
          const SizedBox(height: 10),
          SizedBox(
              height: 30,
              width: double.infinity,
              child: Sparkline(
                  data: data,
                  color: tint == Palette.green ? Palette.greenDark : tint)),
        ]),
      );
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.st});
  final DashState st;
  @override
  Widget build(BuildContext context) {
    final week = st.range == 1;
    final s = st.series;
    final String insight;
    if (week) {
      final peak = DashState.dayNames[st.peakIndex];
      final quiet = DashState.dayNames[st.quietIndex];
      final peakCount = s[st.peakIndex];
      insight = st.developerMockMode
          ? '$peak adalah hari tersibuk ($peakCount chat). Pastikan jadwal bot aktif mencakup hari $peak.'
          : '$peak tersibuk ($peakCount chat) — $quiet paling sepi. Pertimbangkan konten atau promo untuk hari $quiet.';
    } else {
      final b = st.busyStart;
      final covered = st.busyCovered;
      insight = st.developerMockMode
          ? 'Jam $b.00–${b + 2}.00 paling ramai. Bot aktif & menjawab 92% pesan di jam tersibuk — performa optimal!'
          : covered
              ? 'Jam $b.00–${b + 2}.00 paling ramai. Jadwal bot sudah mencakup jam ini — bagus!'
              : 'Jam $b.00–${b + 2}.00 paling ramai tapi belum masuk jadwal bot. Perbarui jadwal di Studio.';
    }
    return DCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Text('Kapan chat masuk?',
                  style: tStyle(17, w: FontWeight.w800))),
          SegToggle(
              labels: const ['Hari ini', '7 hari'],
              index: st.range,
              onChanged: st.setRange,
              width: 140),
        ]),
        const SizedBox(height: 14),
        ActivityChart(
          values: s,
          labels: st.labels,
          peak: st.peakIndex,
          tooltip: (i) => week
              ? '${s[i]} chat'
              : '${i.toString().padLeft(2, '0')}.00 · ${s[i]} chat',
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Palette.green.withOpacity(.2),
              borderRadius: BorderRadius.circular(16)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.lightbulb_outline_rounded,
                size: 24, color: Palette.greenDark),
            const SizedBox(width: 10),
            Expanded(
                child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(insight,
                        key: ValueKey(insight),
                        style: tStyle(13,
                            w: FontWeight.w600,
                            height: 1.35,
                            color: Palette.greenDark)))),
          ]),
        ),
      ]),
    );
  }
}

class _Topics extends StatelessWidget {
  const _Topics({required this.st});
  final DashState st;
  static const mockData = [
    (Icons.access_time_rounded, 'Jam buka', 64),
    (Icons.payments_outlined, 'Harga', 52),
    (Icons.local_shipping_outlined, 'Ongkir', 41),
    (Icons.inventory_2_outlined, 'Stok', 27),
    (Icons.card_giftcard_rounded, 'Promo', 19)
  ];
  static const colors = [
    Color(0xFFBFEFC0),
    Color(0xFFFFE9A8),
    Color(0xFFCDEBFF),
    Color(0xFFFFD3C7),
    Color(0xFFE3D4FF)
  ];
  @override
  Widget build(BuildContext context) {
    final data = st.developerMockMode
        ? mockData
        : st.topics
            .map((topic) => (
                  topic.label.toLowerCase().contains('harga') ||
                          topic.label.toLowerCase().contains('biaya')
                      ? Icons.payments_outlined
                      : topic.label.toLowerCase().contains('kirim') ||
                              topic.label.toLowerCase().contains('ongkir')
                          ? Icons.local_shipping_outlined
                          : topic.label.toLowerCase().contains('stok') ||
                                  topic.label.toLowerCase().contains('produk')
                              ? Icons.inventory_2_outlined
                              : topic.label.toLowerCase().contains('jam') ||
                                      topic.label.toLowerCase().contains('buka')
                                  ? Icons.access_time_rounded
                                  : Icons.chat_bubble_outline_rounded,
                  topic.label,
                  topic.count,
                ))
            .toList(growable: false);
    if (data.isEmpty) {
      return DCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Text(
              'Topik sering ditanyakan muncul setelah pesan tercatat.',
              textAlign: TextAlign.center,
              style: tStyle(13, color: Colors.black54, w: FontWeight.w500),
            ),
          ),
        ),
      );
    }
    return DCard(
      child: Column(children: [
        Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 14,
            runSpacing: 14,
            children: [
              for (var i = 0; i < data.length; i++)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 500 + i * 120),
                  curve: Curves.elasticOut,
                  builder: (_, v, child) =>
                      Transform.scale(scale: v.clamp(0.0, 1.2), child: child),
                  child: _bubble(i, data),
                ),
            ]),
        const SizedBox(height: 14),
        Text(
            st.developerMockMode
                ? 'Contoh topik untuk pratinjau mode developer.'
                : 'Topik dihitung lokal dari kata pada pesan masuk.',
            textAlign: TextAlign.center,
            style: tStyle(12.5,
                color: Colors.black54, w: FontWeight.w500, height: 1.35)),
      ]),
    );
  }

  Widget _bubble(int i, List<(IconData, String, int)> data) {
    final d = data[i];
    final maxCount =
        data.map((item) => item.$3).fold<int>(1, (a, b) => a > b ? a : b);
    final size = 56 + 44 * d.$3 / maxCount;
    return SizedBox(
      width: size + 8,
      child: Column(children: [
        Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: colors[i], shape: BoxShape.circle),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(d.$1, size: size * .32, color: Palette.ink),
              Text('${d.$3}', style: tStyle(size * .2, w: FontWeight.w800))
            ])),
        const SizedBox(height: 6),
        Text(d.$2,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tStyle(12, w: FontWeight.w700)),
      ]),
    );
  }
}




class _ScoreRingPainter extends CustomPainter {
  _ScoreRingPainter(this.pct, this.color);
  final double pct;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    final rect = Rect.fromCircle(center: center, radius: radius);
    // Track
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = Colors.black.withOpacity(.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9);
    // Arc
    if (pct > 0) {
      canvas.drawArc(
          rect,
          -math.pi / 2,
          2 * math.pi * pct,
          false,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 9
            ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_ScoreRingPainter o) => o.pct != pct || o.color != color;
}

// ── Milestone Banner ──
class _MilestoneBanner extends StatelessWidget {
  const _MilestoneBanner({required this.st});
  final DashState st;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B6B3A), Color(0xFF2A9D5C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Palette.greenDark.withOpacity(.3),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(.15),
                shape: BoxShape.circle),
            child: const Icon(Icons.emoji_events_rounded,
                color: Colors.amber, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Milestone tercapai!',
                    style:
                        tStyle(14, color: Colors.white, w: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                    'Bot kamu baru saja menjawab pesan ke-${st.botReplies}! Terus tingkatkan pengetahuan bot.',
                    style: tStyle(12.5,
                        color: Colors.white.withOpacity(.85),
                        w: FontWeight.w500,
                        height: 1.35)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.share_rounded, color: Colors.white70, size: 20),
        ],
      ),
    );
  }
}

// ── Multi WA Sheets ──
void _showWaManagerSheet(BuildContext context, DashState st) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => ListenableBuilder(
      listenable: st,
      builder: (ctx, _) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('Kelola WhatsApp', style: tStyle(22, w: FontWeight.w800)),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx)),
              ]),
              Text('Pilih nomor aktif atau tambah nomor baru',
                  style: sub(ctx).copyWith(fontSize: 14)),
              const SizedBox(height: 16),
              for (var i = 0; i < st.waAccounts.length; i++) ...[
                GestureDetector(
                  onTap: () {
                    st.switchWaAccount(i);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: st.activeWaIndex == i
                          ? Palette.green.withOpacity(.2)
                          : Palette.bgTop,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: st.activeWaIndex == i
                              ? Palette.green
                              : Colors.transparent,
                          width: 2),
                    ),
                    child: Row(children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                            color: st.waAccounts[i].isConnected
                                ? Palette.green.withOpacity(.3)
                                : Colors.orange.withOpacity(.2),
                            shape: BoxShape.circle),
                        child: Icon(
                            st.waAccounts[i].isConnected
                                ? Icons.phone_android_rounded
                                : Icons
                                    .signal_cellular_connected_no_internet_0_bar_rounded,
                            size: 20,
                            color: st.waAccounts[i].isConnected
                                ? Palette.greenDark
                                : Colors.deepOrange),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Flexible(
                                    child: Text(st.waAccounts[i].name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: tStyle(15, w: FontWeight.w800))),
                                if (st.activeWaIndex == i) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: Palette.greenDark,
                                          borderRadius:
                                              BorderRadius.circular(6)),
                                      child: Text('AKTIF',
                                          style: tStyle(10,
                                              color: Colors.white,
                                              w: FontWeight.w800))),
                                ],
                              ]),
                              const SizedBox(height: 2),
                              Text(st.waAccounts[i].phone,
                                  style: tStyle(13, color: Colors.black54)),
                            ]),
                      ),
                      if (!st.waAccounts[i].isConnected)
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showPairingModal(context, st, st.waAccounts[i]);
                          },
                          child: Text('Hubungkan',
                              style: tStyle(13,
                                  color: Palette.greenDark,
                                  w: FontWeight.w800)),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Palette.green.withOpacity(.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.check_circle_rounded,
                                size: 13, color: Palette.greenDark),
                            const SizedBox(width: 4),
                            Text('Tertaut',
                                style: tStyle(11.5,
                                    color: Palette.greenDark,
                                    w: FontWeight.w700)),
                          ]),
                        ),
                      if (st.waAccounts.length > 1)
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 20, color: Colors.black38),
                          onPressed: () => st.removeWaAccount(i),
                        ),
                    ]),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _showAddNumberDialog(context, st),
                icon: const Icon(Icons.add_rounded, color: Palette.ink),
                label: Text('Tambah Nomor WhatsApp',
                    style: tStyle(14, w: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  side: const BorderSide(color: Palette.ink, width: 1.5),
                ),
              ),
            ]),
      ),
    ),
  );
}

void _showAddNumberDialog(BuildContext context, DashState st) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => _AddNumberSheet(st: st),
  );
}

class _AddNumberSheet extends StatefulWidget {
  const _AddNumberSheet({required this.st});
  final DashState st;

  @override
  State<_AddNumberSheet> createState() => _AddNumberSheetState();
}

class _AddNumberSheetState extends State<_AddNumberSheet> {
  ConnectMethod? method;

  @override
  Widget build(BuildContext context) {
    if (method == null) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
            24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('Tambah Nomor WA', style: tStyle(22, w: FontWeight.w800)),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context)),
            ]),
            Text('Pilih cara penghubungan nomor WhatsApp baru',
                style: sub(context).copyWith(fontSize: 14)),
            const SizedBox(height: 20),
            _OptionTile(
              icon: Icons.qr_code_2_rounded,
              title: 'Scan QR Code',
              desc: 'Pindai kode QR dari WhatsApp di HP lain',
              onTap: () => setState(() => method = ConnectMethod.qr),
            ),
            const SizedBox(height: 10),
            _OptionTile(
              icon: Icons.pin_rounded,
              title: 'Kode Pairing (8 Digit)',
              desc: 'Masukkan nomor HP & terima kode 8 digit',
              onTap: () => setState(() => method = ConnectMethod.pairCode),
            ),
          ],
        ),
      );
    }

    final answers = Answers()..method = method;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    return Container(
      height: MediaQuery.of(context).size.height * .78,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: PairingScreen(
        answers: answers,
        connector: widget.st.connector,
        onNext: () {
          final phone = widget.st.connector.botNumber.isNotEmpty
              ? '+${widget.st.connector.botNumber}'
              : '+62 WA Baru';
          widget.st.addWaAccount(phone, 'Nomor WA Baru');
          final newIdx = widget.st.waAccounts.length - 1;
          widget.st.toggleWaConnection(newIdx, true);
          widget.st.switchWaAccount(newIdx);
          navigator.pop();
          messenger.showSnackBar(SnackBar(
            content: Text('$phone berhasil terhubung & dijadikan nomor utama!'),
          ));
        },
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile(
      {required this.icon,
      required this.title,
      required this.desc,
      required this.onTap});
  final IconData icon;
  final String title, desc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Palette.bgTop,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Palette.green.withOpacity(.3)),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Palette.green.withOpacity(.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: Palette.greenDark),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: tStyle(15, w: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(desc, style: tStyle(12.5, color: Colors.black54)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Palette.greenDark),
        ]),
      ),
    );
  }
}

void _showPairingModal(BuildContext context, DashState st, WaAccount account) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
    builder: (ctx) => Container(
      height: MediaQuery.of(ctx).size.height * .78,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: PairingScreen(
        answers: Answers()..method = ConnectMethod.qr,
        connector: st.connector,
        onNext: () {
          final idx = st.waAccounts.indexOf(account);
          if (idx != -1) {
            st.toggleWaConnection(idx, true);
            st.switchWaAccount(idx);
          }
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('${account.name} (${account.phone}) berhasil terhubung!'),
          ));
        },
      ),
    ),
  );
}
