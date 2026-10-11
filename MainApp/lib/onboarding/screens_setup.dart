import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PathMetric;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import 'common.dart';
import '../legal/legal_documents.dart';
import 'models.dart';

/// Kerangka layar izin: ilustrasi + pesan + CTA + opsi lewati.
class _PermScaffold extends StatelessWidget {
  const _PermScaffold({
    required this.illustration,
    required this.title,
    required this.message,
    required this.cta,
    required this.onCta,
    this.skipLabel,
    this.onSkip,
  });
  final Widget illustration;
  final String title, message, cta;
  final VoidCallback onCta;
  final String? skipLabel;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxHeight < 620;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
            child: Column(children: [
              SizedBox(height: compact ? 16 : 36),
              SizedBox(
                  height: compact ? 150 : 230,
                  child: Center(
                      child: FittedBox(
                          fit: BoxFit.scaleDown, child: illustration))),
              SizedBox(height: compact ? 20 : 28),
              Text(title,
                  textAlign: TextAlign.center,
                  style: h1(context).copyWith(fontSize: 28)),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(message,
                    textAlign: TextAlign.center,
                    style: sub(context, color: Palette.greenDark)
                        .copyWith(fontSize: 16)),
              ],
              const SizedBox(height: 28),
              PrimaryButton(label: cta, onTap: onCta),
              SizedBox(
                height: 48,
                child: skipLabel == null
                    ? null
                    : GhostButton(label: skipLabel!, onTap: onSkip!),
              ),
            ]),
          ),
        );
      });
}

/// 1) Sebelum pilih metode hubungkan.
class ConnectChoice extends StatelessWidget {
  const ConnectChoice({super.key, required this.answers, required this.onNext});
  final Answers answers;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    Future<void> choose(ConnectMethod method) async {
      final accepted = await requestLegalConsent(context);
      if (!accepted || !context.mounted) return;
      HapticFeedback.selectionClick();
      answers.method = method;
      onNext();
    }

    Widget card(ConnectMethod m, IconData icon, String t, String d) =>
        GestureDetector(
          onTap: () => choose(m),
          child: Container(
            padding: const EdgeInsets.all(18),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(.75),
                borderRadius: BorderRadius.circular(22)),
            child: Row(children: [
              Icon(icon, size: 52, color: Palette.greenDark),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 17, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(d,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5, color: Colors.black54)),
                    ]),
              ),
              const Icon(Icons.chevron_right_rounded),
            ]),
          ),
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Mascot(size: 52),
        const SizedBox(height: 20),
        Text('Kita akan hubungkan ke WhatsApp-mu sekarang',
            style: h1(context).copyWith(fontSize: 28)),
        const SizedBox(height: 10),
        Text(
            'Pilih cara yang paling nyaman. Keduanya aman dan bisa diputus kapan saja.',
            style: sub(context).copyWith(fontSize: 15)),
        const SizedBox(height: 28),
        card(ConnectMethod.qr, Icons.qr_code_2_rounded, 'Scan QR Code',
            'Scan dari WhatsApp di HP lain'),
        card(ConnectMethod.pairCode, Icons.pin_rounded, 'Kode Pairing',
            'Masukkan kode 8 karakter di HP ini'),
      ]),
    );
  }
}

/// 2) Izin "Display over other apps" — setelah memilih metode.
class OverlayPermission extends StatefulWidget {
  const OverlayPermission({super.key, required this.onNext});
  final VoidCallback onNext;
  @override
  State<OverlayPermission> createState() => _OverlayPermissionState();
}

class _OverlayPermissionState extends State<OverlayPermission>
    with WidgetsBindingObserver {
  bool asked = false;
  bool requesting = false;
  bool advanced = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Layar pengaturan overlay membuka halaman sistem; cek ulang saat kembali.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed &&
        asked &&
        await Permission.systemAlertWindow.isGranted) {
      _advanceOnce();
    }
  }

  void _advanceOnce() {
    if (!mounted || advanced) return;
    advanced = true;
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) => _PermScaffold(
        illustration: const _OverlayIllustration(),
        title: 'Biar bot tetap jalan',
        message:
            'Bliss butuh izin tampil di atas aplikasi lain agar bot tetap aktif saat kamu membuka WhatsApp atau app lainnya.',
        cta: 'Izinkan',
        onCta: () async {
          if (requesting || advanced) return;
          requesting = true;
          asked = true;
          try {
            final status = await Permission.systemAlertWindow.request();
            if (status.isGranted) _advanceOnce();
          } finally {
            requesting = false;
          }
        },
        skipLabel: 'Nanti saja',
        onSkip: _advanceOnce,
      );
}

/// Ilustrasi kecil kenapa: bubble bot melayang di atas aplikasi lain.
class _OverlayIllustration extends StatelessWidget {
  const _OverlayIllustration();
  @override
  Widget build(BuildContext context) => _DeviceFrame(
        child: Stack(children: [
          const _AppRows(),
          Positioned(
            right: 10,
            bottom: 18,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutBack,
              builder: (_, value, child) =>
                  Transform.scale(scale: value, child: child),
              child: Container(
                  width: 52,
                  height: 52,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                      color: Palette.ink,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(.2),
                            blurRadius: 12,
                            offset: const Offset(0, 5))
                      ]),
                  child: const Mascot(size: 42)),
            ),
          ),
          Positioned(
              right: 56,
              bottom: 28,
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.reply_rounded,
                      color: Palette.greenDark, size: 17))),
        ]),
      );
}

class _DeviceFrame extends StatelessWidget {
  const _DeviceFrame({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
      width: 184,
      height: 300,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: Palette.ink,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
                color: Palette.greenDark.withOpacity(.22),
                blurRadius: 20,
                offset: const Offset(0, 9))
          ]),
      child: ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: ColoredBox(color: const Color(0xFFF5F7F4), child: child)));
}

class _AppRows extends StatelessWidget {
  const _AppRows();
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 38, 16, 0),
      child: Column(children: [
        for (var i = 0; i < 4; i++)
          Align(
              alignment: Alignment.centerLeft,
              child: Container(
                  margin: const EdgeInsets.only(bottom: 13),
                  width: i.isEven ? 120 : 145,
                  height: 11,
                  decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(8))))
      ]));
}

class _NotificationIllustration extends StatelessWidget {
  const _NotificationIllustration();
  @override
  Widget build(BuildContext context) => _DeviceFrame(
        child: Stack(children: [
          const _AppRows(),
          Positioned(
            top: 18,
            left: 10,
            right: 10,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: -18, end: 0),
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeOutCubic,
              builder: (_, y, child) =>
                  Transform.translate(offset: Offset(0, y), child: child),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(.13),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ]),
                child: Row(children: [
                  const Mascot(size: 32),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Bliss',
                            style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800, fontSize: 11)),
                        Text('Bot terputus. Ketuk untuk cek.',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 10, color: Colors.black54)),
                      ])),
                  const Icon(Icons.notifications_rounded,
                      size: 18, color: Palette.greenDark),
                ]),
              ),
            ),
          ),
        ]),
      );
}

class _BatteryIllustration extends StatelessWidget {
  const _BatteryIllustration();
  @override
  Widget build(BuildContext context) => _DeviceFrame(
          child: Stack(children: [
        Positioned(
            top: 22,
            left: 0,
            right: 0,
            child: Icon(Icons.lock_rounded,
                color: Palette.ink.withOpacity(.55), size: 24)),
        Positioned(
            top: 56,
            left: 18,
            right: 18,
            child: Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15)),
                child: Row(children: [
                  const Mascot(size: 30),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text('Siap, aku ingatkan jam 5 sore.',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.5, fontWeight: FontWeight.w600)))
                ]))),
        Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Icon(Icons.battery_full_rounded,
                color: Palette.greenDark, size: 34)),
      ]));
}

/// 3) Proses pairing (QR / kode) sampai tersambung.
class PairingScreen extends StatefulWidget {
  const PairingScreen(
      {super.key,
      required this.answers,
      required this.connector,
      required this.onNext});
  final Answers answers;
  final WhatsAppConnector connector;
  final VoidCallback onNext;
  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  String? payload;
  bool connected = false;
  bool starting = false;
  String? error;
  late final TextEditingController _phoneController;
  StreamSubscription<String>? _pairingSubscription;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
    _pairingSubscription = widget.connector.pairingUpdates.listen((value) {
      if (mounted) setState(() => payload = value);
    });
    if (widget.answers.method != ConnectMethod.pairCode) _run();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _pairingSubscription?.cancel();
    super.dispose();
  }

  void _onConnected() {
    if (connected || !mounted) return;
    setState(() => connected = true);
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) widget.onNext();
    });
  }

  Future<void> _run() async {
    if (widget.answers.method == ConnectMethod.pairCode &&
        !RegExp(r'^\d{8,15}$').hasMatch(_phoneController.text.trim())) {
      setState(() =>
          error = 'Masukkan nomor internasional 8–15 digit tanpa tanda +.');
      return;
    }
    setState(() {
      payload = null;
      error = null;
      starting = true;
    });
    try {
      final p = await widget.connector.start(
          widget.answers.method ?? ConnectMethod.qr,
          phoneNumber: _phoneController.text.trim(),
          profile: widget.answers.toBotProfile());
      if (!mounted) return;
      // A refreshed QR can arrive over pairingUpdates before start() returns.
      // Keep that fresher payload instead of overwriting it with the initial one.
      if (payload == null) setState(() => payload = p);
      await widget.connector.waitUntilConnected();
      _onConnected();
    } catch (e) {
      if (mounted)
        setState(() =>
            error = 'Gagal terhubung. Pastikan internet aktif lalu coba lagi.');
    } finally {
      if (mounted) setState(() => starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCode = widget.answers.method == ConnectMethod.pairCode;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 24),
      child: Column(children: [
        Text(
            isCode
                ? (payload == null
                    ? 'Masukkan nomor WhatsApp'
                    : 'Masukkan kode ini di WhatsApp')
                : 'Scan QR ini dari WhatsApp',
            textAlign: TextAlign.center,
            style: h1(context).copyWith(fontSize: 26)),
        const SizedBox(height: 10),
        Text(
            isCode
                ? (payload == null
                    ? 'Masukkan nomor dengan kode negara tanpa tanda + untuk meminta kode resmi WhatsApp.'
                    : 'WhatsApp › Perangkat tertaut › Tautkan perangkat › Tautkan dengan nomor telepon.')
                : 'WhatsApp › Perangkat tertaut › Tautkan perangkat, lalu arahkan kamera ke kode ini.',
            textAlign: TextAlign.center,
            style: sub(context).copyWith(fontSize: 14.5)),
        Expanded(
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: connected
                  ? const Icon(Icons.check_circle_rounded,
                      key: ValueKey('ok'), size: 120, color: Palette.green)
                  : error != null
                      ? Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(error!,
                              textAlign: TextAlign.center,
                              style: sub(context, color: Colors.red.shade700)),
                          const SizedBox(height: 16),
                          OutlinedButton(
                              onPressed: _run, child: const Text('Coba lagi')),
                        ])
                      : payload == null
                          ? isCode
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextField(
                                        controller: _phoneController,
                                        keyboardType: TextInputType.phone,
                                        textInputAction: TextInputAction.done,
                                        onSubmitted: (_) => _run(),
                                        maxLength: 15,
                                        decoration: const InputDecoration(
                                          labelText: 'Nomor WhatsApp',
                                          hintText: '628123456789',
                                          prefixText: '+',
                                          counterText: '',
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      FilledButton(
                                        onPressed: starting ? null : _run,
                                        child: Text(starting
                                            ? 'Menyiapkan kode…'
                                            : 'Buat kode pairing'),
                                      ),
                                    ],
                                  ),
                                )
                              : const CircularProgressIndicator(
                                  color: Palette.green)
                          : isCode
                              ? _CodeBox(code: payload!)
                              : _QrBox(data: payload!),
            ),
          ),
        ),
        if (!connected && error == null && (!isCode || payload != null)) ...[
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Palette.greenDark)),
            const SizedBox(width: 10),
            Flexible(
                child: Text('Menunggu tersambung dengan WhatsApp…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                        color: Palette.greenDark,
                        fontWeight: FontWeight.w600))),
          ]),
        ],
      ]),
    );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({required this.code});
  final String code;
  @override
  Widget build(BuildContext context) => GestureDetector(
        key: const ValueKey('code'),
        onTap: () {
          Clipboard.setData(ClipboardData(text: code));
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Kode disalin')));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(code,
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4)),
            const SizedBox(height: 8),
            Text('Ketuk untuk menyalin',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5, color: Colors.black45)),
          ]),
        ),
      );
}

/// Placeholder QR. Ganti dengan paket `qr_flutter` memakai [data] dari connector.
class _QrBox extends StatelessWidget {
  const _QrBox({required this.data});
  final String data;
  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('qr'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: SizedBox(
        width: 220,
        height: 220,
        child: CustomPaint(painter: _QrPlaceholderPainter(data.hashCode)),
      ),
    );
  }
}

class _QrPlaceholderPainter extends CustomPainter {
  _QrPlaceholderPainter(this.seed) {
    final random = math.Random(seed);
    for (var y = 0; y < 21; y++) {
      for (var x = 0; x < 21; x++) {
        if (_insideFinder(x, y)) continue;
        if (random.nextBool()) _modules.add(Offset(x.toDouble(), y.toDouble()));
      }
    }
  }

  final int seed;
  final List<Offset> _modules = [];
  final Paint _dark = Paint()..color = Palette.ink;
  final Paint _light = Paint()..color = Colors.white;

  bool _insideFinder(int x, int y) =>
      (x < 7 && y < 7) || (x >= 14 && y < 7) || (x < 7 && y >= 14);

  void _drawFinder(Canvas canvas, double unit, int left, int top) {
    final outer = Rect.fromLTWH(left * unit, top * unit, 7 * unit, 7 * unit);
    final middle =
        Rect.fromLTWH((left + 1) * unit, (top + 1) * unit, 5 * unit, 5 * unit);
    final inner =
        Rect.fromLTWH((left + 2) * unit, (top + 2) * unit, 3 * unit, 3 * unit);
    canvas.drawRect(outer, _dark);
    canvas.drawRect(middle, _light);
    canvas.drawRect(inner, _dark);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 21;
    final modules = Path();
    for (final cell in _modules) {
      modules
          .addRect(Rect.fromLTWH(cell.dx * unit, cell.dy * unit, unit, unit));
    }
    canvas.drawPath(modules, _dark);
    _drawFinder(canvas, unit, 0, 0);
    _drawFinder(canvas, unit, 14, 0);
    _drawFinder(canvas, unit, 0, 14);
  }

  @override
  bool shouldRepaint(_QrPlaceholderPainter oldDelegate) =>
      oldDelegate.seed != seed;
}

/// 4) Setelah bot terhubung — pengecualian optimasi baterai.
class BatteryPermission extends StatelessWidget {
  const BatteryPermission({super.key, required this.onNext});
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) => _PermScaffold(
        illustration: const _BatteryIllustration(),
        title: 'Jaga bot tetap menyala',
        message:
            'Tanpa pengecualian ini, Android bisa mematikan bot saat layar mati. Aktifkan agar bot tidak pernah berhenti di tengah malam.',
        cta: 'Izinkan',
        onCta: () async {
          await Permission.ignoreBatteryOptimizations.request();
          onNext();
        },
        skipLabel: 'Nanti saja',
        onSkip: onNext,
      );
}

/// 5) Notifikasi persisten. Pindahkan pemanggilan ke momen pertama user membuka log/status bila mau.
class NotificationPermission extends StatelessWidget {
  const NotificationPermission({super.key, required this.onNext});
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) => _PermScaffold(
        illustration: const _NotificationIllustration(),
        title: 'Mau kami kabari?',
        message:
            'Kami kirim notifikasi hanya saat bot terputus dari WhatsApp — bukan iklan, bukan spam.',
        cta: 'Ya, kabari aku',
        onCta: () async {
          await Permission.notification.request();
          onNext();
        },
        skipLabel: 'Tidak sekarang',
        onSkip: onNext,
      );
}

/// Layar akhir — checkmark animasi besar + confetti bintang + aksi nyata pertama.
class SuccessScreen extends StatefulWidget {
  const SuccessScreen(
      {super.key, required this.connector, required this.onDone});
  final WhatsAppConnector connector;
  final VoidCallback onDone;
  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..forward();
  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _sendTest() async {
    final uri = Uri.parse(
        'https://wa.me/${widget.connector.botNumber}?text=${Uri.encodeComponent('Halo bot!')}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      const Positioned.fill(
          child: DecoratedBox(
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
            Color(0xFFE7F8DF),
            Color(0xFFF8F3C8),
            Color(0xFFE1F5D5)
          ])))),
      const Positioned.fill(child: ConfettiStars()),
      SafeArea(child: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxHeight < 620;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: ConstrainedBox(
              constraints:
                  BoxConstraints(minHeight: constraints.maxHeight - 48),
              child: Column(children: [
                SizedBox(height: compact ? 20 : 68),
                Text('Bot kamu online! 🎉',
                    textAlign: TextAlign.center,
                    style: h1(context).copyWith(fontSize: 34)),
                const SizedBox(height: 8),
                Text('Bot WhatsApp pertamamu aktif dan siap membalas.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        color: Palette.greenDark,
                        fontWeight: FontWeight.w600)),
                SizedBox(height: compact ? 24 : 40),
                RepaintBoundary(
                  child: CustomPaint(
                    size: Size(compact ? 175 : 230, compact ? 175 : 230),
                    painter: _CheckPainter(_c),
                  ),
                ),
                SizedBox(height: compact ? 26 : 60),
                Text('Coba kirim pesan test ke nomor botmu sekarang.',
                    textAlign: TextAlign.center,
                    style: sub(context, color: Palette.greenDark)),
                const SizedBox(height: 20),
                PrimaryButton(
                    label: 'Kirim pesan test 🚀',
                    onTap: _sendTest,
                    icon: Icons.send_rounded),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.55),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.share_outlined,
                          size: 18, color: Palette.greenDark),
                      const SizedBox(width: 8),
                      Text('Screenshot & bagikan ke rekan bisnismu!',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Palette.greenDark)),
                    ],
                  ),
                ),
                SizedBox(
                    height: 48,
                    child: GhostButton(
                        label: 'Ke dashboard', onTap: widget.onDone)),
              ])),
        );
      })),
    ]);
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(Animation<double> progress)
      : _progress = progress,
        _checkMetric = _buildCheckPath().computeMetrics().first,
        super(repaint: progress);

  final Animation<double> _progress;
  final PathMetric _checkMetric;
  final Paint _circlePaint = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFA8FFB8), Palette.mint],
    ).createShader(const Rect.fromLTWH(0, 0, 1, 1));
  final Paint _checkPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = .112
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    final t = Curves.easeOutCubic.transform(_progress.value);
    const c = Offset(.5, .5);
    const r = .5;
    final circleT = (t / .55).clamp(0.0, 1.0);
    canvas.save();
    canvas.scale(size.width, size.height);
    canvas.drawCircle(
      c,
      r * circleT,
      _circlePaint,
    );
    final checkT = ((t - .45) / .55).clamp(0.0, 1.0);
    if (checkT > 0) {
      canvas.drawPath(
        _checkMetric.extractPath(0, _checkMetric.length * checkT),
        _checkPaint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CheckPainter old) => false;

  static Path _buildCheckPath() => Path()
    ..moveTo(.28, .52)
    ..lineTo(.45, .68)
    ..lineTo(.74, .36);
}
