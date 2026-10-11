import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../onboarding/common.dart';
import '../legal/legal_documents.dart';
import 'dash_state.dart';
import 'dash_widgets.dart';
import 'local_knowledge_importer.dart';

class StudioTab extends StatelessWidget {
  const StudioTab({super.key, required this.st});
  final DashState st;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) => ListView(
        key: const PageStorageKey('studio'),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        children: [
          Text('Studio Bot', style: tStyle(30, w: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
              'Atur gaya, jadwal, plugin, perintah kustom, dan pengetahuan bot.',
              style: sub(context).copyWith(fontSize: 14.5)),
          const SizedBox(height: 12),
          _StudioRuntimeNotice(st: st),
          const SizedBox(height: 18),
          _Preview(st: st),
          const SectionTitle('Gaya bicara'),
          _Tones(st: st),
          const SectionTitle('Jadwal aktif'),
          _Schedule(st: st),
          const SectionTitle('Otak AI & API Key'),
          _Providers(st: st),
          SectionTitle('Plugin & Mod Bot',
              action: '+ Plugin Store',
              onAction: () => _showPluginStoreSheet(context, st)),
          _PluginsSection(st: st),
          SectionTitle('Perintah Kustom',
              action: '+ Tambah',
              onAction: () => _showAddCommandSheet(context, st)),
          _CustomCommandsSection(st: st),
          SectionTitle('Pengetahuan bot',
              action: '+ Tambah',
              onAction: () => _showAddKnowledgeSheet(context, st)),
          _KnowledgeList(st: st),
          const SectionTitle('Tentang & kebijakan'),
          const LegalLinks(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _StudioRuntimeNotice extends StatelessWidget {
  const _StudioRuntimeNotice({required this.st});
  final DashState st;

  @override
  Widget build(BuildContext context) {
    if (st.dashboardLoading) {
      return DCard(
        radius: 18,
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Memuat data bot dari perangkat…',
                  style: tStyle(13, w: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 10),
          const LinearProgressIndicator(minHeight: 3),
        ]),
      );
    }
    if (st.dashboardError != null) {
      return DCard(
        radius: 18,
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Data runtime belum tersedia',
              style: tStyle(13, w: FontWeight.w800, color: Palette.greenDark)),
          const SizedBox(height: 4),
          Text(st.dashboardError!,
              style: tStyle(12, color: Colors.black54, height: 1.3)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: st.refresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba lagi'),
            ),
          ),
        ]),
      );
    }
    if (!st.runtimeConfigurationLoaded) {
      return DCard(
        radius: 18,
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded, color: Palette.greenDark),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Pengaturan lokal akan tersinkron saat runtime Android tersedia.',
              style: tStyle(12, color: Colors.black54, height: 1.3),
            ),
          ),
        ]),
      );
    }
    return const SizedBox.shrink();
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.st});
  final DashState st;
  @override
  Widget build(BuildContext context) {
    final r = st.reply(0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFFDDEFD7),
          borderRadius: BorderRadius.circular(30)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Mascot(size: 34, blue: false),
          const SizedBox(width: 10),
          Expanded(
              child: Text('Pratinjau langsung',
                  style: tStyle(14,
                      w: FontWeight.w800, color: Palette.greenDark))),
          PulseDot(color: Palette.greenDark, active: st.botOn),
        ]),
        const SizedBox(height: 14),
        const ChatBubble(
            text: 'Halo, jam buka toko sampai jam berapa?', maxWidth: 260),
        const SizedBox(height: 10),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topRight,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: ChatBubble(
                key: ValueKey(r), text: r, outgoing: true, maxWidth: 300),
          ),
        ),
        const SizedBox(height: 8),
        const Align(alignment: Alignment.centerRight, child: AiTag()),
      ]),
    );
  }
}

class _Tones extends StatelessWidget {
  const _Tones({required this.st});
  final DashState st;
  static const toneIcons = [
    Icons.business_center_outlined,
    Icons.sentiment_satisfied_alt_rounded,
    Icons.bolt_outlined,
    Icons.edit_note_rounded
  ];
  static const names = ['Formal', 'Ramah', 'To the point', 'Kustom'];

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  if (i == 3) {
                    _showCustomToneDialog(context, st);
                  } else {
                    st.setTone(i);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                  decoration: BoxDecoration(
                    color: st.toneIndex == i
                        ? Palette.ink
                        : Colors.white.withOpacity(.8),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(children: [
                    AnimatedScale(
                      scale: st.toneIndex == i ? 1.15 : 1,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutBack,
                      child: Icon(toneIcons[i],
                          size: 32,
                          color: st.toneIndex == i
                              ? Palette.green
                              : Palette.greenDark),
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(names[i],
                            style: tStyle(12.5,
                                w: FontWeight.w800,
                                color: st.toneIndex == i
                                    ? Colors.white
                                    : Palette.ink))),
                  ]),
                ),
              ),
            ),
          ],
        ]),
        if (st.toneIndex == 3 &&
            st.customTone != null &&
            st.customTone!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Palette.green.withOpacity(.2),
                borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              const Icon(Icons.psychology_outlined,
                  size: 20, color: Palette.greenDark),
              const SizedBox(width: 10),
              Expanded(
                  child: Text('Gaya Kustom: "${st.customTone}"',
                      style: tStyle(13,
                          w: FontWeight.w700, color: Palette.greenDark))),
              IconButton(
                  icon: const Icon(Icons.edit_rounded,
                      size: 18, color: Palette.greenDark),
                  onPressed: () => _showCustomToneDialog(context, st)),
            ]),
          ),
        ],
      ]);
}

void _showCustomToneDialog(BuildContext context, DashState st) {
  final ctrl = TextEditingController(text: st.customTone ?? '');
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Deskripsi Gaya Bicara Kustom',
                style: tStyle(20, w: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('Deskripsikan sifat dan gaya bicara bot sesuai keinginanmu.',
                style: sub(ctx).copyWith(fontSize: 14)),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              minLines: 3,
              maxLines: 4,
              autofocus: true,
              decoration: InputDecoration(
                hintText:
                    'Contoh: Sopan tapi santai, gunakan emotikon manis, dan sapa pelanggan dengan "Kakak Budi"…',
                filled: true,
                fillColor: Palette.bgTop,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Simpan Gaya Kustom',
              onTap: () {
                if (ctrl.text.trim().isNotEmpty) {
                  st.setCustomTone(ctrl.text.trim());
                }
                Navigator.pop(ctx);
              },
            ),
          ]),
    ),
  );
}

SliderThemeData _sliderTheme(BuildContext c) => SliderTheme.of(c).copyWith(
      trackHeight: 10,
      activeTrackColor: Palette.green,
      inactiveTrackColor: Palette.greenSoft.withOpacity(.6),
      thumbColor: Palette.ink,
      overlayColor: Palette.green.withOpacity(.2),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
      trackShape: const RoundedRectSliderTrackShape(),
      rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 12),
    );

class _Schedule extends StatelessWidget {
  const _Schedule({required this.st});
  final DashState st;
  static const letters = ['S', 'S', 'R', 'K', 'J', 'S', 'M'];
  @override
  Widget build(BuildContext context) {
    final h = st.hourly;
    final mx = h.fold<double>(0.0, (a, b) => a > b ? a : b.toDouble());
    final safeMax = mx <= 0 ? 1.0 : mx;
    final r = st.hours;
    String fmt(double v) => '${v.round().toString().padLeft(2, '0')}.00';
    return DCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('${fmt(r.start)} – ${fmt(r.end)}',
                style: tStyle(22, w: FontWeight.w800)),
          )),
          const SizedBox(width: 8),
          Text('${(r.end - r.start).round()} jam',
              maxLines: 1,
              style: tStyle(14, color: Palette.greenText, w: FontWeight.w700)),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          height: 56,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < 24; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 8 + 48 * h[i] / safeMax,
                    decoration: BoxDecoration(
                        color: (i >= r.start && i < r.end)
                            ? Palette.green
                            : Colors.black12,
                        borderRadius: BorderRadius.circular(3)),
                  ),
                ),
              ),
          ]),
        ),
        SliderTheme(
          data: _sliderTheme(context),
          child: RangeSlider(
              values: r,
              min: 0,
              max: 24,
              divisions: 24,
              onChanged: (v) {
                if (v.end - v.start >= 1) st.setHours(v);
              }),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: st.busyCovered
                  ? Palette.green.withOpacity(.2)
                  : const Color(0xFFFFE9D6),
              borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Icon(
                st.busyCovered
                    ? Icons.check_circle_outline_rounded
                    : Icons.warning_amber_rounded,
                color: st.busyCovered
                    ? Palette.greenDark
                    : const Color(0xFFB4452A),
                size: 22),
            const SizedBox(width: 10),
            Expanded(
                child: Text(
                    st.busyCovered
                        ? 'Jadwal mencakup jam paling ramai.'
                        : 'Jam paling ramai (${st.busyStart}.00–${st.busyStart + 2}.00) ada di luar jadwal.',
                    style: tStyle(12.5, w: FontWeight.w600, height: 1.3))),
          ]),
        ),
        const SizedBox(height: 14),
        Row(children: [
          for (var i = 0; i < 7; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  st.toggleDay(i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: st.days.contains(i)
                          ? Palette.ink
                          : Colors.black.withOpacity(.06),
                      borderRadius: BorderRadius.circular(14)),
                  child: Text(letters[i],
                      style: tStyle(13.5,
                          w: FontWeight.w800,
                          color: st.days.contains(i)
                              ? Colors.white
                              : Colors.black38)),
                ),
              ),
            ),
          ],
        ]),
      ]),
    );
  }
}

class _Providers extends StatefulWidget {
  const _Providers({required this.st});
  final DashState st;
  @override
  State<_Providers> createState() => _ProvidersState();
}

class _ProvidersState extends State<_Providers> {
  late final TextEditingController _apiCtrl =
      TextEditingController(text: widget.st.apiKey);
  late final TextEditingController _modelCtrl;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _modelCtrl = TextEditingController(
        text: widget.st.getModelForProvider(widget.st.provider));
  }

  @override
  void dispose() {
    _apiCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  String _getApiKeyUrl(String provider) {
    if (provider.contains('Gemini'))
      return 'https://aistudio.google.com/app/apikey';
    if (provider.contains('OpenAI') || provider.contains('ChatGPT'))
      return 'https://platform.openai.com/api-keys';
    if (provider.contains('Anthropic') || provider.contains('Claude'))
      return 'https://console.anthropic.com/settings/keys';
    if (provider.contains('Deepseek'))
      return 'https://platform.deepseek.com/api_keys';
    if (provider.contains('Groq')) return 'https://console.groq.com/keys';
    return 'https://aistudio.google.com/app/apikey';
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.st;
    final defaultModel = DashState.getDefaultModel(st.provider);
    final customModel = st.getModelForProvider(st.provider);
    if (_modelCtrl.text != customModel) {
      _modelCtrl.value = TextEditingValue(
        text: customModel,
        selection: TextSelection.collapsed(offset: customModel.length),
      );
    }
    final credentialConfigured = st.apiKey.isNotEmpty
        ? st.providerConfigurationSaved
        : st.providerCredentialConfigured;
    return DCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in DashState.providers)
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                st.setProvider(p);
                _apiCtrl.clear();
                _modelCtrl.text = st.getModelForProvider(p);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: st.provider == p
                      ? Palette.green.withOpacity(.35)
                      : Colors.black.withOpacity(.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color:
                          st.provider == p ? Palette.green : Colors.transparent,
                      width: 2),
                ),
                child: Text(p, style: tStyle(13, w: FontWeight.w700)),
              ),
            ),
        ]),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text('API Key Provider (${st.provider})',
                  style: tStyle(14, w: FontWeight.w800),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () async {
                final url = _getApiKeyUrl(st.provider);
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Palette.green.withOpacity(.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Palette.green.withOpacity(.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Get API Key',
                        style: tStyle(11.5,
                            w: FontWeight.w700, color: Palette.greenDark)),
                    const SizedBox(width: 4),
                    Icon(Icons.open_in_new_rounded,
                        size: 13, color: Palette.greenDark),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _apiCtrl,
          obscureText: _obscure,
          onChanged: st.setApiKey,
          decoration: InputDecoration(
            hintText: 'Masukkan API Key ${st.provider}…',
            filled: true,
            fillColor: Palette.bgTop,
            suffixIcon: IconButton(
              icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: Palette.ink),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Icon(
              credentialConfigured
                  ? Icons.check_circle_rounded
                  : Icons.warning_amber_rounded,
              size: 14,
              color: st.apiKey.isNotEmpty
                  ? Palette.greenDark
                  : Colors.orangeAccent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              st.apiKey.isNotEmpty
                  ? (st.providerConfigurationSaved
                      ? 'API key tersimpan terenkripsi di perangkat.'
                      : 'Key belum dikirim ke runtime; simpan pengaturan untuk menerapkannya.')
                  : credentialConfigured
                      ? 'API key provider sudah tersimpan terenkripsi di perangkat.'
                      : 'Masukkan API key, lalu simpan konfigurasi untuk menggunakannya.',
              style: tStyle(11.5,
                  color: credentialConfigured
                      ? Palette.greenDark
                      : Colors.orangeAccent,
                  w: FontWeight.w600),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: st.allowExternalProcessing,
          onChanged: st.setExternalProcessingConsent,
          activeTrackColor: Palette.green,
          title: Text('Izinkan pemrosesan AI eksternal',
              style: tStyle(13, w: FontWeight.w700)),
          subtitle: Text(
            'Isi pesan dikirim ke ${st.provider.split(' / ').last}. Key disimpan terenkripsi di perangkat dan tidak ditampilkan di Console.',
            style: tStyle(11.5, color: Colors.black54, height: 1.35),
          ),
        ),
        if (st.configurationSaveError != null) ...[
          const SizedBox(height: 4),
          Text(st.configurationSaveError!,
              style: tStyle(12,
                  color: const Color(0xFFB4452A), w: FontWeight.w600)),
        ],
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: st.savingBotConfiguration
                ? null
                : () async {
                    await st.saveBotConfiguration();
                    if (!context.mounted) return;
                    if (st.configurationSaveError == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Pengaturan AI tersimpan dan diterapkan ke runtime.')),
                      );
                    }
                  },
            style: FilledButton.styleFrom(
              backgroundColor: Palette.ink,
              foregroundColor: Palette.green,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: st.savingBotConfiguration
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_rounded, size: 18),
            label: Text(
                st.savingBotConfiguration
                    ? 'Menyimpan…'
                    : st.providerConfigurationSaved
                        ? 'Pengaturan AI tersimpan'
                        : 'Simpan pengaturan AI',
                style: tStyle(13, w: FontWeight.w800, color: Palette.green)),
          ),
        ),
        const SizedBox(height: 16),
        Text('Nama Model (${st.provider})',
            style: tStyle(14, w: FontWeight.w800)),
        const SizedBox(height: 6),
        TextField(
          controller: _modelCtrl,
          onChanged: (val) {
            st.setModelForProvider(st.provider, val);
            setState(() {});
          },
          decoration: InputDecoration(
            hintText:
                DashState.defaultProviderModelIds[st.provider] ?? defaultModel,
            hintStyle: tStyle(13.5, color: Colors.black38, w: FontWeight.w500),
            filled: true,
            fillColor: Palette.bgTop,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Icon(
              customModel.isNotEmpty
                  ? Icons.tune_rounded
                  : Icons.auto_awesome_rounded,
              size: 14,
              color: customModel.isNotEmpty ? Palette.greenDark : Palette.mint),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              customModel.isNotEmpty
                  ? 'Model kustom (ID API): ${st.getModelIdForProvider(st.provider)}'
                  : 'Model default: $defaultModel · ID API: ${st.getModelIdForProvider(st.provider)}',
              style: tStyle(11.5,
                  color:
                      customModel.isNotEmpty ? Palette.greenDark : Palette.mint,
                  w: FontWeight.w600),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ── Plugins Section ──
class _PluginsSection extends StatelessWidget {
  const _PluginsSection({required this.st});
  final DashState st;
  @override
  Widget build(BuildContext context) => Column(children: [
        if (st.plugins.isEmpty)
          DCard(
              child: Center(
                  child: Text(
                      'Belum ada plugin terpasang. Buka Plugin Store untuk memilih fitur.',
                      style: tStyle(13.5, color: Colors.black54)))),
        for (var i = 0; i < st.plugins.length; i++) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DCard(
              radius: 22,
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
              child: Column(children: [
                Row(children: [
                  Icon(st.plugins[i].icon, color: Palette.greenDark, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(st.plugins[i].name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tStyle(14.5, w: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(st.plugins[i].description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: tStyle(12,
                                  color: Colors.black54, w: FontWeight.w500)),
                        ]),
                  ),
                ]),
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  IconButton(
                    tooltip: 'Atur plugin',
                    icon: const Icon(Icons.tune_rounded,
                        color: Palette.greenDark),
                    onPressed: () => _showPluginConfigurationSheet(
                        context, st, st.plugins[i],
                        installing: false),
                  ),
                  Switch(
                    value: st.plugins[i].enabled && st.plugins[i].configured,
                    activeColor: Palette.greenDark,
                    activeTrackColor: Palette.green,
                    onChanged: st.plugins[i].configured
                        ? (val) => _savePluginAction(st.togglePlugin(i, val),
                            ScaffoldMessenger.of(context))
                        : null,
                  ),
                  IconButton(
                      icon: const Icon(Icons.close_rounded,
                          size: 18, color: Colors.black38),
                      tooltip: 'Hapus plugin',
                      onPressed: () => _savePluginAction(
                          st.removePlugin(i), ScaffoldMessenger.of(context))),
                ]),
              ]),
            ),
          ),
        ],
      ]);
}

Future<void> _showPluginStoreSheet(BuildContext context, DashState st) async {
  final plugin = await showModalBottomSheet<PluginItem>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * .78),
          child: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Plugin Store', style: tStyle(22, w: FontWeight.w800)),
                const SizedBox(height: 5),
                Text('Plugin resmi Bliss. Atur dulu sebelum diaktifkan.',
                    style: tStyle(13, color: Colors.black54)),
                const SizedBox(height: 16),
                if (st.pluginCatalog.isEmpty)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                          child: Text(
                              'Katalog plugin belum tersedia. Hubungkan runtime lalu coba lagi.'))),
                for (final plugin in st.pluginCatalog)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DCard(
                        radius: 18,
                        padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          Icon(plugin.icon, color: Palette.greenDark, size: 26),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(plugin.name,
                                    style: tStyle(14, w: FontWeight.w800)),
                                const SizedBox(height: 3),
                                Text(plugin.description,
                                    style: tStyle(12, color: Colors.black54),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                                if (plugin.permissions.isNotEmpty) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    'Izin: ${plugin.permissions.map((permission) => permission == 'whatsapp.presence' ? 'status aktivitas WhatsApp' : permission).join(', ')}',
                                    style: tStyle(11,
                                        color: Palette.greenDark,
                                        w: FontWeight.w600),
                                  ),
                                ],
                              ])),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, plugin),
                            child: Text(plugin.installed ? 'Atur' : 'Pilih'),
                          ),
                        ])),
                  ),
              ])),
        ),
      ),
    ),
  );
  if (!context.mounted || plugin == null) return;
  final installed =
      st.plugins.where((item) => item.id == plugin.id).firstOrNull;
  await _showPluginConfigurationSheet(
    context,
    st,
    installed ?? plugin,
    installing: installed == null,
  );
}

Future<void> _showPluginConfigurationSheet(
    BuildContext context, DashState st, PluginItem plugin,
    {required bool installing}) {
  final controllers = <String, TextEditingController>{};
  final booleans = <String, bool>{};
  for (final field in plugin.settingsSchema) {
    final key = field['key']?.toString() ?? '';
    if (key.isEmpty || key == 'configured') continue;
    final current = plugin.settings[key] ?? field['defaultValue'];
    if (field['type'] == 'boolean') {
      booleans[key] = current == true;
    } else {
      controllers[key] = TextEditingController(text: current?.toString() ?? '');
    }
  }
  final messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    22, 20, 22, MediaQuery.of(ctx).viewInsets.bottom + 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(ctx).height * .78),
                  child: SingleChildScrollView(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(
                            installing
                                ? 'Atur ${plugin.name}'
                                : 'Pengaturan ${plugin.name}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: tStyle(20, w: FontWeight.w800)),
                        const SizedBox(height: 5),
                        Text(
                            'Tinjau pengaturan ini. Plugin akan tetap nonaktif sampai kamu menyalakannya.',
                            style: tStyle(12.5, color: Colors.black54)),
                        const SizedBox(height: 14),
                        for (final field in plugin.settingsSchema) ...[
                          if (field['key'] == 'configured')
                            const SizedBox.shrink()
                          else if (field['type'] == 'boolean')
                            Row(children: [
                              Expanded(
                                child: Text(field['label']?.toString() ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: tStyle(13, w: FontWeight.w600)),
                              ),
                              Switch.adaptive(
                                value: booleans[field['key']] ?? false,
                                activeColor: Palette.greenDark,
                                onChanged: (value) => setSheetState(() =>
                                    booleans[field['key'].toString()] = value),
                              ),
                            ])
                          else ...[
                            Text(field['label']?.toString() ?? '',
                                style: tStyle(12.5, w: FontWeight.w700)),
                            const SizedBox(height: 6),
                            TextField(
                                controller: controllers[field['key']],
                                maxLines: field['type'] == 'text' ? 2 : 1,
                                decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Palette.bgTop,
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide.none))),
                            const SizedBox(height: 12),
                          ],
                        ],
                        const SizedBox(height: 8),
                        PrimaryButton(
                            label: installing
                                ? 'Simpan konfigurasi'
                                : 'Simpan perubahan',
                            onTap: () async {
                              final settings = <String, Object?>{
                                ...booleans,
                                for (final entry in controllers.entries)
                                  entry.key: entry.value.text.trim()
                              };
                              Navigator.pop(ctx);
                              try {
                                if (installing) {
                                  await st.installPlugin(plugin, settings);
                                } else {
                                  final index = st.plugins.indexWhere(
                                      (item) => item.id == plugin.id);
                                  if (index >= 0)
                                    await st.configurePlugin(index, settings);
                                }
                              } catch (error) {
                                messenger.showSnackBar(SnackBar(
                                    content: Text(
                                        'Pengaturan plugin gagal disimpan: $error')));
                              }
                            }),
                      ])),
                ),
              ),
            )),
  ).whenComplete(() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
  });
}

void _savePluginAction(Future<void> action, ScaffoldMessengerState messenger) {
  action.catchError((error) {
    messenger.showSnackBar(
        SnackBar(content: Text('Pengaturan plugin gagal disimpan: $error')));
  });
}

// ── Custom Commands Section ──
class _CustomCommandsSection extends StatelessWidget {
  const _CustomCommandsSection({required this.st});
  final DashState st;
  @override
  Widget build(BuildContext context) => Column(children: [
        if (st.customCommands.isEmpty)
          DCard(
              child: Center(
                  child: Text('Belum ada perintah kustom. Ketuk + Tambah.',
                      style: tStyle(13.5, color: Colors.black54)))),
        for (var i = 0; i < st.customCommands.length; i++) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DCard(
              radius: 22,
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
              child: Row(children: [
                const Icon(Icons.terminal_rounded,
                    color: Palette.greenDark, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(st.customCommands[i].trigger,
                            style: tStyle(14.5,
                                w: FontWeight.w800, color: Palette.greenDark)),
                        const SizedBox(height: 2),
                        Text(st.customCommands[i].response,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: tStyle(12,
                                color: Colors.black54, w: FontWeight.w500)),
                      ]),
                ),
                Switch(
                  value: st.customCommands[i].enabled,
                  activeColor: Palette.greenDark,
                  activeTrackColor: Palette.green,
                  onChanged: (val) => st.toggleCustomCommand(i, val),
                ),
                IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 18, color: Colors.black38),
                    onPressed: () => st.removeCustomCommand(i)),
              ]),
            ),
          ),
        ],
      ]);
}

void _showAddCommandSheet(BuildContext context, DashState st) {
  final trigCtrl = TextEditingController(), respCtrl = TextEditingController();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tambah Perintah Kustom',
                style: tStyle(20, w: FontWeight.w800)),
            const SizedBox(height: 14),
            _field(trigCtrl, 'Perintah (misal: !promo atau /bantuan)'),
            const SizedBox(height: 10),
            _field(respCtrl, 'Jawaban bot saat perintah diketik', lines: 3),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Simpan Perintah',
              onTap: () {
                if (trigCtrl.text.trim().isNotEmpty &&
                    respCtrl.text.trim().isNotEmpty) {
                  st.addCustomCommand(
                      trigCtrl.text.trim(), respCtrl.text.trim());
                }
                Navigator.pop(ctx);
              },
            ),
          ]),
    ),
  );
}

// ── Knowledge List ──
class _KnowledgeList extends StatelessWidget {
  const _KnowledgeList({required this.st});
  final DashState st;

  IconData _iconForKind(KnowledgeKind k) {
    switch (k) {
      case KnowledgeKind.document:
        return Icons.description_outlined;
      case KnowledgeKind.image:
        return Icons.image_outlined;
      case KnowledgeKind.text:
        return Icons.notes_outlined;
      case KnowledgeKind.faq:
        return Icons.quiz_outlined;
    }
  }

  String _badgeForKind(KnowledgeKind k) {
    switch (k) {
      case KnowledgeKind.document:
        return 'DOC';
      case KnowledgeKind.image:
        return 'IMG';
      case KnowledgeKind.text:
        return 'TXT';
      case KnowledgeKind.faq:
        return 'FAQ';
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        if (st.knowledgeBase.isEmpty)
          DCard(
              child: Center(
                  child: Text('Belum ada pengetahuan. Ketuk + Tambah.',
                      style: tStyle(13.5, color: Colors.black54)))),
        for (var i = 0; i < st.knowledgeBase.length; i++) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DCard(
              radius: 22,
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
              child: Row(children: [
                Icon(_iconForKind(st.knowledgeBase[i].kind),
                    color: Palette.greenDark, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          SizedBox(
                            width: 44,
                            height: 20,
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color: Palette.greenDark,
                                  borderRadius: BorderRadius.circular(6)),
                              child: Text(
                                  _badgeForKind(st.knowledgeBase[i].kind),
                                  style: tStyle(10,
                                      color: Colors.white, w: FontWeight.w800)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(st.knowledgeBase[i].title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tStyle(14, w: FontWeight.w800))),
                        ]),
                        const SizedBox(height: 3),
                        Text(st.knowledgeBase[i].content,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: tStyle(12,
                                color: Colors.black54, w: FontWeight.w500)),
                        if (st.knowledgeBase[i].fileName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                              '📎 ${st.knowledgeBase[i].fileName} (${st.knowledgeBase[i].fileSize ?? ''})',
                              style: tStyle(11,
                                  color: Palette.greenDark,
                                  w: FontWeight.w700)),
                        ],
                      ]),
                ),
                IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 20, color: Colors.black38),
                    onPressed: () => st.removeKnowledge(i)),
              ]),
            ),
          ),
        ],
      ]);
}

void _showAddKnowledgeSheet(BuildContext context, DashState st) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => _AddKnowledgeDialog(st: st),
  );
}

class _AddKnowledgeDialog extends StatefulWidget {
  const _AddKnowledgeDialog({required this.st});
  final DashState st;
  @override
  State<_AddKnowledgeDialog> createState() => _AddKnowledgeDialogState();
}

class _AddKnowledgeDialogState extends State<_AddKnowledgeDialog> {
  int tab = 0; // 0: FAQ, 1: DOC, 2: IMG, 3: TXT
  final qCtrl = TextEditingController(), aCtrl = TextEditingController();
  final docTitleCtrl = TextEditingController(),
      docDescCtrl = TextEditingController();
  final imgTitleCtrl = TextEditingController(),
      imgDescCtrl = TextEditingController();
  final txtTitleCtrl = TextEditingController(),
      txtContentCtrl = TextEditingController();
  String? selectedFileName;
  String? selectedFileSize;
  String? importStatus;
  String? importError;
  bool importing = false;

  static const categoryIcons = [
    Icons.quiz_outlined,
    Icons.description_outlined,
    Icons.image_outlined,
    Icons.notes_outlined
  ];
  static const categoryColors = [
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFFFF9800),
    Color(0xFF9C27B0)
  ];

  @override
  void dispose() {
    qCtrl.dispose();
    aCtrl.dispose();
    docTitleCtrl.dispose();
    docDescCtrl.dispose();
    imgTitleCtrl.dispose();
    imgDescCtrl.dispose();
    txtTitleCtrl.dispose();
    txtContentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickKnowledgeFile({required bool image}) async {
    setState(() {
      importing = true;
      importError = null;
      importStatus = 'Pilih file dari perangkat…';
    });
    try {
      final file = await LocalKnowledgeImporter.choose(image: image);
      if (!mounted) return;
      if (file == null) {
        setState(() {
          importing = false;
          importStatus = null;
        });
        return;
      }
      final imported = await LocalKnowledgeImporter.extract(
        file,
        image: image,
        onStatus: (status) {
          if (mounted) setState(() => importStatus = status);
        },
      );
      if (!mounted) return;
      setState(() {
        selectedFileName = imported.fileName;
        selectedFileSize = imported.sizeLabel;
        if (image) {
          if (imgTitleCtrl.text.trim().isEmpty) {
            imgTitleCtrl.text =
                imported.fileName.replaceFirst(RegExp(r'\.[^.]+$'), '');
          }
          imgDescCtrl.text = imported.text;
          importStatus =
              'Teks berhasil dibaca di perangkat. Periksa sebelum simpan.';
        } else {
          if (docTitleCtrl.text.trim().isEmpty) {
            docTitleCtrl.text =
                imported.fileName.replaceFirst(RegExp(r'\.[^.]+$'), '');
          }
          docDescCtrl.text = imported.text;
          if (imported.scannedDocument) {
            importStatus = 'PDF scan berhasil dibaca dengan OCR lokal.';
          } else {
            importStatus =
                'Teks berhasil diekstrak di perangkat. Periksa sebelum simpan.';
          }
        }
        importing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        importing = false;
        importStatus = null;
        importError = error is FormatException
            ? error.message
            : 'File tidak dapat dibaca di perangkat ini.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .86),
        child: SingleChildScrollView(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('Tambah Pengetahuan AI',
                      style: tStyle(20, w: FontWeight.w800)),
                  const Spacer(),
                  IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context)),
                ]),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Palette.green.withOpacity(.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lock_outline_rounded,
                          size: 18, color: Palette.greenDark),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'File diproses di perangkat. Hanya teks hasil ekstraksi yang disimpan lokal; teks baru dibagikan ke provider jika izin pemrosesan eksternal diaktifkan.',
                          style: tStyle(11.5,
                              w: FontWeight.w600,
                              color: Palette.greenDark,
                              height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      for (var i = 0; i < 4; i++)
                        GestureDetector(
                          onTap: () => setState(() => tab = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              color: categoryColors[i]
                                  .withOpacity(tab == i ? 1.0 : 0.15),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                  color: tab == i
                                      ? categoryColors[i]
                                      : Colors.transparent,
                                  width: 2),
                              boxShadow: tab == i
                                  ? [
                                      BoxShadow(
                                          color: categoryColors[i]
                                              .withOpacity(0.4),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4))
                                    ]
                                  : [],
                            ),
                            child: Icon(categoryIcons[i],
                                size: 28,
                                color: tab == i
                                    ? Colors.white
                                    : categoryColors[i]),
                          ),
                        ),
                    ]),
                const SizedBox(height: 18),
                if (tab == 0) ...[
                  _field(qCtrl, 'Pertanyaan, misal: Jam buka toko?'),
                  const SizedBox(height: 10),
                  _field(aCtrl, 'Jawaban bot untuk pelanggan', lines: 3),
                ] else if (tab == 1) ...[
                  _field(docTitleCtrl,
                      'Judul Dokumen (misal: Katalog Harga 2026)'),
                  const SizedBox(height: 10),
                  _field(
                      docDescCtrl, 'Teks hasil ekstraksi lokal (dapat diedit)',
                      lines: 5),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: importing
                        ? null
                        : () => _pickKnowledgeFile(image: false),
                    icon: importing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.upload_file_rounded,
                            color: Palette.ink),
                    label: Text(
                        selectedFileName ?? 'Pilih PDF, DOCX, TXT, atau MD',
                        style: tStyle(13, w: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                  ),
                ] else if (tab == 2) ...[
                  _field(imgTitleCtrl,
                      'Judul Gambar (misal: Menu Minuman / Brosur)'),
                  const SizedBox(height: 10),
                  _field(imgDescCtrl, 'Teks hasil OCR lokal (dapat diedit)',
                      lines: 4),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: importing
                        ? null
                        : () => _pickKnowledgeFile(image: true),
                    icon: importing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.add_photo_alternate_rounded,
                            color: Palette.ink),
                    label: Text(
                        selectedFileName ?? 'Pilih File Gambar (JPG, PNG)',
                        style: tStyle(13, w: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                  ),
                ] else ...[
                  _field(
                      txtTitleCtrl, 'Judul Topik (misal: Kebijakan Garansi)'),
                  const SizedBox(height: 10),
                  _field(txtContentCtrl,
                      'Tulis catatan / informasi bebas untuk pengetahuan bot…',
                      lines: 4),
                ],
                if (importStatus != null) ...[
                  const SizedBox(height: 8),
                  Text(importStatus!,
                      style: tStyle(12,
                          w: FontWeight.w600, color: Palette.greenDark)),
                ],
                if (importError != null) ...[
                  const SizedBox(height: 8),
                  Text(importError!,
                      style: tStyle(12,
                          w: FontWeight.w600, color: Colors.red.shade700)),
                ],
                const SizedBox(height: 18),
                PrimaryButton(
                  label: 'Simpan Pengetahuan',
                  enabled: !importing,
                  onTap: () {
                    var saved = false;
                    if (tab == 0 &&
                        qCtrl.text.trim().isNotEmpty &&
                        aCtrl.text.trim().isNotEmpty) {
                      widget.st.addKnowledge(KnowledgeItem(
                          title: qCtrl.text.trim(),
                          content: aCtrl.text.trim(),
                          kind: KnowledgeKind.faq));
                      saved = true;
                    } else if (tab == 1 &&
                        docTitleCtrl.text.trim().isNotEmpty &&
                        docDescCtrl.text.trim().isNotEmpty &&
                        selectedFileName != null) {
                      widget.st.addKnowledge(KnowledgeItem(
                          title: docTitleCtrl.text.trim(),
                          content: docDescCtrl.text.trim(),
                          kind: KnowledgeKind.document,
                          fileName: selectedFileName,
                          fileSize: selectedFileSize));
                      saved = true;
                    } else if (tab == 2 &&
                        imgTitleCtrl.text.trim().isNotEmpty &&
                        imgDescCtrl.text.trim().isNotEmpty &&
                        selectedFileName != null) {
                      widget.st.addKnowledge(KnowledgeItem(
                          title: imgTitleCtrl.text.trim(),
                          content: imgDescCtrl.text.trim(),
                          kind: KnowledgeKind.image,
                          fileName: selectedFileName,
                          fileSize: selectedFileSize));
                      saved = true;
                    } else if (tab == 3 &&
                        txtTitleCtrl.text.trim().isNotEmpty &&
                        txtContentCtrl.text.trim().isNotEmpty) {
                      widget.st.addKnowledge(KnowledgeItem(
                          title: txtTitleCtrl.text.trim(),
                          content: txtContentCtrl.text.trim(),
                          kind: KnowledgeKind.text));
                      saved = true;
                    }
                    if (saved) {
                      Navigator.pop(context);
                    } else {
                      setState(() => importError = tab == 1 || tab == 2
                          ? 'Pilih file dan pastikan teks hasil ekstraksi tersedia.'
                          : 'Lengkapi judul dan isi pengetahuan terlebih dahulu.');
                    }
                  },
                ),
              ]),
        ),
      ),
    );
  }
}

Widget _field(TextEditingController c, String hint, {int lines = 1}) =>
    TextField(
      controller: c,
      minLines: lines,
      maxLines: lines,
      decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: Palette.bgTop,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none)),
    );
