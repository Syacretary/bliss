import 'dart:async';

import 'package:flutter/material.dart' hide Step;
import 'package:flutter/services.dart';

import 'common.dart';
import 'models.dart';
import 'screens_intro.dart';
import 'screens_quiz.dart';
import 'screens_setup.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow(
      {super.key,
      required this.onFinished,
      required this.dependencies,
      this.initialDraft,
      this.onStepChanged});
  final void Function(OnboardingResult result) onFinished;
  final OnboardingDependencies dependencies;
  final OnboardingDraft? initialDraft;
  final ValueChanged<Step>? onStepChanged;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  late final Answers answers = widget.initialDraft?.answers.copy() ?? Answers();
  late final WhatsAppConnector connector = widget.dependencies.connector;
  late Step step = widget.initialDraft?.step ?? Step.intro1;
  bool forward = true;
  bool completing = false;
  bool advancing = false;
  int _advanceGeneration = 0;
  final Set<int> exploredUseCases = {0};

  @override
  void initState() {
    super.initState();
    if (!steps.contains(step)) {
      // A draft can outlive a conditional branch (for example, the user changed
      // purpose after a draft was saved). Resume at the next valid step instead
      // of leaving the user on a screen that has no place in the active flow.
      step = steps.firstWhere(
        (candidate) => candidate.index > step.index,
        orElse: () => steps.last,
      );
    }
  }

  /// Daftar langkah dinamis mengikuti jawaban (pertanyaan kondisional).
  List<Step> get steps => [
        Step.intro1,
        Step.intro2,
        Step.intro3,
        Step.qPurpose,
        if (answers.isCS || answers.isCommunity) Step.qVolume,
        Step.qTone,
        if (answers.isCS) Step.qBusiness,
        Step.qProvider,
        Step.preview,
        Step.connectChoice,
        Step.overlayPerm,
        Step.pairing,
        Step.batteryPerm,
        Step.notifPerm,
        Step.success,
      ];

  Future<void> next() async {
    if (advancing || completing) return;
    final s = steps;
    final i = s.indexOf(step);
    if (i < 0 || i >= s.length - 1) return;
    HapticFeedback.selectionClick();
    advancing = true;
    final generation = ++_advanceGeneration;
    if (step == Step.notifPerm) {
      setState(() {
        completing = true;
        forward = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 520));
      if (!mounted || generation != _advanceGeneration) return;
      setState(() {
        completing = false;
        step = Step.success;
        advancing = false;
      });
      unawaited(widget.dependencies.progressStore.clear());
      widget.onStepChanged?.call(Step.success);
      return;
    }
    setState(() {
      forward = true;
      step = s[i + 1];
    });
    _checkpoint();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (mounted && generation == _advanceGeneration) {
      setState(() => advancing = false);
    }
  }

  bool back() {
    final s = steps;
    final i = s.indexOf(step);
    // Setelah pairing berhasil, jangan kembali ke tahap koneksi.
    if (i <= 0 ||
        step == Step.pairing ||
        step == Step.batteryPerm ||
        step == Step.success) return false;
    _advanceGeneration++;
    advancing = false;
    completing = false;
    setState(() {
      forward = false;
      step = s[i - 1];
    });
    _checkpoint();
    return true;
  }

  void _checkpoint() {
    unawaited(widget.dependencies.progressStore.save(
      OnboardingDraft(step: step, answers: answers.copy()),
    ));
    widget.onStepChanged?.call(step);
  }

  List<double> get fills {
    final s = steps;
    final cur = s.indexOf(step);
    final total = s.length - 1;
    final progress = completing ? 1.0 : cur / total;
    return List<double>.generate(
        4, (segment) => ((progress * 4) - segment).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !back()) SystemNavigator.pop();
      },
      child: Scaffold(
        body: OnbBackground(
          child: SafeArea(
            child: Column(children: [
              if (step != Step.success)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: SegmentedProgress(fills: fills, completed: completing),
                ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragEnd: step == Step.intro2 ||
                          step == Step.pairing ||
                          step == Step.batteryPerm ||
                          step == Step.success
                      ? null
                      : (details) {
                          final velocity = details.primaryVelocity ?? 0;
                          if (velocity > 320) back();
                        },
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    // Keep only the entering step in the render tree. The
                    // default layout stacks outgoing and incoming full-screen
                    // pages, which produced doubled text/cards during motion.
                    layoutBuilder: (currentChild, _) =>
                        currentChild ?? const SizedBox.shrink(),
                    transitionBuilder: (child, anim) {
                      final dir = forward ? .10 : -.10;
                      final offset =
                          Tween<Offset>(begin: Offset(dir, 0), end: Offset.zero)
                              .animate(anim);
                      return SlideTransition(position: offset, child: child);
                    },
                    child:
                        KeyedSubtree(key: ValueKey(step), child: _buildStep()),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (step) {
      case Step.intro1:
        return Intro1(onNext: next);
      case Step.intro2:
        return Intro2(
          onNext: next,
          visited: exploredUseCases,
          onViewed: (index) {
            if (exploredUseCases.add(index)) setState(() {});
          },
        );
      case Step.intro3:
        return Intro3(onNext: next);
      case Step.qPurpose:
        return QPurpose(answers: answers, onNext: next);
      case Step.qVolume:
        return QVolume(answers: answers, onNext: next);
      case Step.qTone:
        return QTone(answers: answers, onNext: next);
      case Step.qBusiness:
        return QBusiness(answers: answers, onNext: next);
      case Step.qProvider:
        return QProvider(answers: answers, onNext: next);
      case Step.preview:
        return PreviewScreen(answers: answers, onNext: next);
      case Step.connectChoice:
        return ConnectChoice(answers: answers, onNext: next);
      case Step.overlayPerm:
        return OverlayPermission(onNext: next);
      case Step.pairing:
        return PairingScreen(
            answers: answers, connector: connector, onNext: next);
      case Step.batteryPerm:
        return BatteryPermission(onNext: next);
      case Step.notifPerm:
        return NotificationPermission(onNext: next);
      case Step.success:
        return SuccessScreen(
            connector: connector,
            onDone: () => widget.onFinished(OnboardingResult(
                answers: answers.copy(), completedAt: DateTime.now())));
    }
  }
}
