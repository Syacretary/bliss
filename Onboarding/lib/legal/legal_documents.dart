import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../onboarding/common.dart';

enum BlissLegalDocument { terms, privacy }

const _legalVersion = '2026-10-11-v1';
const _legalAcceptanceKey = 'bliss.legal.accepted_version';

TextStyle _legalStyle(double size,
        {FontWeight w = FontWeight.w600,
        Color color = Palette.ink,
        double? height}) =>
    GoogleFonts.plusJakartaSans(
        fontSize: size, fontWeight: w, color: color, height: height);

/// Opens the concise, just-in-time disclosure before the first WhatsApp link.
Future<bool> requestLegalConsent(BuildContext context) async {
  final preferences = await SharedPreferences.getInstance();
  if (preferences.getString(_legalAcceptanceKey) == _legalVersion) return true;
  if (!context.mounted) return false;

  var checked = false;
  final accepted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Palette.bgTop,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          12,
          22,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                const Icon(Icons.info_outline_rounded,
                    color: Palette.greenDark, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Sebelum menautkan WhatsApp',
                      style: _legalStyle(20, w: FontWeight.w800)),
                ),
              ]),
              const SizedBox(height: 12),
              _NoticeRow(
                icon: Icons.link_off_rounded,
                text:
                    'Bliss bukan API resmi atau afiliasi WhatsApp/Meta. Koneksi memakai Baileys dan dapat berubah atau dibatasi oleh WhatsApp.',
              ),
              const SizedBox(height: 8),
              _NoticeRow(
                icon: Icons.phone_android_rounded,
                text:
                    'Data bot disimpan di perangkat. Jika pemrosesan AI eksternal Anda aktif, konteks pesan dikirim ke provider AI yang dipilih.',
              ),
              const SizedBox(height: 8),
              _NoticeRow(
                icon: Icons.tune_rounded,
                text:
                    'Anda tetap mengendalikan akun dan penggunaan bot. Baca dokumen lengkap kapan saja sebelum memutuskan.',
              ),
              const SizedBox(height: 6),
              Wrap(spacing: 6, children: [
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LegalDocumentPage(
                          document: BlissLegalDocument.terms),
                    ),
                  ),
                  child: const Text('Baca Ketentuan Layanan'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LegalDocumentPage(
                          document: BlissLegalDocument.privacy),
                    ),
                  ),
                  child: const Text('Baca Kebijakan Privasi'),
                ),
              ]),
              CheckboxListTile.adaptive(
                value: checked,
                onChanged: (value) =>
                    setSheetState(() => checked = value ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: Palette.greenDark,
                title: Text(
                  'Saya memahami ringkasan di atas dan menyetujui Ketentuan Layanan serta telah diberi akses ke Kebijakan Privasi.',
                  style: _legalStyle(12.5, w: FontWeight.w600, height: 1.35),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: checked
                      ? () {
                          HapticFeedback.selectionClick();
                          Navigator.of(context).pop(true);
                        }
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Palette.ink,
                    foregroundColor: Palette.green,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text('Lanjutkan ke penghubungan'),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Belum, kembali'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (accepted != true) return false;
  await preferences.setString(_legalAcceptanceKey, _legalVersion);
  return true;
}

class LegalDocumentPage extends StatelessWidget {
  const LegalDocumentPage({super.key, required this.document});
  final BlissLegalDocument document;

  String get _asset => document == BlissLegalDocument.terms
      ? 'assets/legal/terms.md'
      : 'assets/legal/privacy.md';

  String get _title => document == BlissLegalDocument.terms
      ? 'Ketentuan Layanan'
      : 'Kebijakan Privasi';

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Palette.bgTop,
        appBar: AppBar(
          backgroundColor: Palette.bgTop,
          title: Text(_title, style: _legalStyle(18, w: FontWeight.w800)),
        ),
        body: FutureBuilder<String>(
          future: rootBundle.loadString(_asset),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Dokumen belum dapat dimuat. Coba lagi nanti.',
                      style: _legalStyle(14), textAlign: TextAlign.center),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(
                  child: CircularProgressIndicator(color: Palette.greenDark));
            }
            return SelectionArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                children: _documentBlocks(snapshot.data!),
              ),
            );
          },
        ),
      );
}

List<Widget> _documentBlocks(String markdown) {
  final blocks = <Widget>[];
  for (final raw in markdown.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) {
      blocks.add(const SizedBox(height: 8));
      continue;
    }
    if (line.startsWith('|')) {
      if (RegExp(r'^[|:\-\s]+$').hasMatch(line)) continue;
      final cells = line
          .split('|')
          .map((cell) => cell.trim())
          .where((cell) => cell.isNotEmpty)
          .toList();
      blocks.add(Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Text(
          '•  ${cells.map(_plainMarkdown).join(' — ')}',
          style: _legalStyle(13, color: Colors.black87, height: 1.5),
        ),
      ));
      continue;
    }
    final heading = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(line);
    if (heading != null) {
      final level = heading.group(1)!.length;
      blocks.add(Padding(
        padding: EdgeInsets.only(top: level == 1 ? 12 : 8, bottom: 4),
        child: Text(_plainMarkdown(heading.group(2)!),
            style: _legalStyle(
                level == 1
                    ? 21
                    : level == 2
                        ? 16
                        : 14,
                w: FontWeight.w800)),
      ));
      continue;
    }
    final bullet = line.startsWith('- ');
    blocks.add(Padding(
      padding: EdgeInsets.only(left: bullet ? 4 : 0, bottom: 5),
      child: Text(
        '${bullet ? '•  ' : ''}${_plainMarkdown(bullet ? line.substring(2) : line)}',
        style: _legalStyle(13, color: Colors.black87, height: 1.5),
      ),
    ));
  }
  return blocks;
}

String _plainMarkdown(String text) => text
    .replaceAllMapped(RegExp(r'\*\*(.*?)\*\*'), (match) => match[1]!)
    .replaceAllMapped(RegExp(r'\*(.*?)\*'), (match) => match[1]!)
    .replaceAllMapped(RegExp(r'`(.*?)`'), (match) => match[1]!)
    .replaceAllMapped(RegExp(r'\[(.*?)\]\((.*?)\)'), (match) => match[1]!);

class _NoticeRow extends StatelessWidget {
  const _NoticeRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.75),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 19, color: Palette.greenDark),
          const SizedBox(width: 9),
          Expanded(
            child: Text(text,
                style: _legalStyle(12.5, color: Colors.black87, height: 1.4)),
          ),
        ]),
      );
}

class LegalLinks extends StatelessWidget {
  const LegalLinks({super.key});

  @override
  Widget build(BuildContext context) => Column(children: [
        _LegalLinkTile(
          icon: Icons.description_outlined,
          title: 'Ketentuan Layanan',
          subtitle: 'Status koneksi, risiko, dan tanggung jawab penggunaan',
          document: BlissLegalDocument.terms,
        ),
        _LegalLinkTile(
          icon: Icons.privacy_tip_outlined,
          title: 'Kebijakan Privasi',
          subtitle: 'Data lokal, pemrosesan AI, dan pilihan privasi Anda',
          document: BlissLegalDocument.privacy,
        ),
      ]);
}

class _LegalLinkTile extends StatelessWidget {
  const _LegalLinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.document,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final BlissLegalDocument document;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        leading: Icon(icon, color: Palette.greenDark),
        title: Text(title, style: _legalStyle(14, w: FontWeight.w700)),
        subtitle:
            Text(subtitle, style: _legalStyle(11.5, color: Colors.black54)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => LegalDocumentPage(document: document),
        )),
      );
}
