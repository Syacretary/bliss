import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'common.dart';
import 'models.dart';

class _Option {
  const _Option(this.label, {this.icon, this.badge, this.isOther = false});
  final String label;
  final IconData? icon;
  final String? badge;
  final bool isOther;
}

/// 1 soal 1 layar. Tap jawaban -> tersorot sebentar -> otomatis lanjut.
class _QuizScaffold extends StatefulWidget {
  const _QuizScaffold(
      {required this.title,
      required this.options,
      required this.onPicked,
      this.initial,
      this.hint,
      this.illustration});
  final String title;
  final String? hint;
  final List<_Option> options;
  final int? initial;
  final Widget? illustration;
  final void Function(int index, String? custom) onPicked;
  @override
  State<_QuizScaffold> createState() => _QuizScaffoldState();
}

class _QuizScaffoldState extends State<_QuizScaffold> {
  int? selected;
  bool locked = false;

  @override
  void initState() {
    super.initState();
    selected = widget.initial;
  }

  Future<void> _tap(int i) async {
    if (locked) return;
    HapticFeedback.selectionClick();
    String? custom;
    if (widget.options[i].isOther) {
      custom = await _askCustom(context, widget.title);
      if (custom == null || custom.trim().isEmpty) return;
    }
    setState(() {
      selected = i;
      locked = true;
    });
    await Future.delayed(const Duration(milliseconds: 320));
    if (mounted) widget.onPicked(i, custom?.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.title, style: h1(context).copyWith(fontSize: 28)),
        if (widget.hint != null) ...[
          const SizedBox(height: 8),
          Text(widget.hint!, style: sub(context).copyWith(fontSize: 15)),
        ],
        const SizedBox(height: 28),
        Expanded(
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            itemCount:
                widget.options.length + (widget.illustration == null ? 0 : 1),
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              if (i == widget.options.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 28, bottom: 12),
                  child: widget.illustration!,
                );
              }
              final o = widget.options[i];
              final on = selected == i;
              return GestureDetector(
                onTap: () => _tap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                  decoration: BoxDecoration(
                    color: on
                        ? Palette.green.withOpacity(.28)
                        : Colors.white.withOpacity(.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: on ? Palette.green : Colors.transparent,
                        width: 2),
                  ),
                  child: Row(children: [
                    if (o.icon != null) ...[
                      Icon(o.icon, size: 28, color: Palette.greenDark),
                      const SizedBox(width: 14)
                    ],
                    Expanded(
                        child: Text(o.label,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w600,
                                color: Palette.ink))),
                    if (o.badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: o.badge == 'gratis'
                                ? Palette.green.withOpacity(.3)
                                : Colors.black12,
                            borderRadius: BorderRadius.circular(10)),
                        child: Text(o.badge!,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Palette.greenDark)),
                      ),
                    AnimatedScale(
                      scale: on ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutBack,
                      child: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(Icons.check_circle_rounded,
                            color: Palette.greenDark),
                      ),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

Future<String?> _askCustom(BuildContext context, String title) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _CustomAnswerSheet(title: title),
  );
}

class _CustomAnswerSheet extends StatefulWidget {
  const _CustomAnswerSheet({required this.title});
  final String title;

  @override
  State<_CustomAnswerSheet> createState() => _CustomAnswerSheetState();
}

class _CustomAnswerSheetState extends State<_CustomAnswerSheet> {
  late final TextEditingController _controller = TextEditingController();
  late final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Let the sheet finish its entrance before the keyboard animates in. Running
    // both transitions together was causing avoidable layout work on Android.
    Future<void>.delayed(const Duration(milliseconds: 420), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.viewInsetsOf(context).bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ceritakan sedikit',
                style: h1(context).copyWith(fontSize: 22)),
            const SizedBox(height: 6),
            Text(widget.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: sub(context).copyWith(fontSize: 13)),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'Tulis jawabanmu…',
                filled: true,
                fillColor: Palette.bgTop,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(label: 'Simpan', onTap: _submit),
          ],
        ),
      );
}

class _QuizVignette extends StatelessWidget {
  const _QuizVignette({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(alignment: Alignment.center, children: [
            Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                    color: Palette.green.withOpacity(.16),
                    shape: BoxShape.circle)),
            Icon(icon, color: Palette.greenDark, size: 40),
            const Positioned(
                right: 0, bottom: 2, child: Mascot(size: 36, blue: false)),
          ]),
          const SizedBox(height: 10),
          Text(label,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Palette.greenDark)),
        ]),
      );
}

class QPurpose extends StatelessWidget {
  const QPurpose({super.key, required this.answers, required this.onNext});
  final Answers answers;
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) => _QuizScaffold(
        title: 'Bot ini mau dipakai untuk apa?',
        initial: answers.purpose?.index,
        options: const [
          _Option('Teman Ngobrol Personal',
              icon: Icons.chat_bubble_outline_rounded),
          _Option('Asisten Grup Komunitas', icon: Icons.groups_2_outlined),
          _Option('Customer Service Bisnis', icon: Icons.storefront_outlined),
          _Option('Lainnya', icon: Icons.auto_awesome_outlined, isOther: true),
        ],
        illustration: const _QuizVignette(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Satu bot untuk setiap percakapanmu'),
        onPicked: (i, custom) {
          final nextPurpose = Purpose.values[i];
          if (answers.purpose != nextPurpose) {
            answers.volumeIndex = null;
            answers.businessName = null;
          }
          answers.purpose = nextPurpose;
          answers.purposeOther = nextPurpose == Purpose.other ? custom : null;
          onNext();
        },
      );
}

class QVolume extends StatelessWidget {
  const QVolume({super.key, required this.answers, required this.onNext});
  final Answers answers;
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) => _QuizScaffold(
        title: answers.isCS
            ? 'Seberapa sering kamu balas pesan customer dalam sehari?'
            : 'Seberapa sering kamu balas pesan anggota dalam sehari?',
        hint: 'Kami pakai ini untuk menghitung waktu yang bisa dihemat.',
        initial: answers.volumeIndex,
        options: const [
          _Option('Kurang dari 10 kali'),
          _Option('10 sampai 50'),
          _Option('50 sampai 100'),
          _Option('Lebih dari 100'),
        ],
        illustration: _QuizVignette(
            icon: answers.isCS
                ? Icons.storefront_outlined
                : Icons.groups_2_outlined,
            label: answers.isCS
                ? 'Pesan pelanggan tetap terjawab'
                : 'Komunitas tetap terasa terurus'),
        onPicked: (i, _) {
          answers.volumeIndex = i;
          onNext();
        },
      );
}

class QTone extends StatelessWidget {
  const QTone({super.key, required this.answers, required this.onNext});
  final Answers answers;
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) => _QuizScaffold(
        title: 'Bahasa dan gaya bicara bot seperti apa yang kamu mau?',
        initial: const ['Formal', 'Ramah', 'To the point']
            .indexOf(answers.tone ?? ''),
        options: const [
          _Option('Formal', icon: Icons.business_center_outlined),
          _Option('Ramah', icon: Icons.waving_hand_outlined),
          _Option('To the point', icon: Icons.bolt_outlined),
          _Option('Lainnya', icon: Icons.auto_awesome_outlined, isOther: true),
        ],
        illustration: _QuizVignette(
            icon: answers.isCS
                ? Icons.storefront_outlined
                : Icons.chat_bubble_outline_rounded,
            label: 'Gaya bicara ini akan membentuk setiap balasan'),
        onPicked: (i, custom) {
          answers.tone = custom ?? ['Formal', 'Ramah', 'To the point'][i];
          onNext();
        },
      );
}

/// Input teks tidak bisa auto-next, jadi memakai tombol Lanjut.
class QBusiness extends StatefulWidget {
  const QBusiness({super.key, required this.answers, required this.onNext});
  final Answers answers;
  final VoidCallback onNext;
  @override
  State<QBusiness> createState() => _QBusinessState();
}

class _QBusinessState extends State<QBusiness> {
  late final c = TextEditingController(text: widget.answers.businessName);
  late final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 340), () {
      if (mounted && !_focusNode.hasFocus) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    c.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _go() {
    if (c.text.trim().isEmpty) return;
    widget.answers.businessName = c.text.trim();
    FocusScope.of(context).unfocus();
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 36, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Apa nama bisnismu?', style: h1(context).copyWith(fontSize: 28)),
        const SizedBox(height: 8),
        Text('Bot akan memakai nama ini saat menyapa pelanggan.',
            style: sub(context).copyWith(fontSize: 15)),
        const SizedBox(height: 28),
        TextField(
          controller: c,
          focusNode: _focusNode,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _go(),
          style: GoogleFonts.plusJakartaSans(
              fontSize: 20, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'Contoh: Kopi Senja',
            filled: true,
            fillColor: Colors.white.withOpacity(.8),
            contentPadding: const EdgeInsets.all(20),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: Palette.green, width: 2)),
          ),
        ),
        const SizedBox(height: 22),
        const _QuizVignette(
            icon: Icons.storefront_outlined,
            label: 'Sapa pelanggan dengan identitas bisnismu'),
        const Spacer(),
        PrimaryButton(
            label: 'Lanjut', onTap: _go, enabled: c.text.trim().isNotEmpty),
      ]),
    );
  }
}

class QProvider extends StatelessWidget {
  const QProvider({super.key, required this.answers, required this.onNext});
  final Answers answers;
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) {
    const list = [
      _Option('OpenAI / ChatGPT', badge: 'berbayar'),
      _Option('Anthropic / Claude', badge: 'berbayar'),
      _Option('Google / Gemini', badge: 'gratis'),
      _Option('Opensource / Deepseek', badge: 'berbayar'),
      _Option('Groq', badge: 'gratis'),
      _Option('Belum tahu'),
    ];
    final selected =
        list.indexWhere((option) => option.label == answers.provider);
    return _QuizScaffold(
      title: 'Provider AI apa yang biasanya kamu pakai atau mau dicoba?',
      hint: 'Pilih "Belum tahu" kalau ragu. Bisa diganti kapan saja.',
      options: list,
      initial: selected < 0 ? null : selected,
      illustration: const _QuizVignette(
          icon: Icons.hub_outlined,
          label: 'Pilih mesin AI yang paling cocok untukmu'),
      onPicked: (i, _) {
        answers.provider = list[i].label;
        onNext();
      },
    );
  }
}

/// Preview personalisasi.
class PreviewScreen extends StatefulWidget {
  const PreviewScreen({super.key, required this.answers, required this.onNext});
  final Answers answers;
  final VoidCallback onNext;

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  int stage = 0;

  @override
  void initState() {
    super.initState();
    _preparePersona();
  }

  Future<void> _preparePersona() async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (mounted) setState(() => stage = 1);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (mounted) setState(() => stage = 2);
  }

  @override
  Widget build(BuildContext context) {
    if (stage < 2) return _PersonaLoading(stage: stage);
    final answers = widget.answers;
    final biz = answers.businessName ?? 'Bisnismu';
    late final List<Widget> chat;
    if (answers.isCS) {
      chat = [
        const ChatBubble(
            text: 'Halo, jam buka toko sampai jam berapa?', maxWidth: 270),
        ChatBubble(
          text:
              'Halo kak! Toko kami buka sampai jam 9 malam ya 😊 Ada yang bisa dibantu lagi?',
          outgoing: true,
          maxWidth: 290,
        ),
      ];
    } else if (answers.isCommunity) {
      chat = [
        _announce('Seseorang bergabung ke komunitas'),
        const ChatBubble(
            text:
                'Selamat datang di Komunitas kami! Pastikan baca peraturan di deskripsi dan mentaatinya ya! Selamat menikmati!',
            outgoing: true,
            maxWidth: 300),
      ];
    } else {
      chat = [
        const ChatBubble(
            text: 'Nanti ingetin aku jam 5 sore buat beli garam ya!',
            maxWidth: 280),
        const ChatBubble(
            text: 'Baik, reminder telah ditambahkan untuk jam 5 sore.',
            outgoing: true,
            maxWidth: 290),
      ];
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Bot kamu siap! 👇', style: h1(context).copyWith(fontSize: 30)),
        const SizedBox(height: 8),
        Text('Ini persona yang sudah kami siapkan untukmu.',
            style: sub(context).copyWith(fontSize: 15)),
        const SizedBox(height: 24),
        if (answers.isCS)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              const Mascot(size: 30, blue: false),
              const SizedBox(width: 8),
              Text('Bot $biz',
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700, color: Palette.greenDark)),
            ]),
          ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: const Color(0xFFEFF6EC),
              borderRadius: BorderRadius.circular(24)),
          child: Column(children: [
            for (var i = 0; i < chat.length; i++)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 400 + i * 450),
                curve:
                    Interval(i * .5 / (1 + i * 1.1), 1, curve: Curves.easeOut),
                builder: (_, v, c) => Opacity(
                    opacity: v,
                    child: Transform.translate(
                        offset: Offset(0, 10 * (1 - v)), child: c)),
                child: Padding(
                    padding: const EdgeInsets.only(bottom: 10), child: chat[i]),
              ),
            const Align(alignment: Alignment.centerRight, child: AiTag()),
          ]),
        ),
        if (answers.isCS && answers.volumeIndex != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: Palette.ink, borderRadius: BorderRadius.circular(22)),
            child: Row(children: [
              const Text('⏱️', style: TextStyle(fontSize: 30)),
              const SizedBox(width: 14),
              Expanded(
                child: Text.rich(
                    TextSpan(children: [
                      const TextSpan(
                          text:
                              'Berdasarkan jawabanmu, bot ini berpotensi menghemat '),
                      TextSpan(
                          text: answers.savedTimeLabel,
                          style: const TextStyle(
                              color: Palette.green,
                              fontWeight: FontWeight.w800)),
                      const TextSpan(text: ' waktu balas chat manual.'),
                    ]),
                    style: GoogleFonts.plusJakartaSans(
                        color: Colors.white, fontSize: 14.5, height: 1.4)),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 18),
        _SocialProofCard(),
        const SizedBox(height: 28),
        PrimaryButton(
            label: 'Hubungkan ke WhatsApp',
            onTap: widget.onNext,
            icon: Icons.arrow_forward_rounded),
      ]),
    );
  }

  Widget _announce(String t) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
              color: const Color(0xFFFFF3C4),
              borderRadius: BorderRadius.circular(12)),
          child: Text(t,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5, fontWeight: FontWeight.w600)),
        ),
      );
}

class _SocialProofCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Palette.green.withOpacity(.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Palette.green.withOpacity(.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: Palette.green.withOpacity(.2), shape: BoxShape.circle),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: Palette.greenDark, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bot siap dalam hitungan menit',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Palette.greenDark)),
                  const SizedBox(height: 3),
                  Text(
                      'Tidak perlu server, tidak perlu coding — cukup HP dan koneksi internet.',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          height: 1.4,
                          color: Palette.ink.withOpacity(.7))),
                ],
              ),
            ),
          ],
        ),
      );
}
class _PersonaLoading extends StatelessWidget {
  const _PersonaLoading({required this.stage});
  final int stage;

  @override
  Widget build(BuildContext context) {
    const lines = ['Meracik persona bot-mu…', 'Menyesuaikan gaya bicara…'];
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Mascot(size: 82),
        const SizedBox(height: 24),
        const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
                strokeWidth: 3, color: Palette.greenDark)),
        const SizedBox(height: 18),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(lines[stage],
              key: ValueKey(stage),
              textAlign: TextAlign.center,
              style: h1(context).copyWith(fontSize: 24)),
        ),
        const SizedBox(height: 8),
        Text('Sebentar lagi hasil khususmu siap.',
            style: sub(context).copyWith(fontSize: 14)),
      ]),
    );
  }
}
