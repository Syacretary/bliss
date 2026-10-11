import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'dashboard/dash_state.dart';
import 'dashboard/dashboard_repository.dart';
import 'dashboard/dashboard_shell.dart';
import 'onboarding/android_whatsapp_connector.dart';
import 'onboarding/common.dart';
import 'onboarding/models.dart';
import 'onboarding/onboarding_flow.dart';
import 'onboarding/onboarding_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
  ));
  runApp(const BlissApp());
}

class BlissApp extends StatelessWidget {
  const BlissApp({super.key, this.connector});

  /// Optional connector injection keeps previews and tests independent from
  /// the Android process bridge.
  final WhatsAppConnector? connector;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Bliss',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Palette.green),
          textTheme: GoogleFonts.plusJakartaSansTextTheme(),
        ),
        home: _AppRoot(connector: connector),
      );
}

/// App composition root: the production onboarding owns the real Android
/// connector, then hands its completed profile to the dashboard.
class _AppRoot extends StatefulWidget {
  const _AppRoot({this.connector});

  final WhatsAppConnector? connector;

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  final _store = SharedPreferencesOnboardingStore();
  late final WhatsAppConnector _connector = widget.connector ??
      (defaultTargetPlatform == TargetPlatform.android
          ? AndroidWhatsAppConnector()
          : FakeConnector());
  late final Future<void> _restore = _restoreApp();

  OnboardingDraft? _draft;
  DashState? _dashboard;
  String? _linkedPhone;
  bool _ready = false;
  Object? _restoreError;

  Future<void> _restoreApp() async {
    try {
      final savedAnswers = await _store.readCompletedAnswers();
      if (savedAnswers != null) {
        _linkedPhone = await _store.readLinkedPhone();
        _dashboard = _makeDashboard(savedAnswers, linkedPhone: _linkedPhone);
        unawaited(_dashboard!.refresh());
      } else {
        _draft = await _store.readDraft();
      }
    } catch (error) {
      // Storage trouble should not strand a new user on a loading screen.
      _restoreError = error;
    } finally {
      _ready = true;
    }
  }

  DashState _makeDashboard(Answers answers, {String? linkedPhone}) =>
      DashState.fromAnswers(
        answers,
        linkedPhone: linkedPhone,
        repository: _connector is DashboardRepository
            ? _connector as DashboardRepository
            : null,
      );

  Future<void> _finishOnboarding(OnboardingResult result) async {
    _linkedPhone = _connector.botNumber;
    Object? saveError;
    try {
      await _store.markCompleted(result.answers, linkedPhone: _linkedPhone);
    } catch (error) {
      saveError = error;
    }
    if (!mounted) return;
    setState(() => _dashboard = _makeDashboard(
          result.answers,
          linkedPhone: _linkedPhone,
        ));
    unawaited(_dashboard!.refresh());
    if (saveError != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Dashboard terbuka, tetapi status onboarding belum tersimpan.'),
        ));
      });
    }
  }

  void _retryRestore() {
    setState(() {
      _ready = false;
      _restoreError = null;
    });
    _restoreApp().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _dashboard?.dispose();
    if (widget.connector == null) {
      final connector = _connector;
      if (connector is AndroidWhatsAppConnector) connector.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
        future: _restore,
        builder: (context, snapshot) {
          if (!_ready) {
            return const Scaffold(
              body: OnbBackground(
                child: Center(
                  child: CircularProgressIndicator(color: Palette.greenDark),
                ),
              ),
            );
          }
          if (_restoreError != null && _dashboard == null) {
            return Scaffold(
              body: OnbBackground(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_rounded,
                            size: 42, color: Palette.greenDark),
                        const SizedBox(height: 16),
                        Text('Belum bisa membuka Bliss',
                            style: h1(context).copyWith(fontSize: 23),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        Text('Coba lagi untuk memuat data aplikasi.',
                            style: sub(context), textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        FilledButton(
                            onPressed: _retryRestore,
                            child: const Text('Coba lagi')),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 360),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (current, _) => current ?? const SizedBox.shrink(),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, .025),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: _dashboard == null
                ? OnboardingFlow(
                    key: const ValueKey('onboarding'),
                    dependencies: OnboardingDependencies(
                      connector: _connector,
                      progressStore: _store,
                    ),
                    initialDraft: _draft,
                    onFinished: (result) =>
                        unawaited(_finishOnboarding(result)),
                  )
                : DashboardShell(
                    key: const ValueKey('dashboard'), state: _dashboard!),
          );
        },
      );
}
