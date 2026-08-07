import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../util/dates.dart';
import '../welcome_screen.dart';
import '../widgets/common.dart';
import '../widgets/stack_scaffold.dart';
import 'child_screen.dart';

/// إدارة الأطفال: ترتيب بالسحب، فتح ملف الطفل، وأرشفة بدل الحذف.
class ChildrenScreen extends StatelessWidget {
  const ChildrenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.I;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => StackScaffold(
        title: 'الأطفال',
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorder: (oldIndex, newIndex) async {
                final ids = app.children.map((c) => c.id).toList();
                if (newIndex > oldIndex) newIndex--;
                ids.insert(newIndex, ids.removeAt(oldIndex));
                await app.repo.reorderChildren(ids);
                await app.load();
              },
              children: [
                for (var i = 0; i < app.children.length; i++)
                  Padding(
                    key: ValueKey(app.children[i].id),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: RubaCard(
                      padding: const EdgeInsets.all(14),
                      shadowOpacity: .08,
                      child: Row(
                        children: [
                          ReorderableDragStartListener(
                            index: i,
                            child: Icon(Icons.drag_indicator_rounded,
                                size: 22, color: RC.ink7),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            width: 46,
                            height: 46,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: RC.muted,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              app.children[i].initial,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: app.children[i].color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                await app.selectChild(app.children[i].id);
                                if (context.mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const ChildScreen()),
                                  );
                                }
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(app.children[i].name,
                                      style: const TextStyle(
                                          fontSize: 18, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(ageLabel(app.children[i].dob),
                                      style: TextStyle(
                                          fontSize: 13.5, color: RC.ink4)),
                                ],
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _archive(context, i),
                            icon: const Icon(Icons.archive_outlined, size: 19),
                            label: const Text('أرشفة', style: TextStyle(fontSize: 14)),
                            style: TextButton.styleFrom(foregroundColor: RC.ink4),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            GhostButton(
              label: 'إضافة طفل',
              dashed: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const WelcomeScreen(startStep: 1, asAddChild: true),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'الأرشفة تُخفي الطفل من التبديل السريع وتُبقي كل سجلاته.',
              style: TextStyle(fontSize: 13, color: RC.ink4, height: 1.7),
            ),
            if (app.archivedChildren.isNotEmpty) ...[
              const SizedBox(height: 20),
              const SectionLabel('مؤرشفة'),
              const SizedBox(height: 10),
              for (final c in app.archivedChildren)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: RubaCard(
                    color: RC.mutedDeep,
                    shadowOpacity: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(c.name,
                              style: TextStyle(fontSize: 17, color: RC.ink3)),
                        ),
                        TextButton(
                          onPressed: () => app.archiveChild(c.id, false),
                          child: Text('استعادة',
                              style: TextStyle(color: RC.cyanDark)),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _archive(BuildContext context, int index) async {
    final app = AppState.I;
    final c = app.children[index];
    if (app.children.length == 1) {
      flash(context, 'لا يمكن أرشفة الطفل الوحيد');
      return;
    }
    final ok = await confirm(
      context,
      title: 'أرشفة ${c.name}',
      message: 'سيختفي من التبديل السريع، وتبقى كل سجلاته محفوظة ويمكن استعادته لاحقاً.',
      confirmLabel: 'أرشفة',
    );
    if (!ok) return;
    await app.archiveChild(c.id, true);
    if (context.mounted) flash(context, 'أُرشف ${c.name} — سجلاته محفوظة');
  }
}
