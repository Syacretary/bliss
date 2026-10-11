import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'common.dart';

/// Layar 1 — HP dengan layar ">_" berubah menjadi chat aktual.
class Intro1 extends StatefulWidget {
  const Intro1({super.key, required this.onNext});
  final VoidCallback onNext;
  @override
  State<Intro1> createState() => _Intro1State();
}

class _Intro1State extends State<Intro1> {
  bool chat = false;
  Timer? _chatTimer;
  @override
  void initState() {
    super.initState();
    _chatTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => chat = true);
    });
  }

  @override
  void dispose() {
    _chatTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(children: [
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: 'Bayangkan WhatsApp bisnismu\n'),
            TextSpan(
                text: 'membalas 24 jam.',
                style: TextStyle(color: Palette.green)),
          ]),
          textAlign: TextAlign.center,
          style: h1(context).copyWith(fontSize: 30),
        ),
        const SizedBox(height: 20),
        Expanded(child: Center(child: _Phone(showChat: chat))),
        const SizedBox(height: 12),
        Text(
            'Dengan gaya yang kamu tentukan. Tanpa koding, tanpa server mahal. Cukup dari HP kamu.',
            textAlign: TextAlign.center,
            style:
                sub(context, color: Palette.greenDark).copyWith(fontSize: 16)),
        const SizedBox(height: 20),
        PrimaryButton(
            label: 'Lanjut',
            onTap: widget.onNext,
            icon: Icons.arrow_forward_rounded),
      ]),
    );
  }
}

class _Phone extends StatelessWidget {
  const _Phone({required this.showChat});
  final bool showChat;
  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: .56,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Palette.ink,
          borderRadius: BorderRadius.circular(36),
          boxShadow: [
            BoxShadow(
                color: Palette.greenDark.withOpacity(.25),
                blurRadius: 30,
                offset: const Offset(0, 16))
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            child: showChat
                ? const _ChatScreen(key: ValueKey('chat'))
                : const _TerminalScreen(key: ValueKey('term')),
          ),
        ),
      ),
    );
  }
}

class _TerminalScreen extends StatelessWidget {
  const _TerminalScreen({super.key});
  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFF0B1410),
        alignment: Alignment.center,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1400),
          builder: (_, v, __) => Text(
            '>_${v > .5 ? ' ▍' : ''}',
            style: GoogleFonts.jetBrainsMono(
                fontSize: 44,
                color: Palette.green,
                fontWeight: FontWeight.w700),
          ),
        ),
      );
}

class _ChatScreen extends StatelessWidget {
  const _ChatScreen({super.key});
  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFFEFF6EC),
        padding: const EdgeInsets.all(12),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: 190,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _Pop(
                    delay: 0,
                    child: const ChatBubble(
                        text: 'Halo kak, tokonya memiliki produk apa aja?',
                        maxWidth: 190,
                        fontSize: 12.5)),
                const SizedBox(height: 10),
                _Pop(
                    delay: 500,
                    child: const ChatBubble(
                        text: 'Halo kak! Berikut adalah produk kami',
                        outgoing: true,
                        maxWidth: 190,
                        fontSize: 12.5)),
                const SizedBox(height: 8),
                _Pop(delay: 900, child: const ProductRow(size: 52)),
                const SizedBox(height: 6),
                _Pop(delay: 1100, child: const AiTag()),
              ],
            ),
          ),
        ),
      );
}

/// Muncul berurutan (scale+fade) — satu momen orkestrasi, bukan efek berserakan.
class _Pop extends StatelessWidget {
  const _Pop({required this.delay, required this.child});
  final int delay;
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 450 + delay),
        curve: Interval(delay / (450 + delay), 1, curve: Curves.easeOutBack),
        builder: (_, v, c) => Opacity(
            opacity: v.clamp(0, 1),
            child: Transform.scale(scale: .85 + .15 * v, child: c)),
        child: child,
      );
}

/// Layar 2 — "Mau bot-mu jadi apa?" dengan 3 mockup yang bisa digeser.
class Intro2 extends StatefulWidget {
  const Intro2(
      {super.key,
      required this.onNext,
      required this.visited,
      required this.onViewed});
  final VoidCallback onNext;
  final Set<int> visited;
  final ValueChanged<int> onViewed;
  @override
  State<Intro2> createState() => _Intro2State();
}

class _Intro2State extends State<Intro2> {
  final _pc = PageController(viewportFraction: .86);
  int page = 0;
  bool _assetsWarmed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_assetsWarmed) return;
    _assetsWarmed = true;
    // Decode the small images before the first swipe, not while the page is
    // animating. ResizeImage keeps the decoded copies close to display size.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final imageSizes = <String, double>{
      'assets/images/avatarai_ready.png': 28,
      'assets/images/avatarai_ready2.png': 28,
      'assets/images/avatarai_wake.png': 28,
      'assets/images/avatarai_sleep.png': 28,
      'assets/images/avatarai_lazy.png': 28,
      'assets/images/coffee1.jpg': 60,
      'assets/images/coffe2.jpg': 60,
      'assets/images/coffee3.jpg': 60,
    };
    for (final entry in imageSizes.entries) {
      final pixelSize = (entry.value * dpr).round();
      precacheImage(
        ResizeImage(AssetImage(entry.key), width: pixelSize, height: pixelSize),
        context,
      );
    }
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cards = [
      const _UseCase(
          'Customer Service 24/7',
          'Halo kak, tokonya memiliki produk apa aja?',
          'Halo kak! Berikut adalah produk kami',
          true),
      const _UseCase(
          'Asisten Pribadi',
          'Nanti ingetin aku jam 5 sore buat beli garam ya!',
          'Baik, reminder telah ditambahkan untuk jam 5 sore.',
          false),
      const _UseCase(
          'Bot Komunitas',
          'Halo, aku baru join. Aturan grupnya apa ya?',
          'Selamat datang! Aturan lengkap ada di deskripsi grup ya 🙌',
          false),
    ];
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(28, 40, 28, 0),
        child: Column(children: [
          Text('Mau bot-mu jadi apa?',
              textAlign: TextAlign.center,
              style: h1(context).copyWith(fontSize: 32)),
          const SizedBox(height: 10),
          Text('Buat bantu bisnis, komunitas, atau hal kecil sehari-hari.',
              textAlign: TextAlign.center, style: sub(context)),
        ]),
      ),
      Expanded(
        child: PageView.builder(
          controller: _pc,
          itemCount: cards.length,
          onPageChanged: (i) {
            setState(() => page = i);
            widget.onViewed(i);
          },
          itemBuilder: (_, i) => AnimatedScale(
            scale: page == i ? 1 : .92,
            duration: const Duration(milliseconds: 250),
            child: RepaintBoundary(child: Center(child: cards[i])),
          ),
        ),
      ),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < cards.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: page == i ? 22 : 7,
            height: 7,
            decoration: BoxDecoration(
                color: page == i ? Palette.green : Palette.greenSoft,
                borderRadius: BorderRadius.circular(8)),
          ),
      ]),
      Padding(
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
        child: Column(children: [
          if (widget.visited.length < cards.length)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                  'Geser untuk jelajahi semua contoh (${widget.visited.length}/${cards.length})',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Palette.greenDark)),
            ),
          PrimaryButton(
            label: widget.visited.length == cards.length
                ? 'Lanjut'
                : 'Jelajahi semua mockup',
            onTap: widget.onNext,
            enabled: widget.visited.length == cards.length,
            icon: widget.visited.length == cards.length
                ? Icons.arrow_forward_rounded
                : Icons.swipe_rounded,
          ),
        ]),
      ),
    ]);
  }
}

class _UseCase extends StatelessWidget {
  const _UseCase(this.label, this.q, this.a, this.withProducts);
  final String label, q, a;
  final bool withProducts;
  @override
  Widget build(BuildContext context) {
    final avatar = label.startsWith('Customer')
        ? 'assets/images/avatarai_ready.png'
        : label.startsWith('Asisten')
            ? 'assets/images/avatarai_wake.png'
            : 'assets/images/avatarai_ready2.png';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(.55),
          borderRadius: BorderRadius.circular(28)),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ChatBubble(text: q, maxWidth: 240),
            const SizedBox(height: 10),
            ChatBubble(text: a, outgoing: true, maxWidth: 240),
            if (withProducts) ...[
              const SizedBox(height: 10),
              const Center(child: ProductRow(size: 60))
            ],
            const SizedBox(height: 8),
            Align(
                alignment: Alignment.centerRight,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Direspon oleh AI',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, color: Colors.black45)),
                  const SizedBox(width: 6),
                  ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(avatar,
                          width: 28,
                          height: 28,
                          cacheWidth:
                              (28 * MediaQuery.devicePixelRatioOf(context))
                                  .round(),
                          cacheHeight:
                              (28 * MediaQuery.devicePixelRatioOf(context))
                                  .round(),
                          fit: BoxFit.cover)),
                ])),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: Palette.green.withOpacity(.25),
                  borderRadius: BorderRadius.circular(14)),
              child: Text(label,
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700, color: Palette.greenDark)),
            ),
          ]),
    );
  }
}

/// Layar 3 — gaya bubble chat: sapaan maskot.
class Intro3 extends StatelessWidget {
  const Intro3({super.key, required this.onNext});
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 650;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            minHeight: MediaQuery.sizeOf(context).height -
                MediaQuery.paddingOf(context).vertical -
                90),
        child: Column(children: [
          SizedBox(height: compact ? 28 : 70),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset('assets/images/avatarai_wake.png',
                    width: 58,
                    height: 58,
                    cacheWidth:
                        (58 * MediaQuery.devicePixelRatioOf(context)).round(),
                    cacheHeight:
                        (58 * MediaQuery.devicePixelRatioOf(context)).round(),
                    fit: BoxFit.cover)),
            const SizedBox(width: 10),
            Expanded(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutBack,
                builder: (_, v, c) => Opacity(
                    opacity: v.clamp(0, 1),
                    child: Transform.scale(
                        alignment: Alignment.bottomLeft,
                        scale: .8 + .2 * v,
                        child: c)),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                        bottomLeft: Radius.circular(4)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(.07),
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Text(
                    'Halo~ Aku Syacretary, developer Bliss. Aku bikin Bliss karena capek lihat orang langganan server mahal hanya untuk bot WA. Yuk setup bot pertamamu dalam < 3 menit.',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 16, height: 1.45, color: Palette.ink),
                  ),
                ),
              ),
            ),
          ]),
          SizedBox(height: compact ? 36 : 80),
          Text('Siap bikin bot pertamamu?',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: Palette.greenDark)),
          SizedBox(height: compact ? 28 : 64),
          PrimaryButton(
              label: 'Yuk Setup', onTap: onNext, icon: Icons.bolt_rounded),
        ]),
      ),
    );
  }
}
