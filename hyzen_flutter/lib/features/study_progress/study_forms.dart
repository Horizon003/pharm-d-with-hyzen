import 'package:flutter/material.dart';
import 'study_tracker.dart';
import 'study_session.dart';
import 'study_notifications.dart';

Future<void> showStudyForm(
  BuildContext context,
  StudyTracker tracker, {
  bool reminder = false,
  StudyTask? existing,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) =>
      _StudyForm(tracker: tracker, reminder: reminder, existing: existing),
);

class _StudyForm extends StatefulWidget {
  const _StudyForm({
    required this.tracker,
    required this.reminder,
    this.existing,
  });
  final StudyTracker tracker;
  final bool reminder;
  final StudyTask? existing;
  @override
  State<_StudyForm> createState() => _StudyFormState();
}

class _StudyFormState extends State<_StudyForm> {
  final form = GlobalKey<FormState>();
  late final String taskId;
  late final TextEditingController title, category, duration;
  late String priority, repeat;
  late DateTime? due, until;
  late Set<int> weekdays;
  late int lead, extra;
  late bool quiet;
  bool saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final task = widget.existing;
    taskId = task?.id ?? studyId();
    title = TextEditingController(text: task?.title ?? '');
    category = TextEditingController(
      text: task?.category ?? (widget.reminder ? 'Study' : 'General'),
    );
    duration = TextEditingController(text: '${task?.estimatedMinutes ?? 30}');
    priority = task?.priority ?? 'medium';
    repeat = task?.repeat ?? 'none';
    due =
        task?.due ??
        (widget.reminder ? DateTime.now().add(const Duration(hours: 1)) : null);
    until = task?.until;
    weekdays = {...?task?.weekdays};
    lead = task?.leadMinutes ?? 0;
    extra = task?.extraAlerts ?? 0;
    quiet = task?.quiet ?? true;
  }

  @override
  void dispose() {
    title.dispose();
    category.dispose();
    duration.dispose();
    super.dispose();
  }

  Future<void> pickDue() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: due != null && !due!.isBefore(now) ? due! : now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    if (!widget.reminder) {
      setState(() => due = date);
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(due ?? now),
    );
    if (time != null && mounted) {
      setState(
        () => due = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    if (widget.reminder &&
        (due == null ||
            !due!.subtract(Duration(minutes: lead)).isAfter(DateTime.now()))) {
      setState(
        () => error = 'Choose a future date and time after the advance alert.',
      );
      return;
    }
    if (repeat == 'custom' && weekdays.isEmpty) {
      setState(() => error = 'Choose at least one repeat day.');
      return;
    }
    if (until != null &&
        due != null &&
        until!.isBefore(DateTime(due!.year, due!.month, due!.day))) {
      setState(
        () => error = 'The stop date must be on or after the first reminder.',
      );
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    final task = StudyTask(
      taskId,
      title.text.trim(),
      due: due,
      kind: widget.reminder ? 'reminder' : 'task',
      category: category.text.trim(),
      priority: priority,
      estimatedMinutes: int.tryParse(duration.text) ?? 30,
      repeat: repeat,
      leadMinutes: lead,
      extraAlerts: extra,
      weekdays: weekdays.toList()..sort(),
      quiet: quiet,
      until: until,
      enabled: widget.existing?.enabled ?? true,
      done: widget.existing?.done ?? false,
    );
    await widget.tracker.saveTask(task);
    await widget.tracker.flush();
    if (!mounted) return;
    if (widget.tracker.saveError != null) {
      setState(() {
        error = widget.tracker.saveError;
        saving = false;
      });
      return;
    }
    final allowed =
        !widget.reminder ||
        await StudyNotificationScheduler.instance.requestPermission();
    if (!mounted) return;
    if (!allowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Reminder saved. Enable notification permission on your phone for system alerts.',
          ),
        ),
      );
    }
    final scheduleError = StudyNotificationScheduler.instance.lastError;
    if (widget.reminder && allowed && scheduleError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reminder saved locally. $scheduleError')));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.existing == null ? 'Add' : 'Edit';
    final kind = widget.reminder ? 'Reminder' : 'Task';
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$action $kind',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: title,
                maxLength: 120,
                decoration: InputDecoration(labelText: '$kind Title *'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter a title.' : null,
              ),
              if (!widget.reminder) ...[
                TextFormField(
                  controller: category,
                  maxLength: 60,
                  decoration: const InputDecoration(
                    labelText: 'Subject / Category',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Enter a category.'
                      : null,
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final name
                        in widget.tracker.tasks
                            .map((t) => t.category)
                            .toSet()
                            .take(8))
                      ActionChip(
                        label: Text(name),
                        onPressed: () => setState(() => category.text = name),
                      ),
                  ],
                ),
                const Text('Estimated Time'),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final value in [15, 30, 60, 90, 120])
                      ChoiceChip(
                        label: Text('${value}m'),
                        selected: duration.text == '$value',
                        onSelected: (_) =>
                            setState(() => duration.text = '$value'),
                      ),
                  ],
                ),
                TextFormField(
                  controller: duration,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Custom minutes (1–1440)',
                  ),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    return n == null || n < 1 || n > 1440
                        ? 'Enter 1 to 1440 minutes.'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                const Text('Priority'),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final value in ['low', 'medium', 'high'])
                      ChoiceChip(
                        label: Text(value),
                        selected: priority == value,
                        onSelected: (_) => setState(() => priority = value),
                      ),
                  ],
                ),
              ] else ...[
                const Text('Reminder Type'),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final value in ['Study', 'Task', 'Goal', 'General'])
                      ChoiceChip(
                        label: Text(value),
                        selected: category.text == value,
                        onSelected: (_) =>
                            setState(() => category.text = value),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: pickDue,
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  due == null
                      ? 'Due Date (optional)'
                      : '${due!.day}/${due!.month}/${due!.year}${widget.reminder ? ' · ${TimeOfDay.fromDateTime(due!).format(context)}' : ''}',
                ),
              ),
              if (!widget.reminder && due != null)
                TextButton(
                  onPressed: () => setState(() => due = null),
                  child: const Text('Remove due date'),
                ),
              if (widget.reminder) ...[
                const Text('Repeat'),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final value in [
                      'none',
                      'daily',
                      'weekdays',
                      'weekly',
                      'custom',
                    ])
                      ChoiceChip(
                        label: Text(
                          value == 'none'
                              ? 'Once'
                              : value == 'weekdays'
                              ? 'Mon–Fri'
                              : value,
                        ),
                        selected: repeat == value,
                        onSelected: (_) => setState(() => repeat = value),
                      ),
                  ],
                ),
                if (repeat == 'custom')
                  Wrap(
                    spacing: 4,
                    children: [
                      for (var day = 1; day <= 7; day++)
                        FilterChip(
                          label: Text(
                            const [
                              'Mon',
                              'Tue',
                              'Wed',
                              'Thu',
                              'Fri',
                              'Sat',
                              'Sun',
                            ][day - 1],
                          ),
                          selected: weekdays.contains(day),
                          onSelected: (on) => setState(() {
                            if (on) {
                              weekdays.add(day);
                            } else {
                              weekdays.remove(day);
                            }
                          }),
                        ),
                    ],
                  ),
                const Text('Advance Alert'),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final value in [0, 10, 30])
                      ChoiceChip(
                        label: Text(
                          value == 0 ? 'At time' : '${value}m before',
                        ),
                        selected: lead == value,
                        onSelected: (_) => setState(() => lead = value),
                      ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Two extra alerts, 15 minutes apart'),
                  value: extra > 0,
                  onChanged: (on) => setState(() => extra = on ? 2 : 0),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Quiet hours · 10pm–7am'),
                  subtitle: const Text(
                    'Alerts during quiet hours are skipped.',
                  ),
                  value: quiet,
                  onChanged: (on) => setState(() => quiet = on),
                ),
                if (repeat != 'none')
                  TextButton(
                    onPressed: () async {
                      final start = due ?? DateTime.now();
                      final date = await showDatePicker(
                        context: context,
                        initialDate: until ?? start,
                        firstDate: DateTime(start.year, start.month, start.day),
                        lastDate: start.add(const Duration(days: 30)),
                      );
                      if (date != null && mounted) setState(() => until = date);
                    },
                    child: Text(
                      until == null
                          ? 'Set stop date (within 30 days)'
                          : 'Stops ${until!.day}/${until!.month}/${until!.year}',
                    ),
                  ),
                if (until != null)
                  TextButton(
                    onPressed: () => setState(() => until = null),
                    child: const Text('Remove stop date'),
                  ),
              ],
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: saving ? null : save,
                  child: Text(
                    saving
                        ? 'Saving…'
                        : widget.existing == null
                        ? 'Add $kind'
                        : 'Save changes',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
