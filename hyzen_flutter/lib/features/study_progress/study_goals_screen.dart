import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'study_tracker.dart';
import 'study_forms.dart';
import '../home/presentation/home_time_artwork.dart';

const _sky = Color(0xFF49AFFF);

/// The full Goals screen from the uploaded reference, using real local data.
class StudyGoalsScreen extends ConsumerStatefulWidget {
  const StudyGoalsScreen({super.key});
  @override
  ConsumerState<StudyGoalsScreen> createState() => _StudyGoalsScreenState();
}

class _StudyGoalsScreenState extends ConsumerState<StudyGoalsScreen> {
  int selectedPeriod = 0;

  Widget panel(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: child,
  );

  Widget sectionHeading(
    String name,
    IconData icon, {
    String? action,
    VoidCallback? onTap,
  }) => LayoutBuilder(
    builder: (context, constraints) {
      final heading = Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      );
      final button = action == null
          ? null
          : TextButton(
              onPressed: onTap,
              child: Text(
                action,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                ),
              ),
            );
      if (MediaQuery.textScalerOf(context).scale(1) > 1.3) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [heading, if (button != null) button],
        );
      }
      return Row(
        children: [
          Expanded(child: heading),
          if (button != null) button,
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(studyTrackerProvider);
    final now = DateTime.now();
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 3.0);
    final pct = (progress.todaySeconds / ((selectedPeriod == 2 ? progress.customGoal : progress.dailyGoal) * 60))
        .clamp(0.0, 1.0)
        .toDouble();
    final weeklyPct = (progress.weekSeconds / (progress.weeklyGoal * 60))
        .clamp(0.0, 1.0)
        .toDouble();
    final todayTasks = progress.tasks.where((task) => task.due == null ||
      studyDayKey(task.due!) == studyDayKey(now)).toList();
    final done = todayTasks.where((task) => task.done).length;
    final total = todayTasks.length;
    final entries = progress.days;
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final week = [
      for (var i = 0; i < 7; i++)
        entries[studyDayKey(monday.add(Duration(days: i)))] ?? 0,
    ];
    final maxWeek = week.fold<int>(1, (m, d) => d > m ? d : m);
    final priorWeek = [
      for (var i = -7; i < now.weekday - 7; i++)
        entries[studyDayKey(monday.add(Duration(days: i)))] ?? 0,
    ].fold<int>(0, (a, b) => a + b);
    final changePercent = priorWeek > 0
        ? ((progress.weekSeconds - priorWeek) / priorWeek * 100).round()
        : null;
    final daysStudied = week.where((s) => s >= 900).length;
    final suggested = (progress.weekSeconds / 60 / 7 * 1.1)
        .round()
        .clamp(30, 360)
        .toInt();
    final goalMinutes = selectedPeriod == 1
        ? progress.weeklyGoal
        : selectedPeriod == 2
        ? progress.customGoal
        : progress.dailyGoal;
    final actualMinutes = selectedPeriod == 1
        ? progress.weekSeconds ~/ 60
        : progress.todaySeconds ~/ 60;

    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          toolbarHeight: 60 * scale,
          backgroundColor: theme.scaffoldBackgroundColor,
          centerTitle: true,
          title: Column(
            children: [
              Text(
                'Study Goals',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              Text(
                'Set goals, track progress & stay consistent',
                style: TextStyle(fontSize: 11, color: muted),
              ),
            ],
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/home'),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.calendar_month_outlined),
              onPressed: () => showDatePicker(
                context: context,
                initialDate: now,
                firstDate: DateTime(2020),
                lastDate: DateTime(now.year + 1),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 38),
          children: [
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: theme.colorScheme.primary),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      HomeTimePhase.at(now).asset,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.scaffoldBackgroundColor.withValues(alpha: .82),
                            theme.scaffoldBackgroundColor.withValues(alpha: .08),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '▣  This Week’s Goal',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${progress.weekSeconds ~/ 3600}h / ${progress.weeklyGoal ~/ 60}h',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: weeklyPct,
                                  minHeight: 8,
                                  color: _sky,
                                  backgroundColor: Theme.of(context).colorScheme.outlineVariant,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${(weeklyPct * 100).round()}%',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.today),
                    label: Text('Daily Goal'),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.date_range),
                    label: Text('Weekly Goal'),
                  ),
                  ButtonSegment(
                    value: 2,
                    icon: Icon(Icons.flag_outlined),
                    label: Text('Custom'),
                  ),
                ],
                selected: {selectedPeriod},
                showSelectedIcon: false,
                onSelectionChanged: (value) =>
                    setState(() => selectedPeriod = value.first),
              ),
            ),
            const SizedBox(height: 14),
            panel(
              Column(
                children: [
                  sectionHeading(
                    selectedPeriod == 1
                        ? 'This Week’s Goal'
                        : selectedPeriod == 2
                        ? 'Custom Study Goal'
                        : 'Today’s Goal',
                    Icons.gps_fixed_rounded,
                    action: 'Edit Goal',
                    onTap: () => _editGoals(progress),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '${goalMinutes ~/ 60}h ${(goalMinutes % 60).toString().padLeft(2, '0')}m',
                              style: TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Study Target',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 45, color: Theme.of(context).colorScheme.outline),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '$done / $total',
                              style: TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Tasks Done',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 67,
                        height: 67,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox.expand(
                              child: CircularProgressIndicator(
                                value: selectedPeriod == 1 ? weeklyPct : pct,
                                color: _sky,
                                backgroundColor: Theme.of(context).colorScheme.outlineVariant,
                                strokeWidth: 8,
                              ),
                            ),
                            Text(
                              '${((selectedPeriod == 1 ? weeklyPct : pct) * 100).round()}%',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$actualMinutes minutes recorded',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            panel(
              Column(
                children: [
                  sectionHeading(
                    'Today’s Tasks',
                    Icons.check_box_outlined,
                    action: '+ Add Task',
                    onTap: () => _addTask(progress),
                  ),
                  if (todayTasks.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(18),
                      child: Text(
                        'No study tasks yet. Add a real task to start tracking.',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ),
                  for (final task in todayTasks)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Material(
                        color: theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(14),
                        child: ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.only(
                            left: 5,
                            right: 4,
                          ),
                          leading: Checkbox(
                            value: task.done,
                            onChanged: (_) => progress.toggleTask(task.id),
                          ),
                          title: Text(
                            task.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              decoration: task.done
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          subtitle: Text(
                            '${task.category} · ${task.estimatedMinutes}m · ${task.priority}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (selection) {
                              if (selection == 'edit') {
                                showStudyForm(
                                  context,
                                  progress,
                                  existing: task,
                                );
                              }
                              if (selection == 'done') {
                                progress.toggleTask(task.id);
                              }
                              if (selection == 'delete') {
                                progress.deleteTask(task.id);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit task'),
                              ),
                              PopupMenuItem(
                                value: 'done',
                                child: Text('Toggle complete'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete task'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _LinkCard(
                    icon: Icons.emoji_events_rounded,
                    title: 'Professional Rank',
                    value: 'View leaderboard',
                    onTap: () => context.push('/campus-rank'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _LinkCard(
                    icon: Icons.local_fire_department_rounded,
                    title: 'Study Streak',
                    value: '${progress.currentStreak} Days',
                    onTap: () => context.push('/study-streak'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            panel(
              Column(
                children: [
                  sectionHeading(
                    'Reminders',
                    Icons.notifications_outlined,
                    action: '+ Add Reminder',
                    onTap: () => _addReminder(progress),
                  ),
                  const SizedBox(height: 6),
                  if (progress.reminders.isEmpty)
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'No reminders scheduled yet.',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ),
                  for (final reminder in progress.reminders)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Material(
                        color: theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(15),
                        child: ListTile(
                          leading: Icon(Icons.menu_book_outlined),
                          title: Text(reminder.title),
                          subtitle: Text(
                            '${reminder.repeat} · ${reminder.due?.hour.toString().padLeft(2, '0') ?? '--'}:${reminder.due?.minute.toString().padLeft(2, '0') ?? '--'}',
                            style: TextStyle(fontSize: 11),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: reminder.enabled,
                                onChanged: (_) =>
                                    progress.toggleReminder(reminder.id),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'edit') { showStudyForm(context, progress, reminder: true, existing: reminder); }
                                  if (v == 'delete') {
                                    progress.deleteTask(reminder.id);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'edit', child: Text('Edit reminder')),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete reminder'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            panel(
              Column(
                children: [
                  sectionHeading(
                    'Weekly Progress',
                    Icons.bar_chart_rounded,
                    action: 'See Details',
                    onTap: () => context.push('/study-streak'),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 112 * scale,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        for (var i = 0; i < 7; i++)
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  week[i] == 0 ? '—' : '${week[i] ~/ 60}m',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontSize: 9,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  height: 10 + 63 * week[i] / maxWeek,
                                  width: 28,
                                  decoration: BoxDecoration(
                                    color: week[i] == 0 ? Theme.of(context).colorScheme.outlineVariant : _sky,
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  const [
                                    'Mon',
                                    'Tue',
                                    'Wed',
                                    'Thu',
                                    'Fri',
                                    'Sat',
                                    'Sun',
                                  ][i],
                                  style: TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            panel(
              Column(
                children: [
                  sectionHeading('Insights', Icons.insights_outlined),
                  Wrap(
                    spacing: 15,
                    runSpacing: 8,
                    children: [
                      _Insight(
                        'Total study',
                        '${progress.days.values.fold<int>(0, (a, b) => a + b) ~/ 60}m',
                      ),
                      _Insight(
                        'Daily average',
                        '${(progress.weekSeconds ~/ 60) ~/ now.weekday}m',
                      ),
                      _Insight('Active days', '$daysStudied / 7'),
                      _Insight(
                        'Vs last week',
                        changePercent == null
                            ? 'No baseline'
                            : '${changePercent > 0 ? '+' : ''}$changePercent%',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            panel(
              Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: _sky),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Goal Suggestion',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Try ${suggested}m each day based on your recent week.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        progress.setGoals(suggested, progress.weeklyGoal),
                    child: Text('Apply', style: TextStyle(color: _sky)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editGoals(StudyTracker tracker) async {
    final controller = TextEditingController(
      text:
          (selectedPeriod == 1
                  ? tracker.weeklyGoal
                  : selectedPeriod == 2
                  ? tracker.customGoal
                  : tracker.dailyGoal)
              .toString(),
    );
    try {
      await showDialog<void>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text('Edit study target'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Target minutes'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(controller.text.trim());
                if (value == null || value < 1 || value > 10080) return;
                if (selectedPeriod == 1) {
                  tracker.setGoals(tracker.dailyGoal, value);
                } else if (selectedPeriod == 2) {
                  tracker.setCustomGoal(value);
                } else {
                  tracker.setGoals(value, tracker.weeklyGoal);
                }
                Navigator.pop(dialog);
              },
              child: Text('Save'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _addTask(StudyTracker tracker) =>
      showStudyForm(context, tracker);
  Future<void> _addReminder(StudyTracker tracker) =>
      showStudyForm(context, tracker, reminder: true);
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });
  final IconData icon;
  final String title, value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(20),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 23, color: Theme.of(context).colorScheme.primary),
                const Spacer(),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Insight extends StatelessWidget {
  const _Insight(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 125,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    ),
  );
}
