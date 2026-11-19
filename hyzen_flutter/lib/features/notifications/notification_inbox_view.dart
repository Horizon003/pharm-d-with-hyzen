import 'package:flutter/material.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/polish_ui.dart';
import '../../core/widgets/surfaces.dart';

class NotificationInboxView extends StatefulWidget {
  const NotificationInboxView({
    super.key,
    required this.items,
    required this.onOpen,
  });
  final List<Map<String, dynamic>> items;
  final ValueChanged<Map<String, dynamic>> onOpen;
  @override
  State<NotificationInboxView> createState() => _NotificationInboxViewState();
}

class _NotificationInboxViewState extends State<NotificationInboxView> {
  bool _unreadOnly = false;
  @override
  Widget build(BuildContext context) {
    final unread = widget.items.where((m) => m['read'] != true).length;
    final list = _unreadOnly
        ? widget.items.where((m) => m['read'] != true).toList()
        : widget.items;
    final text = Theme.of(context).textTheme;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE5DDF7), Color(0xFFFFECD8)],
                    ),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: Colors.white),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Your updates', style: text.headlineMedium),
                            const SizedBox(height: 6),
                            Text(
                              unread == 0
                                  ? 'All caught up. Make time for your next goal.'
                                  : '$unread unread · Study reminders and new resources',
                              style: text.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const HAssetIcon('icon-bell', size: 58),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('All updates'),
                      selected: !_unreadOnly,
                      onSelected: (_) => setState(() => _unreadOnly = false),
                    ),
                    ChoiceChip(
                      label: Text('Unread · $unread'),
                      selected: _unreadOnly,
                      onSelected: (_) => setState(() => _unreadOnly = true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (list.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const HAssetIcon('icon-bell', size: 72),
                    const SizedBox(height: 16),
                    Text('You’re up to date', style: text.headlineSmall),
                    const SizedBox(height: 8),
                    const Text(
                      'Announcements and study reminders will appear here.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
            sliver: SliverList.builder(
              itemCount: list.length,
              itemBuilder: (c, i) {
                final m = list[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: HCard(
                    onTap: () => widget.onOpen(m),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const HAssetIcon('icon-bell', size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m['read'] == true ? 'Read' : 'New update',
                                style: text.labelMedium,
                              ),
                              const SizedBox(height: 4),
                              Text('${m['title']}', style: text.titleMedium),
                              const SizedBox(height: 6),
                              Text('${m['body']}', style: text.bodyMedium),
                            ],
                          ),
                        ),
                        if (m['read'] != true)
                          const Padding(
                            padding: EdgeInsets.only(left: 8, top: 4),
                            child: Icon(
                              Icons.circle,
                              size: 7,
                              color: HColors.ink,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
