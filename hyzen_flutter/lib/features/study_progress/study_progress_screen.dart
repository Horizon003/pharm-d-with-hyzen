// ignore_for_file: prefer_interpolation_to_compose_strings
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'study_tracker.dart';

class HomeStudyTracker extends ConsumerWidget {
  const HomeStudyTracker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(studyTrackerProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? const Color(0xFF202023) : Colors.white,
      borderRadius: BorderRadius.circular(22),
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
                        fontWeight: FontWeight.w800,
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
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 9),
              LinearProgressIndicator(
                value: (progress.todaySeconds / (progress.dailyGoal * 60))
                    .clamp(0.0, 1.0)
                    .toDouble(),
                color: const Color(0xFF087F76),
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
    final progress = ref.watch(studyTrackerProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF09090A) : const Color(0xFFF4F4F5);
    final surface = dark ? const Color(0xFF1B1B1D) : Colors.white;
    final secondary = dark ? Colors.white70 : Colors.black54;

    Widget panel(String name, Widget body) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          body,
        ],
      ),
    );

    Widget progressBar(int seconds, int goal) => LinearProgressIndicator(
      value: (seconds / (goal * 60)).clamp(0.0, 1.0).toDouble(),
      minHeight: 7,
      color: const Color(0xFF087F76),
      backgroundColor: dark ? Colors.white12 : Colors.black12,
      borderRadius: BorderRadius.circular(12),
    );

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Study progress',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
        children: [
          panel(
            'Focus timer',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatStudyTime(progress.todaySeconds),
                  key: const ValueKey('study-time'),
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  progress.cloudStatus,
                  style: TextStyle(fontSize: 12, color: secondary),
                ),
                const SizedBox(height: 16),
                if (progress.running)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: progress.pause,
                      icon: const Icon(Icons.pause_rounded),
                      label: const Text('Pause study session'),
                      style: FilledButton.styleFrom(
                        backgroundColor: dark ? Colors.white : Colors.black,
                        foregroundColor: dark ? Colors.black : Colors.white,
                        minimumSize: const Size(0, 48),
                      ),
                    ),
                  )
                else
                  Text(
                    'Study time starts automatically when you open a file.',
                    style: TextStyle(fontSize: 12, color: secondary),
                  ),
                if (progress.hasSession)
                  TextButton.icon(
                    onPressed: progress.stop,
                    icon: const Icon(Icons.stop_rounded),
                    label: const Text('Stop session'),
                  ),
                const Text(
                  'Pauses in the background or after 5 minutes without interaction.',
                  style: TextStyle(fontSize: 11),
                ),
                if (progress.saveError != null) Text(progress.saveError!),
              ],
            ),
          ),
          const SizedBox(height: 14),
          panel(
            'Daily & weekly goals',
            Column(
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('Daily goal')),
                    Text(
                      (progress.todaySeconds ~/ 60).toString() +
                          ' / ' +
                          progress.dailyGoal.toString() +
                          ' min',
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                progressBar(progress.todaySeconds, progress.dailyGoal),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(child: Text('This week')),
                    Text(
                      (progress.weekSeconds ~/ 60).toString() +
                          ' / ' +
                          progress.weeklyGoal.toString() +
                          ' min',
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                progressBar(progress.weekSeconds, progress.weeklyGoal),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => _editGoals(context, progress),
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: const Text('Edit goals'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          panel(
            'Streaks & recent breaks',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 18,
                  runSpacing: 12,
                  children: [
                    _Stat(
                      'Current streak',
                      progress.currentStreak.toString() + ' days',
                      Icons.local_fire_department_outlined,
                    ),
                    _Stat(
                      'Highest streak',
                      progress.highestStreak.toString() + ' days',
                      Icons.emoji_events_outlined,
                    ),
                    _Stat(
                      'This week',
                      (progress.weekSeconds ~/ 60).toString() + ' min',
                      Icons.calendar_today_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Recent breaks',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (progress.recentBreaks.isEmpty)
                  Text(
                    'No breaks between tracked study days yet.',
                    style: TextStyle(fontSize: 12, color: secondary),
                  )
                else
                  for (final item in progress.recentBreaks)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text(
                        item,
                        style: TextStyle(fontSize: 12, color: secondary),
                      ),
                    ),
                const SizedBox(height: 10),
                Text(
                  'At least 15 actively studied minutes count as a study day.',
                  style: TextStyle(fontSize: 11, color: secondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          panel(
            'Tasks & reminders',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reminder alerts appear in the in-app inbox when the app runs.',
                  style: TextStyle(fontSize: 12, color: secondary),
                ),
                const SizedBox(height: 12),
                for (final task in progress.tasks)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Checkbox(
                      value: task.done,
                      onChanged: (_) => progress.toggleTask(task.id),
                    ),
                    title: Text(
                      task.title,
                      style: TextStyle(
                        decoration: task.done
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    subtitle: task.due == null
                        ? null
                        : Text(
                            'Reminder: ' +
                                task.due!.day.toString() +
                                '/' +
                                task.due!.month.toString() +
                                ' at ' +
                                task.due!.hour.toString().padLeft(2, '0') +
                                ':' +
                                task.due!.minute.toString().padLeft(2, '0'),
                            style: TextStyle(fontSize: 11, color: secondary),
                          ),
                    trailing: IconButton(
                      tooltip: 'Delete task',
                      icon: const Icon(Icons.close_rounded, size: 19),
                      onPressed: () => progress.deleteTask(task.id),
                    ),
                  ),
                if (progress.tasks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'No tasks yet. Add your first study task.',
                      style: TextStyle(color: secondary),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _addTask(context, progress),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add task or reminder'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          panel(
            'Professional Rank',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.groups_outlined, size: 28),
                const SizedBox(height: 10),
                const Text(
                  'Open Professional Rank for your verified leaderboard.',
                ),
                const SizedBox(height: 5),
                Text(
                  'Students from all colleges compete within their verified professional year.',
                  style: TextStyle(fontSize: 12, color: secondary),
                ),
              ],
            ),
          ),
        ],
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

  Future<void> _addTask(BuildContext context, StudyTracker tracker) async {
    final title = TextEditingController();
    DateTime? due;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheet) => StatefulBuilder(
          builder: (sheet, redraw) => Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              MediaQuery.viewInsetsOf(sheet).bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'New study task',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: title,
                  autofocus: true,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Task',
                    hintText: 'Revise pharmacology',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.notifications_none_rounded),
                  label: Text(
                    due == null
                        ? 'Set reminder date & time'
                        : 'Reminder: ' +
                              due!.day.toString() +
                              '/' +
                              due!.month.toString() +
                              ' ' +
                              due!.hour.toString().padLeft(2, '0') +
                              ':' +
                              due!.minute.toString().padLeft(2, '0'),
                  ),
                  onPressed: () async {
                    final now = DateTime.now();
                    final date = await showDatePicker(
                      context: sheet,
                      initialDate: now,
                      firstDate: now.subtract(const Duration(days: 1)),
                      lastDate: now.add(const Duration(days: 365)),
                    );
                    if (date == null || !sheet.mounted) return;
                    final time = await showTimePicker(
                      context: sheet,
                      initialTime: TimeOfDay.now(),
                    );
                    if (time == null || !sheet.mounted) return;
                    redraw(
                      () => due = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time.hour,
                        time.minute,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      if (title.text.trim().isEmpty) return;
                      tracker.addTask(title.text, due);
                      Navigator.pop(sheet);
                    },
                    child: const Text('Save task'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      title.dispose();
    }
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.name, this.value, this.icon);
  final String name, value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 96,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 21),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        Text(name, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}
