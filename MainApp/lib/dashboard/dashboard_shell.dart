import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../onboarding/common.dart';
import 'chats_tab.dart';
import 'dash_state.dart';
import 'dash_widgets.dart';
import 'home_tab.dart';
import 'studio_tab.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key, required this.state});
  final DashState state;
  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int tab = 0;
  void go(int i) {
    if (i == 1) widget.state.showChatLogs();
    if (i != tab) setState(() => tab = i);
  }

  void openConsole() {
    widget.state.showConsole();
    if (tab != 1) setState(() => tab = 1);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final st = widget.state;
    final pages = [
      HomeTab(st: st, goTab: go),
      ChatsTab(st: st),
      StudioTab(st: st)
    ];
    return MediaQuery(
      // Jaga layout tetap stabil di ukuran font sistem yang ekstrem.
      data: mq.copyWith(
          textScaler:
              mq.textScaler.clamp(minScaleFactor: .85, maxScaleFactor: 1.15)),
      child: PopScope(
        canPop: tab == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) go(0);
        },
        child: Scaffold(
          extendBody: true,
          body: OnbBackground(
            child: SafeArea(
              bottom: false,
              child: Stack(children: [
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOutCubic,
                    transitionBuilder: (c, a) => FadeTransition(
                        opacity: a,
                        child: SlideTransition(
                            position: Tween(
                                    begin: const Offset(0, .02),
                                    end: Offset.zero)
                                .animate(a),
                            child: c)),
                    child: KeyedSubtree(key: ValueKey(tab), child: pages[tab]),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 14 + mq.padding.bottom,
                  child: ListenableBuilder(
                      listenable: st,
                      builder: (_, __) => _NavBar(
                          index: tab, badge: st.needsYouCount, onTap: go)),
                ),
                if (tab == 1)
                  Positioned(
                    right: 27,
                    bottom: 14 + mq.padding.bottom + 74 + 10,
                    child: Semantics(
                      button: true,
                      label: tab == 1 && st.consoleMode
                          ? 'Kembali ke log chat'
                          : 'Buka console bot',
                      child: Tooltip(
                        message: tab == 1 && st.consoleMode
                            ? 'Kembali ke log chat'
                            : 'Buka console bot',
                        child: Material(
                          color: Palette.ink,
                          elevation: 8,
                          shadowColor: Colors.black26,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              if (tab == 1 && st.consoleMode) {
                                st.showChatLogs();
                              } else {
                                openConsole();
                              }
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: SizedBox(
                              width: 56,
                              height: 56,
                              child: Center(
                                child: Text('>_',
                                    style: tStyle(19,
                                        w: FontWeight.w800,
                                        color: Palette.green)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar(
      {required this.index, required this.badge, required this.onTap});
  final int index, badge;
  final ValueChanged<int> onTap;
  static const items = [
    (Icons.grid_view_rounded, 'Beranda'),
    (Icons.forum_rounded, 'Percakapan'),
    (Icons.tune_rounded, 'Studio')
  ];
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 74,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: 64,
              decoration: BoxDecoration(
                color: Palette.ink,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(.25),
                      blurRadius: 24,
                      offset: const Offset(0, 10))
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeOutBack,
                    alignment: Alignment(index - 1.0, 0),
                    child: FractionallySizedBox(
                      widthFactor: 1 / 3,
                      heightFactor: 1.0,
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Palette.green,
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(children: [
                    for (var i = 0; i < items.length; i++)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onTap(i);
                          },
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Stack(clipBehavior: Clip.none, children: [
                                  Icon(items[i].$1,
                                      size: 23,
                                      color: i == index
                                          ? Palette.ink
                                          : Colors.white70),
                                  if (i == 1 && badge > 0)
                                    Positioned(
                                        right: -8,
                                        top: -5,
                                        child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                                color: const Color(0xFFEB5A3C),
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                            child: Text('$badge',
                                                style: tStyle(10,
                                                    w: FontWeight.w800,
                                                    color: Colors.white)))),
                                ]),
                                const SizedBox(height: 3),
                                Text(items[i].$2,
                                    maxLines: 1,
                                    style: tStyle(10.5,
                                        w: FontWeight.w700,
                                        color: i == index
                                            ? Palette.ink
                                            : Colors.white70)),
                              ]),
                        ),
                      ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      );
}
