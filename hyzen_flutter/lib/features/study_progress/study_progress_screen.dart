// ignore_for_file: prefer_interpolation_to_compose_strings
import 'package:flutter/material.dart';
import '../../core/widgets/workspace_icons.dart';
import '../../core/widgets/surfaces.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'study_tracker.dart';
import '../../core/theme/tokens.dart';
import 'study_forms.dart';
import 'reward_controller.dart';
import 'campus_rank_screen.dart';
import '../../core/widgets/reward_art.dart';

class HomeStudyTracker extends ConsumerWidget {
  const HomeStudyTracker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(studyTrackerProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? const Color(0xFF202023) : Colors.white,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/study-progress'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.timer_outlined, size: 21),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'STUDY TIME',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_outward_rounded, size: 18),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                formatStudyTime(progress.todaySeconds),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 9),
              LinearProgressIndicator(
                value: (progress.todaySeconds / (progress.dailyGoal * 60))
                    .clamp(0.0, 1.0)
                    .toDouble(),
                color: const Color(0xFF656565),
                backgroundColor: dark ? Colors.white12 : Colors.black12,
                minHeight: 5,
                borderRadius: BorderRadius.circular(9),
              ),
              const SizedBox(height: 9),
              Text(
                'Goal ' +
                    progress.dailyGoal.toString() +
                    ' min  ·  ' +
                    progress.currentStreak.toString() +
                    ' day streak  ·  ' +
                    progress.pendingCount.toString() +
                    ' tasks',
                style: TextStyle(
                  fontSize: 11,
                  color: dark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StudyProgressScreen extends ConsumerWidget {
  const StudyProgressScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(studyTrackerProvider),
        reward = ref.watch(rewardProvider);
    final board = ref.watch(campusBoardProvider('week')).valueOrNull;
    final rank = board?.mine;
    Widget bar(int seconds, int minutes) => LinearProgressIndicator(
      value: (seconds / (minutes * 60)).clamp(0.0, 1.0),
      minHeight: 4,
      borderRadius: BorderRadius.circular(4),
    );
    Widget section(
      String title,
      String summary,
      ControlGlyph icon,
      Widget body,
      Color color,
    ) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
      ),
      child: ExpansionTile(
        key: PageStorageKey(title),
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: ControlIcon(icon, size: 28),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(summary, style: const TextStyle(fontSize: 12)),
        children: [body],
      ),
    );
    return HBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Study progress'),
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/home'),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: hFocusGradient,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const ControlIcon(ControlGlyph.timer, size: 32),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Focus timer',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              p.running
                                  ? 'Reading · tracking automatically'
                                  : p.awaitingClose
                                  ? 'File closed · ending session in 30 seconds'
                                  : 'Open a file to start studying',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    formatStudyTime(p.todaySeconds),
                    key: const ValueKey('study-time'),
                    style: const TextStyle(
                      fontSize: 29,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  bar(p.todaySeconds, p.dailyGoal),
                  const SizedBox(height: 8),
                  const Text(
                    'Only visible, open-file reading counts. Closing the file ends your session after 30 seconds.',
                    style: TextStyle(fontSize: 11),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    p.cloudStatus,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                  if (p.saveError != null) Text(p.saveError!),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: const Color(0xffffedcf),
              child: ListTile(
                onTap: () => context.push('/campus-rank'),
                leading: const RewardArt(11, size: 40),
                title: const Text(
                  'Professional Rank',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  rank == null
                      ? board?.status ?? 'Checking verified ranking…'
                      : '#${rank.rank} · ${rank.minutes} verified min · ${rank.points} rank points',
                ),
                trailing: const Icon(Icons.arrow_forward_rounded, size: 18),
              ),
            ),
            section(
              'Daily & weekly goals',
              '${p.todaySeconds ~/ 60}/${p.dailyGoal} min today',
              ControlGlyph.goal,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daily · ${p.todaySeconds ~/ 60} / ${p.dailyGoal} min'),
                  const SizedBox(height: 8),
                  bar(p.todaySeconds, p.dailyGoal),
                  const SizedBox(height: 12),
                  Text('Weekly · ${p.weekSeconds ~/ 60} / ${p.weeklyGoal} min'),
                  const SizedBox(height: 8),
                  bar(p.weekSeconds, p.weeklyGoal),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => _editGoals(context, p),
                        child: const Text('Edit goals'),
                      ),
                      TextButton(
                        onPressed: () => context.push('/study-goals'),
                        child: const Text('Custom goals'),
                      ),
                    ],
                  ),
                ],
              ),
              const Color(0xffffe6d2),
            ),
            section(
              'Study progress',
              '${reward.streak} claimed days · ${p.weekSeconds ~/ 60} min this week',
              ControlGlyph.streak,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Best study streak · ${p.highestStreak} days'),
                  const SizedBox(height: 6),
                  const Text(
                    'Study streaks require 15 active minutes. Daily reward claims are tracked separately.',
                    style: TextStyle(fontSize: 12),
                  ),
                  TextButton(
                    onPressed: () => context.push('/study-streak'),
                    child: const Text('Daily streak & rewards'),
                  ),
                  const Text(
                    'Recent study breaks',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (p.recentBreaks.isEmpty)
                    const Text('No breaks between recorded study days.')
                  else
                    ...p.recentBreaks.map((s) => Text(s)),
                ],
              ),
              const Color(0xffdfede2),
            ),
            section(
              'Tasks & reminders',
              '${p.pendingCount} tasks pending · ${p.reminders.length} reminders',
              ControlGlyph.reminder,
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Scheduled alerts appear in your phone’s notification panel when permission is enabled.',
                    style: TextStyle(fontSize: 12),
                  ),
                  for (final task in [...p.tasks, ...p.reminders])
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      onTap: () => showStudyForm(
                        context,
                        p,
                        reminder: task.kind == 'reminder',
                        existing: task,
                      ),
                      leading: task.kind == 'reminder'
                          ? Switch(
                              value: task.enabled,
                              onChanged: (_) => p.toggleReminder(task.id),
                            )
                          : Checkbox(
                              value: task.done,
                              onChanged: (_) => p.toggleTask(task.id),
                            ),
                      title: Text(
                        task.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          decoration: task.done
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      subtitle: task.due == null
                          ? null
                          : Text(
                              '${task.due!.day}/${task.due!.month} · ${TimeOfDay.fromDateTime(task.due!).format(context)}',
                            ),
                      trailing: IconButton(
                        tooltip: 'Delete',
                        onPressed: () => p.deleteTask(task.id),
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => showStudyForm(context, p),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add task'),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            showStudyForm(context, p, reminder: true),
                        icon: const Icon(
                          Icons.notifications_none_rounded,
                          size: 18,
                        ),
                        label: const Text('Reminder'),
                      ),
                    ],
                  ),
                ],
              ),
              Colors.white.withValues(alpha: .85),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editGoals(BuildContext context, StudyTracker tracker) async {
    final daily = TextEditingController(text: tracker.dailyGoal.toString());
    final weekly = TextEditingController(text: tracker.weeklyGoal.toString());
    try {
      await showDialog<void>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Set study goals'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: daily,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Daily minutes'),
              ),
              TextField(
                controller: weekly,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Weekly minutes'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final d = int.tryParse(daily.text);
                final w = int.tryParse(weekly.text);
                if (d != null && w != null && d > 0 && w > 0) {
                  tracker.setGoals(d, w);
                  Navigator.pop(dialog);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
    } finally {
      daily.dispose();
      weekly.dispose();
    }
  }
}
