import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../util/dates.dart';
import 'screens/children_screen.dart';
import 'screens/settings_screen.dart';
import 'sheets/feed_sheet.dart';
import 'tabs/history_tab.dart';
import 'tabs/home_tab.dart';
import 'tabs/meds_tab.dart';
import 'tabs/stats_tab.dart';

/// الهيكل العام: شريط علوي بمبدّل الأطفال، أربعة تبويبات، وزر تسجيل الرضعة.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  static const _tabs = [
    (label: 'الرئيسية', icon: Icons.home_rounded),
    (label: 'السجل', icon: Icons.calendar_month_rounded),
    (label: 'العلاجات', icon: Icons.medication_rounded),
    (label: 'الإحصائيات', icon: Icons.bar_chart_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final app = AppState.I;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final child = app.current;
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                _TopBar(
                  onSettings: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                  onChildren: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChildrenScreen()),
                  ),
                ),
                Expanded(
                  child: child == null
                      ? const _EmptyState()
                      : IndexedStack(
                          index: _tab,
                          children: const [
                            HomeTab(),
                            HistoryTab(),
                            MedsTab(),
                            StatsTab(),
                          ],
                        ),
                ),
              ],
            ),
          ),
          floatingActionButton: (child != null && (_tab == 0 || _tab == 1))
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: FloatingActionButton(
                      onPressed: () => openFeedSheet(context),
                      backgroundColor: RC.cyan,
                      foregroundColor: Colors.white,
                      elevation: 6,
                      shape: const CircleBorder(),
                      tooltip: 'تسجيل رضعة',
                      child: const Icon(Icons.add_rounded, size: 30),
                    ),
                  ),
                )
              : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
          bottomNavigationBar: DecoratedBox(
            decoration: BoxDecoration(
              color: RC.surface,
              border: Border(top: BorderSide(color: RC.hair(.09))),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
                child: Row(
                  children: [
                    for (var i = 0; i < _tabs.length; i++)
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _tab = i),
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _tabs[i].icon,
                                  size: 25,
                                  color: _tab == i ? RC.cyan : RC.ink5,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _tabs[i].label,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: _tab == i ? RC.cyan : RC.ink5,
                                    fontWeight:
                                        _tab == i ? FontWeight.w600 : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSettings, required this.onChildren});

  final VoidCallback onSettings;
  final VoidCallback onChildren;

  @override
  Widget build(BuildContext context) {
    final app = AppState.I;
    final cur = app.current;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: RC.hair(.07))),
      ),
      child: Row(
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    cur?.name ?? 'ربى',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  longDayLabel(DateTime.now()),
                  style: const TextStyle(fontSize: 12.5, color: RC.ink4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                children: [
                  for (final k in app.children) ...[
                    _Avatar(
                      initial: k.initial,
                      color: k.color,
                      selected: k.id == app.currentId,
                      onTap: () => app.selectChild(k.id),
                      tooltip: k.name,
                    ),
                    const SizedBox(width: 6),
                  ],
                  _DashedAvatar(onTap: onChildren),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: onSettings,
                    icon: const Icon(Icons.settings_rounded, size: 22, color: RC.ink2),
                    tooltip: 'الإعدادات',
                    constraints: const BoxConstraints.tightFor(width: 34, height: 34),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.initial,
    required this.color,
    required this.selected,
    required this.onTap,
    required this.tooltip,
  });

  final String initial;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? RC.card : RC.muted,
              shape: BoxShape.circle,
              border: selected ? Border.all(color: color, width: 2) : null,
            ),
            child: Text(
              initial,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: selected ? color : RC.ink4,
              ),
            ),
          ),
        ),
      );
}

class _DashedAvatar extends StatelessWidget {
  const _DashedAvatar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'كل الأطفال',
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: RC.hair(.22), width: 1.5),
            ),
            child: const Icon(Icons.add_rounded, size: 18, color: RC.ink4),
          ),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.child_care_rounded, size: 48, color: RC.ink7),
              const SizedBox(height: 14),
              const Text(
                'لا يوجد طفل بعد',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'أضف طفلاً من زر «+» في الأعلى لتبدأ التسجيل.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: RC.ink4, height: 1.7),
              ),
            ],
          ),
        ),
      );
}
