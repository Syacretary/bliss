import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Palette {
  static const green = Color(0xFF69E26B);
  static const greenSoft = Color(0xFFB4E3B1);
  static const greenDark = Color(0xFF1B6B3A);
  static const greenText = Color(0xFF3F6B24);
  static const ink = Color(0xFF111A14);
  static const bgTop = Color(0xFFECEFEA);
  static const bgBottom = Color(0xFFE3F6E3);
  static const bubbleOut = Color(0xFFEBFFE8);
  static const mint = Color(0xFF86F5C4);
}

TextStyle h1(BuildContext c, {Color color = Palette.ink}) =>
    GoogleFonts.plusJakartaSans(
        fontSize: 34,
        height: 1.15,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: -0.5);

TextStyle sub(BuildContext c, {Color color = Palette.greenText}) =>
    GoogleFonts.plusJakartaSans(
        fontSize: 17, height: 1.5, fontWeight: FontWeight.w500, color: color);

/// Background gradien lembut seperti referensi.
class OnbBackground extends StatelessWidget {
  const OnbBackground({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
              decoration: BoxDecoration(
                  gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Palette.bgTop, Palette.bgBottom],
          ))),
          const _AmbientOrbs(),
          child,
        ],
      );
}

class _AmbientOrbs extends StatefulWidget {
  const _AmbientOrbs();
  @override
  State<_AmbientOrbs> createState() => _AmbientOrbsState();
}

class _AmbientOrbsState extends State<_AmbientOrbs>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3600))
    ..forward();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _AmbientPainter(_controller),
            size: Size.infinite,
          ),
        ),
      );
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter(Animation<double> animation)
      : _animation = animation,
        super(repaint: animation);

  final Animation<double> _animation;
  final Paint _mint = Paint()..color = Palette.mint.withOpacity(.20);
  final Paint _green = Paint()..color = Palette.green.withOpacity(.13);

  @override
  void paint(Canvas canvas, Size size) {
    final t = Curves.easeInOut.transform(_animation.value.clamp(0, 1));
    canvas.drawCircle(Offset(size.width - 20 - 25 * t, 15 + 35 * t), 95, _mint);
    canvas.drawCircle(
        Offset(10 + 35 * t, size.height - 160 + 30 * t), 75, _green);
  }

  // CustomPainter's repaint listenable schedules paint directly, without
  // rebuilding the background widget subtree every display frame.
  @override
  bool shouldRepaint(_AmbientPainter oldDelegate) => false;
}

/// Progress bar bersegmen; tiap segmen terisi halus (animasi).
class SegmentedProgress extends StatelessWidget {
  const SegmentedProgress(
      {super.key, required this.fills, this.completed = false});
  final List<double> fills; // 0..1 per segmen
  final bool completed;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < fills.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(children: [
                Container(height: 6, color: Palette.greenSoft),
                TweenAnimationBuilder<double>(
                  tween: Tween(end: fills[i]),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => FractionallySizedBox(
                    widthFactor: v,
                    child: Container(height: 6, color: Palette.green),
                  ),
                ),
              ]),
            ),
          ),
        ],
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: completed
              ? const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.check_circle_rounded,
                      key: ValueKey('complete'),
                      color: Palette.greenDark,
                      size: 18))
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton(
      {super.key,
      required this.label,
      required this.onTap,
      this.icon,
      this.enabled = true});
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: enabled ? onTap : null,
        style: FilledButton.styleFrom(
          backgroundColor: Palette.ink,
          disabledBackgroundColor: Palette.ink.withOpacity(.25),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
          if (icon != null) ...[
            const SizedBox(width: 8),
            Icon(icon, size: 20, color: Colors.white)
          ],
        ]),
      ),
    );
  }
}

class GhostButton extends StatelessWidget {
  const GhostButton({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onTap,
        child: Text(label,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Palette.greenText)),
      );
}

/// Avatar AI dari aset produk, agar seluruh percakapan memiliki identitas visual yang konsisten.
/// [asset] dapat diisi langsung jika ingin avatar spesifik (misal: 'assets/images/avatarai_ready2.png').
/// Default menggunakan [blue] (true = avatarai_ready.png, false = avatarai_wake.png) atau [asset].
class Mascot extends StatelessWidget {
  const Mascot({super.key, this.size = 56, this.blue = true, this.asset});
  final double size;
  final bool blue;
  final String? asset;

  @override
  Widget build(BuildContext context) {
    final imagePath = asset ??
        (blue
            ? 'assets/images/avatarai_ready.png'
            : 'assets/images/avatarai_wake.png');
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * .28),
      child: Image.asset(
        imagePath,
        width: size,
        height: size,
        cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
        cacheHeight: (size * MediaQuery.devicePixelRatioOf(context)).round(),
        fit: BoxFit.cover,
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  const ChatBubble(
      {super.key,
      required this.text,
      this.outgoing = false,
      this.time = '09.41',
      this.maxWidth = 280,
      this.fontSize = 15});
  final String text;
  final bool outgoing;
  final String time;
  final double maxWidth;
  final double fontSize;
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 8),
        decoration: BoxDecoration(
          color: outgoing ? Palette.bubbleOut : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(.06),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
                child: Text(text,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: fontSize, height: 1.35, color: Palette.ink))),
            const SizedBox(width: 10),
            Text(time,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5, color: Colors.black45)),
          ],
        ),
      ),
    );
  }
}

class AiTag extends StatelessWidget {
  const AiTag({super.key});
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Text('Direspon oleh AI',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 12, color: Colors.black45)),
        const SizedBox(width: 6),
        const Mascot(size: 26, blue: false),
      ]);
}

/// Thumbnail produk. Memakai aset bila ada, jika tidak pakai placeholder emoji.
class ProductThumb extends StatelessWidget {
  const ProductThumb({super.key, required this.asset, this.size = 64});
  final String asset;
  final double size;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          asset,
          width: size,
          height: size,
          cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
          cacheHeight: (size * MediaQuery.devicePixelRatioOf(context)).round(),
          fit: BoxFit.cover,
        ),
      );
}

class ProductRow extends StatelessWidget {
  const ProductRow({super.key, this.size = 64});
  final double size;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        ProductThumb(asset: 'assets/images/coffee1.jpg', size: size),
        const SizedBox(width: 8),
        ProductThumb(asset: 'assets/images/coffe2.jpg', size: size),
        const SizedBox(width: 8),
        ProductThumb(asset: 'assets/images/coffee3.jpg', size: size),
      ]);
}

/// Confetti satu kali jalan, dengan variasi bentuk dan warna seperti potongan kertas asli.
class ConfettiStars extends StatefulWidget {
  const ConfettiStars({super.key, this.count = 64});
  final int count;
  @override
  State<ConfettiStars> createState() => _ConfettiStarsState();
}

class _ConfettiStarsState extends State<ConfettiStars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2800))
    ..forward();
  late final List<_Confetto> _pieces =
      List.generate(widget.count, (_) => _Confetto.random());
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
              painter: _ConfettiPainter(_pieces, _c), size: Size.infinite),
        ),
      );
}

enum _ConfettiShape { rectangle, ribbon, circle, star }

class _Confetto {
  _Confetto(
      this.x, this.y0, this.speed, this.size, this.color, this.rot, this.shape)
      : paint = Paint()..color = color.withOpacity(.85),
        starPath = shape == _ConfettiShape.star ? _makeStar(size) : null;
  final double x, y0, speed, size, rot;
  final Color color;
  final _ConfettiShape shape;
  final Paint paint;
  final Path? starPath;
  static final _r = math.Random();
  static const _colors = [
    Color(0xFFFF595E),
    Color(0xFFFFCA3A),
    Color(0xFF8AC926),
    Color(0xFF1982C4),
    Color(0xFF6A4C93),
    Color(0xFFFF70A6),
    Color(0xFF00B8A9),
  ];
  factory _Confetto.random() => _Confetto(
      _r.nextDouble(),
      -_r.nextDouble() * .35,
      .72 + _r.nextDouble() * .7,
      5 + _r.nextDouble() * 12,
      _colors[_r.nextInt(_colors.length)],
      _r.nextDouble() * 6,
      _ConfettiShape.values[_r.nextInt(_ConfettiShape.values.length)]);
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, Animation<double> animation)
      : _animation = animation,
        super(repaint: animation);

  final List<_Confetto> pieces;
  final Animation<double> _animation;
  @override
  void paint(Canvas canvas, Size size) {
    final t = _animation.value;
    for (final s in pieces) {
      final y = (s.y0 + t * s.speed * 1.75) * size.height;
      if (y < -20 || y > size.height + 20) continue;
      final fade = (1 - (y / (size.height * 1.1))).clamp(0.0, 1.0);
      final p = s.paint..color = s.color.withOpacity(.85 * fade);
      canvas.save();
      canvas.translate(s.x * size.width, y);
      canvas.rotate(s.rot + t * 8 * s.speed);
      _drawPiece(canvas, s, p);
      canvas.restore();
    }
  }

  void _drawPiece(Canvas canvas, _Confetto piece, Paint paint) {
    switch (piece.shape) {
      case _ConfettiShape.rectangle:
        canvas.drawRect(
            Rect.fromCenter(
                center: Offset.zero,
                width: piece.size * .55,
                height: piece.size * 1.45),
            paint);
      case _ConfettiShape.ribbon:
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: Offset.zero,
                    width: piece.size * .42,
                    height: piece.size * 1.9),
                Radius.circular(piece.size)),
            paint);
      case _ConfettiShape.circle:
        canvas.drawCircle(Offset.zero, piece.size * .52, paint);
      case _ConfettiShape.star:
        canvas.drawPath(piece.starPath!, paint);
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => false;
}

Path _makeStar(double radius) {
  final path = Path();
  for (var i = 0; i < 10; i++) {
    final r = i.isEven ? radius : radius * .45;
    final angle = -math.pi / 2 + i * math.pi / 5;
    final point = Offset(r * math.cos(angle), r * math.sin(angle));
    if (i == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  return path..close();
}
