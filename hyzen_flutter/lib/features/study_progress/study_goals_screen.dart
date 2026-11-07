import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'study_tracker.dart';
import 'study_notifications.dart';
import '../home/presentation/home_time_artwork.dart';

const _sky = Color(0xFF49AFFF);
const _panel = Color(0xFF1A2838);
const _border = Color(0xFF3B5269);

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
    decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _border)),
    child: child,
  );

  Widget sectionHeading(String name, IconData icon, {String? action, VoidCallback? onTap}) =>
      Row(children: [
        Icon(icon, size: 20, color: _sky),
        const SizedBox(width: 8),
        Expanded(child: Text(name, style: const TextStyle(fontSize: 17,
          fontWeight: FontWeight.w800, color: Colors.white))),
        if (action != null) TextButton(onPressed: onTap, child: Text(action,
          style: const TextStyle(color: _sky, fontSize: 12))),
      ]);

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(studyTrackerProvider);
    final now = DateTime.now();
    final pct = (progress.todaySeconds / (progress.dailyGoal * 60)).clamp(0.0, 1.0).toDouble();
    final weeklyPct = (progress.weekSeconds / (progress.weeklyGoal * 60)).clamp(0.0, 1.0).toDouble();
    final done = progress.completedTasks;
    final total = progress.tasks.length;
    final entries = progress.days;
    final monday = DateTime(now.year, now.month, now.day).subtract(
        Duration(days: now.weekday - 1));
    final week = [for (var i = 0; i < 7; i++)
      entries[studyDayKey(monday.add(Duration(days: i)))] ?? 0];
    final maxWeek = week.fold<int>(1, (m, d) => d > m ? d : m);
    final priorWeek = [for (var i = -7; i < 0; i++)
      entries[studyDayKey(monday.add(Duration(days: i)))] ?? 0]
        .fold<int>(0, (a, b) => a + b);
    final changePercent = priorWeek > 0
        ? ((progress.weekSeconds - priorWeek) / priorWeek * 100).round()
        : null;
    final daysStudied = week.where((s) => s >= 900).length;
    final suggested = (progress.weekSeconds / 60 / 7 * 1.1).round().clamp(30, 360).toInt();
    final goalMinutes = selectedPeriod == 1 ? progress.weeklyGoal :
        selectedPeriod == 2 ? progress.customGoal : progress.dailyGoal;
    final actualMinutes = selectedPeriod == 1 ? progress.weekSeconds ~/ 60 : progress.todaySeconds ~/ 60;

    return Theme(data: ThemeData.dark(useMaterial3: true).copyWith(
      colorScheme: const ColorScheme.dark(primary: _sky, surface: _panel)),
      child: Scaffold(backgroundColor: const Color(0xFF081521),
      appBar: AppBar(backgroundColor: const Color(0xFF081521),
        centerTitle: true, title: const Column(children: [
          Text('🎯 Study Goals', style: TextStyle(fontSize: 22,
            fontWeight: FontWeight.w800)),
          Text('Set goals, track progress & stay consistent',
            style: TextStyle(fontSize: 11, color: Colors.white70)),
        ]),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home')),
        actions: [IconButton(icon: const Icon(Icons.calendar_month_outlined),
          onPressed: () => showDatePicker(context: context,
            initialDate: now, firstDate: DateTime(2020),
            lastDate: DateTime(now.year + 1)))],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 10, 14, 38), children: [
        Container(height: 145, clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _sky)),
          child: Stack(fit: StackFit.expand, children: [
            Image.asset(HomeTimePhase.at(now).asset, fit: BoxFit.cover),
            const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
              colors: [Color(0xF4081727), Color(0x16081727)],
              begin: Alignment.centerLeft, end: Alignment.centerRight))),
            Padding(padding: const EdgeInsets.all(18), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('▣  This Week’s Goal',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('${progress.weekSeconds ~/ 3600}h / ${progress.weeklyGoal ~/ 60}h',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                const SizedBox(height: 9),
                Row(children: [Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(value: weeklyPct,
                    minHeight: 8, color: _sky, backgroundColor: Colors.white24))),
                  const SizedBox(width: 12), Text('${(weeklyPct * 100).round()}%',
                    style: const TextStyle(fontWeight: FontWeight.w800))]),
              ])),
          ])),
        const SizedBox(height: 14),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, icon: Icon(Icons.today), label: Text('Daily Goal')),
            ButtonSegment(value: 1, icon: Icon(Icons.date_range), label: Text('Weekly Goal')),
            ButtonSegment(value: 2, icon: Icon(Icons.flag_outlined), label: Text('Custom')),
          ],
          selected: {selectedPeriod}, showSelectedIcon: false,
          onSelectionChanged: (value) => setState(() => selectedPeriod = value.first),
        ),
        const SizedBox(height: 14),
        panel(Column(children: [
          sectionHeading(selectedPeriod == 1 ? 'This Week’s Goal' :
            selectedPeriod == 2 ? 'Custom Study Goal' : 'Today’s Goal',
            Icons.gps_fixed_rounded,
            action: 'Edit Goal', onTap: () => _editGoals(progress)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Column(children: [
              Text('${goalMinutes ~/ 60}h ${(goalMinutes % 60).toString().padLeft(2, '0')}m',
                style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
              const Text('Study Target', style: TextStyle(fontSize: 11,
                color: Colors.white70)),
            ])),
            Container(width: 1, height: 45, color: Colors.white38),
            Expanded(child: Column(children: [
              Text('$done / $total', style: const TextStyle(fontSize: 23,
                fontWeight: FontWeight.w900)),
              const Text('Tasks Done', style: TextStyle(fontSize: 11,
                color: Colors.white70)),
            ])),
            SizedBox(width: 67, height: 67, child: Stack(
              alignment: Alignment.center, children: [
              SizedBox.expand(child: CircularProgressIndicator(
                value: selectedPeriod == 1 ? weeklyPct : pct,
                color: _sky, backgroundColor: Colors.white24, strokeWidth: 8)),
              Text('${((selectedPeriod == 1 ? weeklyPct : pct) * 100).round()}%',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            ])),
          ]),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerLeft, child: Text(
            '$actualMinutes minutes recorded',
            style: const TextStyle(fontSize: 11, color: Colors.white70))),
        ])),
        const SizedBox(height: 14),
        panel(Column(children: [
          sectionHeading('Today’s Tasks', Icons.check_box_outlined,
            action: '+ Add Task', onTap: () => _addTask(progress)),
          if (progress.tasks.isEmpty)
            const Padding(padding: EdgeInsets.all(18), child: Text(
              'No study tasks yet. Add a real task to start tracking.',
              style: TextStyle(color: Colors.white70))),
          for (final task in progress.tasks)
            Padding(padding: const EdgeInsets.only(top: 8), child: Material(
              color: const Color(0xFF26384B), borderRadius: BorderRadius.circular(14),
              child: ListTile(dense: true, contentPadding: const EdgeInsets.only(left: 5, right: 4),
                leading: Checkbox(value: task.done,
                  onChanged: (_) => progress.toggleTask(task.id)),
                title: Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(decoration: task.done ? TextDecoration.lineThrough : null)),
                subtitle: Text('${task.category} · ${task.estimatedMinutes}m · ${task.priority}',
                  style: const TextStyle(fontSize: 10, color: Colors.white70)),
                trailing: PopupMenuButton<String>(onSelected: (selection) {
                  if (selection == 'done') progress.toggleTask(task.id);
                  if (selection == 'delete') progress.deleteTask(task.id);
                }, itemBuilder: (_) => const [
                  PopupMenuItem(value: 'done', child: Text('Toggle complete')),
                  PopupMenuItem(value: 'delete', child: Text('Delete task')),
                ]),
              ),
            )),
        ])),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _LinkCard(icon: Icons.emoji_events_rounded,
            title: 'Campus Rank', value: 'View leaderboard',
            onTap: () => context.push('/campus-rank'))),
          const SizedBox(width: 10),
          Expanded(child: _LinkCard(icon: Icons.local_fire_department_rounded,
            title: 'Study Streak', value: '${progress.currentStreak} Days',
            onTap: () => context.push('/study-streak'))),
        ]),
        const SizedBox(height: 14),
        panel(Column(children: [
          sectionHeading('Reminders', Icons.notifications_outlined,
            action: '+ Add Reminder', onTap: () => _addReminder(progress)),
          const SizedBox(height: 6),
          if (progress.reminders.isEmpty)
            const Padding(padding: EdgeInsets.all(12), child: Text(
              'No reminders scheduled yet.', style: TextStyle(color: Colors.white70))),
          for (final reminder in progress.reminders)
            Padding(padding: const EdgeInsets.only(bottom: 7),
              child: Material(color: const Color(0xFF26384B),
                borderRadius: BorderRadius.circular(15), child: ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(reminder.title),
                  subtitle: Text('${reminder.repeat} · ${reminder.due?.hour.toString().padLeft(2, '0') ?? '--'}:${reminder.due?.minute.toString().padLeft(2, '0') ?? '--'}',
                    style: const TextStyle(fontSize: 11)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Switch(value: reminder.enabled,
                      onChanged: (_) => progress.toggleReminder(reminder.id)),
                    PopupMenuButton<String>(onSelected: (v) {
                      if (v == 'delete') progress.deleteTask(reminder.id);
                    }, itemBuilder: (_) => const [
                      PopupMenuItem(value: 'delete', child: Text('Delete reminder')),
                    ]),
                  ]),
                ))),
        ])),
        const SizedBox(height: 14),
        panel(Column(children: [
          sectionHeading('Weekly Progress', Icons.bar_chart_rounded,
            action: 'See Details', onTap: () => context.push('/study-streak')),
          const SizedBox(height: 14),
          SizedBox(height: 112, child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [for (var i = 0; i < 7; i++)
              Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text(week[i] == 0 ? '—' : '${week[i] ~/ 60}m',
                  style: const TextStyle(color: Colors.white70, fontSize: 9)),
                const SizedBox(height: 4),
                Container(height: 10 + 63 * week[i] / maxWeek,
                  width: 28, decoration: BoxDecoration(
                    color: week[i] == 0 ? Colors.white24 : _sky,
                    borderRadius: BorderRadius.circular(7))),
                const SizedBox(height: 5),
                Text(const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][i],
                  style: const TextStyle(fontSize: 10)),
              ])),
            ],
          )),
        ])),
        const SizedBox(height: 14),
        panel(Column(children: [
          sectionHeading('Insights', Icons.insights_outlined),
          Wrap(spacing: 15, runSpacing: 8, children: [
            _Insight('Total study', '${progress.days.values.fold<int>(0, (a,b) => a+b) ~/ 60}m'),
            _Insight('Daily average', '${(progress.weekSeconds ~/ 60) ~/ 7}m'),
            _Insight('Active days', '$daysStudied / 7'),
            _Insight('Vs last week', changePercent == null ? 'No baseline' : '${changePercent > 0 ? '+' : ''}$changePercent%'),
          ]),
        ])),
        const SizedBox(height: 14),
        panel(Row(children: [
          const Icon(Icons.lightbulb_outline, color: _sky),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Goal Suggestion', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('Try ${suggested}m each day based on your recent week.',
              style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ])),
          TextButton(onPressed: () => progress.setGoals(suggested, progress.weeklyGoal),
            child: const Text('Apply', style: TextStyle(color: _sky))),
        ])),
      ]),
    ));
  }

  Future<void> _editGoals(StudyTracker tracker) async {
    final controller = TextEditingController(text: (
      selectedPeriod == 1 ? tracker.weeklyGoal :
      selectedPeriod == 2 ? tracker.customGoal : tracker.dailyGoal).toString());
    try {
      await showDialog<void>(context: context, builder: (dialog) => AlertDialog(
        title: const Text('Edit study target'),
        content: TextField(controller: controller, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Target minutes')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Cancel')),
          FilledButton(onPressed: () {
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
          }, child: const Text('Save')),
        ],
      ));
    } finally {
      controller.dispose();
    }
  }

  Future<void> _addTask(StudyTracker tracker) async {
    final title = TextEditingController();
    var category = 'General';
    var priority = 'Medium';
    var minutes = 30;
    DateTime? due;
    try {
      await showModalBottomSheet<void>(context: context, showDragHandle: true,
        isScrollControlled: true, backgroundColor: _panel,
        builder: (sheet) => StatefulBuilder(builder: (sheet, change) =>
          SingleChildScrollView(padding: EdgeInsets.fromLTRB(20, 8, 20,
              24 + MediaQuery.viewInsetsOf(sheet).bottom), child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add Task', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 21)),
              const Text('Create a study task for your goal',
                style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 14),
              TextField(controller: title, autofocus: true, maxLength: 120,
                decoration: const InputDecoration(labelText: 'Task Title *',
                    hintText: 'e.g. Revise Unit 3')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(initialValue: category,
                decoration: const InputDecoration(labelText: 'Subject / Category'),
                items: const ['General','Pharmacology','Pharmaceutics','Pharmacognosy',
                  'Pathology','Biochemistry','Other']
                  .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (v) => change(() => category = v ?? category)),
              const SizedBox(height: 14),
              const Text('Estimated Time', style: TextStyle(fontWeight: FontWeight.w800)),
              Wrap(spacing: 8, children: [for (final v in [15,30,60,90,120])
                ChoiceChip(label: Text('${v}m'), selected: minutes == v,
                  onSelected: (_) => change(() => minutes = v))]),
              const SizedBox(height: 8),
              const Text('Priority', style: TextStyle(fontWeight: FontWeight.w800)),
              Wrap(spacing: 8, children: [for (final v in ['Low','Medium','High'])
                ChoiceChip(label: Text(v), selected: priority == v,
                  onSelected: (_) => change(() => priority = v))]),
              const SizedBox(height: 10),
              OutlinedButton.icon(icon: const Icon(Icons.event_outlined),
                label: Text(due == null ? 'Due Date (optional)' :
                  '${due!.day}/${due!.month}/${due!.year}'),
                onPressed: () async {
                  final result = await showDatePicker(context: sheet,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (result != null) change(() => due = result);
                }),
              const SizedBox(height: 14),
              SizedBox(width: double.infinity, child: FilledButton(
                onPressed: () {
                  if (title.text.trim().isEmpty) return;
                  tracker.addDetailedTask(title.text, category: category,
                    priority: priority.toLowerCase(), estimatedMinutes: minutes,
                    due: due);
                  Navigator.pop(sheet);
                }, child: const Text('Add Task'))),
            ],
          )),
        ),
      );
    } finally {
      title.dispose();
    }
  }

  Future<void> _addReminder(StudyTracker tracker) async {
    final title = TextEditingController();
    var type = 'Study';
    var repeat = 'daily';
    var lead = 0;
    var due = DateTime.now().add(const Duration(hours: 1));
    try {
      await showModalBottomSheet<void>(context: context, isScrollControlled: true,
        showDragHandle: true, backgroundColor: _panel,
        builder: (sheet) => StatefulBuilder(builder: (sheet, change) =>
          SingleChildScrollView(padding: EdgeInsets.fromLTRB(20, 8, 20,
              24 + MediaQuery.viewInsetsOf(sheet).bottom), child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add Reminder', style: TextStyle(fontSize: 21,
                fontWeight: FontWeight.w900)),
              const Text('Get notified for your study tasks',
                style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 14),
              TextField(controller: title, maxLength: 100,
                decoration: const InputDecoration(labelText: 'Reminder Title *',
                  hintText: 'e.g. Study Time')),
              const SizedBox(height: 7),
              const Text('Reminder Type', style: TextStyle(fontWeight: FontWeight.w800)),
              Wrap(spacing: 7, children: [for (final name in ['Study','Task','Goal','General'])
                ChoiceChip(label: Text(name), selected: type == name,
                  onSelected: (_) => change(() => type = name))]),
              const SizedBox(height: 9),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text('${due.day}/${due.month}/${due.year}'),
                  onPressed: () async {
                    final result = await showDatePicker(context: sheet,
                      initialDate: due, firstDate: DateTime.now().subtract(
                        const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (result != null) { change(() => due = DateTime(
                      result.year, result.month, result.day, due.hour, due.minute)); }
                  })),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(
                  icon: const Icon(Icons.schedule),
                  label: Text('${due.hour.toString().padLeft(2,'0')}:${due.minute.toString().padLeft(2,'0')}'),
                  onPressed: () async {
                    final result = await showTimePicker(context: sheet,
                        initialTime: TimeOfDay.fromDateTime(due));
                    if (result != null) {
                      change(() => due = DateTime(due.year, due.month,
                          due.day, result.hour, result.minute));
                    }
                  })),
              ]),
              const SizedBox(height: 12),
              const Text('Repeat', style: TextStyle(fontWeight: FontWeight.w800)),
              Wrap(spacing: 7, children: [for (final val in ['none','daily','weekdays','weekly'])
                ChoiceChip(label: Text(val == 'none' ? 'Once' :
                  val == 'weekdays' ? 'Mon–Fri' : val[0].toUpperCase() + val.substring(1)),
                  selected: repeat == val,
                  onSelected: (_) => change(() => repeat = val))]),
              const SizedBox(height: 10),
              const Text('Notify Me', style: TextStyle(fontWeight: FontWeight.w800)),
              Wrap(spacing: 7, children: [for (final v in [0,10,30])
                ChoiceChip(label: Text(v == 0 ? 'At time' : '$v min before'),
                  selected: lead == v,
                  onSelected: (_) => change(() => lead = v))]),
              const SizedBox(height: 14),
              SizedBox(width: double.infinity, child: FilledButton(
                onPressed: () async {
                  if (title.text.trim().isEmpty) return;
                  final allowed = await StudyNotificationScheduler.instance.requestPermission();
                  tracker.addReminder(title.text, due, type: type,
                    repeat: repeat, leadMinutes: lead);
                  if (!sheet.mounted || !mounted) return;
                  Navigator.pop(sheet);
                  if (!allowed) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Reminder saved. Enable device notifications to see Android alerts.')));
                  }
                }, child: const Text('Add Reminder'))),
            ],
          )),
        ),
      );
    } finally {
      title.dispose();
    }
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({required this.icon, required this.title, required this.value,
      required this.onTap});
  final IconData icon;
  final String title, value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(color: _panel,
    borderRadius: BorderRadius.circular(20), clipBehavior: Clip.antiAlias,
    child: InkWell(onTap: onTap, child: Padding(
      padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, size: 23, color: _sky), const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.white70)]),
          const SizedBox(height: 7), Text(title, style: const TextStyle(
            fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 4), Text(value, style: const TextStyle(
            color: Colors.white70, fontSize: 12)),
        ]))),
  );
}

class _Insight extends StatelessWidget {
  const _Insight(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => SizedBox(width: 125,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
    ]));
}
