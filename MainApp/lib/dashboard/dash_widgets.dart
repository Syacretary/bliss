import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../onboarding/common.dart';
import 'dash_state.dart';

TextStyle tStyle(double size,
        {FontWeight w = FontWeight.w600,
        Color color = Palette.ink,
        double? height}) =>
    GoogleFonts.plusJakartaSans(
        fontSize: size, fontWeight: w, color: color, height: height);

class SampleDataNotice extends StatelessWidget {
  const SampleDataNotice({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.72),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded,
              size: 18, color: Palette.greenDark),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Statistik dan percakapan di dashboard ini masih data contoh.',
              style: tStyle(12, w: FontWeight.w600, color: Palette.greenDark),
            ),
          ),
        ]),
      );
}

class DashboardDataNotice extends StatelessWidget {
  const DashboardDataNotice({super.key, required this.text, this.onRetry});
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.76),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded,
              size: 18, color: Palette.greenDark),
          const SizedBox(width: 9),
          Expanded(
            child: Text(text,
                style:
                    tStyle(12, w: FontWeight.w600, color: Palette.greenDark)),
          ),
          if (onRetry != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Muat ulang',
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded,
                  size: 20, color: Palette.greenDark),
            ),
        ]),
      );
}

class DCard extends StatelessWidget {
  const DCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(18),
      this.color,
      this.radius = 28,
      this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final double radius;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: color ?? Colors.white.withOpacity(.8),
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
            onTap: onTap, child: Padding(padding: padding, child: child)),
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.action, this.onAction});
  final String text;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 26, 4, 12),
        child: Row(children: [
          Expanded(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tStyle(19, w: FontWeight.w800))),
          if (action != null)
            GestureDetector(
                onTap: onAction,
                child: Text(action!,
                    style: tStyle(13.5,
                        color: Palette.greenText, w: FontWeight.w700))),
        ]),
      );
}

class CountUp extends StatelessWidget {
  const CountUp(
      {super.key, required this.value, required this.style, this.format});
  final double value;
  final TextStyle style;
  final String Function(double)? format;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => Text(format?.call(v) ?? v.round().toString(),
            maxLines: 1, style: style),
      );
}

String fmtMinutes(double m) {
  final v = m.round();
  return v >= 60
      ? '${v ~/ 60}j ${(v % 60).toString().padLeft(2, '0')}m'
      : '${v}m';
}

/// Titik status berdenyut.
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, required this.color, this.active = true});
  final Color color;
  final bool active;
  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1700));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) || !widget.active) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void didUpdateWidget(PulseDot old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) _c.repeat();
    if (!widget.active) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 18,
        height: 18,
        child: Stack(alignment: Alignment.center, children: [
          if (widget.active)
            AnimatedBuilder(
              animation: _c,
              builder: (_, __) => Opacity(
                opacity: (1 - _c.value) * .6,
                child: Transform.scale(
                    scale: .5 + _c.value * 1.1,
                    child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                            color: widget.color, shape: BoxShape.circle))),
              ),
            ),
          Container(
              width: 9,
              height: 9,
              decoration:
                  BoxDecoration(color: widget.color, shape: BoxShape.circle)),
        ]),
      );
}

/// Gauge cincin animasi.
class RingGauge extends StatelessWidget {
  const RingGauge(
      {super.key,
      required this.value,
      required this.child,
      this.size = 128,
      this.active = true});
  final double value;
  final double size;
  final bool active;
  final Widget child;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(
              begin: 0, end: active ? value.clamp(0.0, 1.0).toDouble() : 0.0),
          duration: const Duration(milliseconds: 1100),
          curve: Curves.easeOutCubic,
          builder: (_, v, c) => CustomPaint(
              painter: _RingPainter(v, active), child: Center(child: c)),
          child: child,
        ),
      );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.active);
  final double v;
  final bool active;
  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.width / 2 - 14;
    final tick = Paint()
      ..color = Colors.white.withOpacity(.12)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 60; i++) {
      final a = i * math.pi / 30;
      final long = i % 5 == 0;
      canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * (r + 11),
          c + Offset(math.cos(a), math.sin(a)) * (r + (long ? 6 : 8)), tick);
    }
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = Colors.white.withOpacity(.1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12);
    if (v <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * v,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round
        ..shader = const SweepGradient(
                startAngle: 0,
                endAngle: 2 * math.pi,
                colors: [Palette.mint, Palette.green, Palette.mint],
                transform: GradientRotation(-math.pi / 2))
            .createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.v != v || o.active != active;
}

class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.data, this.color = Palette.green});
  final List<double> data;
  final Color color;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        key: ValueKey(data.join(',')),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeOutCubic,
        builder: (_, t, __) => CustomPaint(
            painter: _SparkPainter(data, color, t), size: Size.infinite),
      );
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.d, this.color, this.t);
  final List<double> d;
  final Color color;
  final double t;
  @override
  void paint(Canvas c, Size s) {
    if (d.length < 2 || s.width <= 0) return;
    final mx = d.reduce(math.max), mn = d.reduce(math.min);
    final range = (mx - mn) == 0 ? 1.0 : mx - mn;
    final n = d.length;
    final pts = [
      for (var i = 0; i < n; i++)
        Offset(i / (n - 1) * s.width,
            s.height - ((d[i] - mn) / range) * (s.height - 6) - 3)
    ];
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < n; i++) {
      final mid = (pts[i - 1].dx + pts[i].dx) / 2;
      path.cubicTo(mid, pts[i - 1].dy, mid, pts[i].dy, pts[i].dx, pts[i].dy);
    }
    c.save();
    c.clipRect(Rect.fromLTWH(0, 0, s.width * t, s.height));
    final fill = Path.from(path)
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();
    c.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color.withOpacity(.35), color.withOpacity(0)])
              .createShader(Offset.zero & s));
    c.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round);
    c.restore();
  }

  @override
  bool shouldRepaint(_SparkPainter o) => o.t != t || o.d != d;
}

/// Toggle segmen dengan indikator geser.
class SegToggle extends StatelessWidget {
  const SegToggle(
      {super.key,
      required this.labels,
      required this.index,
      required this.onChanged,
      this.width = 150});
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final double width;
  @override
  Widget build(BuildContext context) {
    final n = labels.length;
    return Container(
      width: width,
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: Colors.black.withOpacity(.06),
          borderRadius: BorderRadius.circular(18)),
      child: Stack(children: [
        AnimatedAlign(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment(n == 1 ? 0 : -1 + 2 * index / (n - 1), 0),
          child: FractionallySizedBox(
              widthFactor: 1 / n,
              heightFactor: 1,
              child: Container(
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15)))),
        ),
        Row(children: [
          for (var i = 0; i < n; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(i);
                },
                child: Center(
                    child: Text(labels[i],
                        style: tStyle(12.5,
                            w: FontWeight.w700,
                            color: i == index ? Palette.ink : Colors.black45))),
              ),
            ),
        ]),
      ]),
    );
  }
}

/// Grafik batang yang bisa di-scrub (geser / ketuk).
class ActivityChart extends StatefulWidget {
  const ActivityChart(
      {super.key,
      required this.values,
      required this.labels,
      required this.tooltip,
      required this.peak});
  final List<int> values;
  final List<String> labels;
  final String Function(int) tooltip;
  final int peak;
  @override
  State<ActivityChart> createState() => _ActivityChartState();
}

class _ActivityChartState extends State<ActivityChart> {
  late int sel = widget.peak;
  @override
  void didUpdateWidget(ActivityChart old) {
    super.didUpdateWidget(old);
    if (old.values != widget.values) sel = widget.peak;
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 190,
        child: LayoutBuilder(builder: (context, c) {
          void pick(Offset p) {
            if (c.maxWidth <= 0) return;
            final n = widget.values.length;
            final i = (p.dx / c.maxWidth * n).floor().clamp(0, n - 1);
            if (i != sel) {
              HapticFeedback.selectionClick();
              setState(() => sel = i);
            }
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => pick(d.localPosition),
            onHorizontalDragUpdate: (d) => pick(d.localPosition),
            child: TweenAnimationBuilder<double>(
              key: ValueKey(widget.values),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              builder: (_, t, __) => CustomPaint(
                size: Size(c.maxWidth, 190),
                painter: _BarsPainter(widget.values, widget.labels, t, sel,
                    widget.peak, widget.tooltip(sel)),
              ),
            ),
          );
        }),
      );
}

class _BarsPainter extends CustomPainter {
  _BarsPainter(this.v, this.labels, this.t, this.sel, this.peak, this.tip);
  final List<int> v;
  final List<String> labels;
  final double t;
  final int sel, peak;
  final String tip;

  TextPainter _tp(String s, TextStyle st) => TextPainter(
      text: TextSpan(text: s, style: st), textDirection: TextDirection.ltr)
    ..layout();

  @override
  void paint(Canvas c, Size s) {
    final n = v.length;
    if (n == 0 || s.width <= 0) return;
    const top = 34.0, bottom = 22.0;
    final chartH = s.height - top - bottom;
    final double mx = math.max(1.0, v.reduce(math.max).toDouble());
    final gap = n > 10 ? 3.0 : 8.0;
    final bw = (s.width - gap * (n - 1)) / n;
    final labelStep = n > 10 ? 6 : 1;
    final lbl = tStyle(10.5, color: Colors.black45, w: FontWeight.w600);
    for (var i = 0; i < n; i++) {
      final tt = ((t * 1.5) - i / n * .5).clamp(0.0, 1.0);
      final h = math.max(4.0, v[i] / mx * chartH) *
          Curves.easeOutBack.transform(tt).clamp(0.0, 1.2);
      final x = i * (bw + gap);
      final color = i == sel
          ? Palette.green
          : (i == peak
              ? Palette.green.withOpacity(.5)
              : Palette.greenSoft.withOpacity(.65));
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x, s.height - bottom - h, bw, h),
              Radius.circular(math.min(bw / 2, 7))),
          Paint()..color = color);
      if (i % labelStep == 0) {
        final tp = _tp(labels[i], lbl);
        tp.paint(c, Offset(x + bw / 2 - tp.width / 2, s.height - bottom + 6));
      }
    }
    // tooltip
    final h = math.max(4.0, v[sel] / mx * chartH);
    final x = sel * (bw + gap) + bw / 2;
    final tp = _tp(tip, tStyle(11.5, w: FontWeight.w700, color: Colors.white));
    final w = tp.width + 20;
    final left = (x - w / 2).clamp(0.0, math.max(0.0, s.width - w)).toDouble();
    final y = (s.height - bottom - h - 34).clamp(0.0, s.height).toDouble();
    final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, y, w, 26), const Radius.circular(13));
    c.drawRRect(r, Paint()..color = Palette.ink);
    tp.paint(c, Offset(left + 10, y + 13 - tp.height / 2));
    c.drawPath(
        Path()
          ..moveTo(x - 5, y + 26)
          ..lineTo(x + 5, y + 26)
          ..lineTo(x, y + 32)
          ..close(),
        Paint()..color = Palette.ink);
  }

  @override
  bool shouldRepaint(_BarsPainter o) =>
      o.t != t || o.sel != sel || o.v != v || o.tip != tip;
}

// ── Sheet uji bot ──
Future<void> showTestSheet(BuildContext context, DashState st) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TestSheet(st: st),
    );

class _Msg {
  _Msg(this.text, this.bot);
  final String text;
  final bool bot;
}

class _TestSheet extends StatefulWidget {
  const _TestSheet({required this.st});
  final DashState st;
  @override
  State<_TestSheet> createState() => _TestSheetState();
}

class _TestSheetState extends State<_TestSheet> {
  static const qs = [
    'Jam buka sampai kapan?',
    'Ada promo hari ini?',
    'Bisa kirim ke luar kota?'
  ];
  final msgs = <_Msg>[];
  bool typing = false;
  final scroll = ScrollController();
  final textCtrl = TextEditingController();
  final focusNode = FocusNode();

  @override
  void dispose() {
    scroll.dispose();
    textCtrl.dispose();
    focusNode.dispose();
    super.dispose();
  }

  Future<void> sendUserMessage(String input) async {
    final text = input.trim();
    if (text.isEmpty || typing) return;
    textCtrl.clear();

    final autoTypingPlugin = widget.st.plugins.firstWhere(
      (p) => p.id == 'autotyping',
      orElse: () => PluginItem(
          id: '',
          name: '',
          description: '',
          icon: Icons.keyboard_alt_outlined,
          enabled: false),
    );

    setState(() {
      msgs.add(_Msg(text, false));
      typing = autoTypingPlugin.enabled;
    });
    _down();

    final botReply = await widget.st.generateAiResponse(text);

    if (!mounted) return;
    setState(() {
      msgs.add(_Msg(botReply, true));
      typing = false;
    });
    _down();
  }

  void _down() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) {
          scroll.animateTo(scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut);
        }
      });

  @override
  Widget build(BuildContext context) {
    final activeModel =
        widget.st.getModelForProvider(widget.st.provider).isNotEmpty
            ? widget.st.getModelForProvider(widget.st.provider)
            : DashState.getDefaultModel(widget.st.provider);
    return Container(
      height: MediaQuery.of(context).size.height * .85,
      decoration: const BoxDecoration(
          color: Palette.bgTop,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(children: [
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.black26, borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 14),
        Row(children: [
          const Mascot(size: 40, blue: false),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Uji Bot Live AI', style: tStyle(18, w: FontWeight.w800)),
              Text(
                '${widget.st.provider} · $activeModel',
                style:
                    tStyle(11.5, color: Palette.greenDark, w: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: Palette.green.withOpacity(.25),
                borderRadius: BorderRadius.circular(10)),
            child: Text(DashState.toneNames[widget.st.toneIndex],
                style:
                    tStyle(12, color: Palette.greenDark, w: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: msgs.isEmpty && !typing
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.chat_outlined,
                          size: 44, color: Palette.mint),
                      const SizedBox(height: 10),
                      Text(
                          'Ketik pertanyaan di bawah atau ketuk saran untuk menguji respons AI bot milikmu secara live.',
                          textAlign: TextAlign.center,
                          style: sub(context).copyWith(fontSize: 13.5)),
                    ]),
                  ),
                )
              : ListView(controller: scroll, children: [
                  for (final m in msgs)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ChatBubble(
                            text: m.text,
                            outgoing: m.bot,
                            maxWidth: 290,
                            time: '')),
                  if (typing)
                    const Align(
                        alignment: Alignment.centerRight, child: _Typing()),
                ]),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (var i = 0; i < qs.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              ActionChip(
                label: Text(qs[i], style: tStyle(12.5, w: FontWeight.w600)),
                backgroundColor: Colors.white,
                side: BorderSide(color: Palette.green.withOpacity(.3)),
                onPressed: () => sendUserMessage(qs[i]),
              ),
            ]
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextField(
              controller: textCtrl,
              focusNode: focusNode,
              textInputAction: TextInputAction.send,
              onSubmitted: sendUserMessage,
              decoration: InputDecoration(
                hintText: 'Ketik pesan untuk uji bot...',
                hintStyle: tStyle(13.5, color: Colors.black38),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide:
                        BorderSide(color: Palette.green.withOpacity(.4))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide:
                        BorderSide(color: Palette.green.withOpacity(.4))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide:
                        const BorderSide(color: Palette.green, width: 2)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: typing ? null : () => sendUserMessage(textCtrl.text),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: typing ? Colors.black26 : Palette.green,
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _Typing extends StatefulWidget {
  const _Typing();
  @override
  State<_Typing> createState() => _TypingState();
}

class _TypingState extends State<_Typing> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
            color: Palette.bubbleOut, borderRadius: BorderRadius.circular(16)),
        child: AnimatedBuilder(
          animation: c,
          builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < 3; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                    color: Palette.greenDark.withOpacity(.35 +
                        .65 *
                            math.max(
                                0, math.sin((c.value * 2 - i * .3) * math.pi))),
                    shape: BoxShape.circle),
              ),
          ]),
        ),
      );
}
