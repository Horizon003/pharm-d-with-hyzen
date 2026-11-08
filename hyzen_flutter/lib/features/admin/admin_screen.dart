import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/ui_kit.dart';
import '../content/data/content_source.dart';
import '../profile/presentation/profile_screens.dart';
import '../shell/app_shell.dart';
import 'data/admin_repository.dart';

const adminGroups = <String, List<(String, IconData, String)>>{
  'Overview': [('Statistics', Icons.insights_rounded, 'stats')],
  'Content': [
    ('Notes', Icons.menu_book_outlined, 'content/notes'),
    ('Special Books & Notes', Icons.auto_stories_outlined, 'content/special'),
    ('Lectures', Icons.play_circle_outlined, 'manage/lectures'),
    ('MCQs', Icons.quiz_outlined, 'content/mcqs'),
    ('Past Papers', Icons.history_edu_outlined, 'content/papers'),
    ('Bulk Import', Icons.upload_file_rounded, 'import'),
    ('Data Manager', Icons.storage_rounded, 'manage/data'),
  ],
  'Store': [
    ('Products', Icons.inventory_2_outlined, 'manage/products'),
    ('Orders', Icons.receipt_long_outlined, 'manage/orders'),
    ('Catalog', Icons.grid_view_rounded, 'manage/catalog'),
    ('Delivery', Icons.local_shipping_outlined, 'manage/delivery'),
  ],
  'Inbox': [('Messages', Icons.forum_outlined, 'manage/messages')],
  'Platform': [
    ('Theme studio', Icons.palette_outlined, 'manage/theme'),
    ('Announcement', Icons.campaign_outlined, 'manage/announcement'),
    (
      'Full-screen notifications',
      Icons.notifications_active_outlined,
      'manage/notice',
    ),
    ('About & Blog', Icons.people_outline_rounded, 'manage/about'),
    ('Blog posts', Icons.article_outlined, 'manage/blogs'),
    ('Section visibility', Icons.toggle_on_outlined, 'sections'),
    ('Settings', Icons.tune_rounded, 'manage/settings'),
  ],
  'Backend': [('Connection', Icons.cloud_outlined, 'manage/connection')],
};

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});
  @override
  ConsumerState<AdminScreen> createState() => _AdminState();
}

class _AdminState extends ConsumerState<AdminScreen> {
  bool busy = false;
  Future<void> sync() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final count = await ref.read(adminRepositoryProvider).syncInboxes();
      if (mounted) {
        showHSnack(context, 'Inbox refreshed · $count items processed');
      }
      ref.invalidate(contentProvider('pw_products'));
    } catch (_) {
      if (mounted) {
        showHSnack(
          context,
          'Could not refresh inbox. Check your connection and admin permissions.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(isAdminProvider)) {
      return const Scaffold(
        body: EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Administrator access required',
        ),
      );
    }
    final orders = asMapList(
          ref.watch(adminValueProvider('pw_orders')).valueOrNull,
        ),
        messages = asMapList(
          ref.watch(adminValueProvider('pw_messages')).valueOrNull,
        );
    return TabPage(
      title: 'PHARM D Admin',
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              const Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HyzenLogo(size: 52, glow: false),
                    Gap(12),
                    Text(
                      'PHARM D WITH HYZEN',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text('Admin control centre'),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.dashboard_outlined),
                title: const Text('Dashboard'),
                selected: true,
                onTap: () => Navigator.of(context).pop(),
              ),
              ListTile(
                leading: const Icon(Icons.campaign_outlined),
                title: const Text('Push Notification Center'),
                onTap: () => context.push('/admin/push'),
              ),
              for (final group in adminGroups.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Text(
                    group.key.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                for (final item in group.value)
                  ListTile(
                    leading: Icon(item.$2),
                    title: Text(item.$1),
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push(
                        item.$3 == 'stats'
                            ? '/admin/stats'
                            : '/admin/${item.$3}',
                      );
                    },
                  ),
              ],
              const Divider(),
              ListTile(
                leading: const Icon(Icons.phone_android_rounded),
                title: const Text('Student view'),
                onTap: () {
                  Navigator.of(context).pop();
                  context.go('/home');
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Log out'),
                onTap: () {
                  Navigator.of(context).pop();
                  logout(context, ref);
                },
              ),
            ],
          ),
        ),
      ),
      subtitle: 'PHARM D WITH HYZEN · Admin console',
      actions: [
        IconButton(
          tooltip: 'Student view',
          onPressed: () => context.go('/home'),
          icon: const Icon(Icons.phone_android_rounded),
        ),
      ],
      onRefresh: sync,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.list(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: .45),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const StatusPill(
                      label: 'Secure admin',
                      icon: Icons.verified_user_rounded,
                      color: HColors.success,
                    ),
                    const Gap(12),
                    Text(
                      'Admin dashboard',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const Gap(6),
                    const Text('Content, orders and your platform'),
                    const Gap(18),
                    Row(
                      children: [
                        Expanded(
                          child: _AdminMetric(
                            '${orders.length}',
                            'Orders',
                            Icons.shopping_bag_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _AdminMetric(
                            '${messages.where((m) => m['read'] != true).length}',
                            'Unread messages',
                            Icons.forum_outlined,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Gap(20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Quick actions',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh inbox',
                    onPressed: busy ? null : sync,
                    icon: const Icon(Icons.sync_rounded),
                  ),
                ],
              ),
              const Gap(10),
              LayoutBuilder(
                builder: (context, box) => GridView(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  primary: false,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount:
                        box.maxWidth < 320 ||
                            MediaQuery.textScalerOf(context).scale(1) > 1.5
                        ? 1
                        : box.maxWidth >= 800
                        ? 3
                        : 2,
                    mainAxisExtent:
                        116 *
                        MediaQuery.textScalerOf(context).scale(1).clamp(1, 1.7),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  children: [
                    for (final action in <(String, IconData, String)>[
                      (
                        'Manage content',
                        Icons.description_outlined,
                        'content/notes',
                      ),
                      ('Import content', Icons.cloud_upload_outlined, 'import'),
                      (
                        'Section visibility',
                        Icons.visibility_outlined,
                        'sections',
                      ),
                      (
                        'Products & shop',
                        Icons.shopping_bag_outlined,
                        'manage/products',
                      ),
                      (
                        'Announcements',
                        Icons.campaign_outlined,
                        'manage/announcement',
                      ),
                      (
                        'Theme settings',
                        Icons.palette_outlined,
                        'manage/theme',
                      ),
                    ])
                      InkWell(
                        onTap: () => context.push('/admin/${action.$3}'),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                action.$2,
                                color: Theme.of(context).colorScheme.primary,
                                size: 26,
                              ),
                              const Gap(12),
                              Text(
                                action.$1,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Gap(22),
              Text(
                'All controls',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Gap(10),
              for (final group in adminGroups.entries)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: Text(group.key),
                    leading: Icon(group.value.first.$2),
                    children: [
                      for (final item in group.value)
                        ListTile(
                          title: Text(item.$1),
                          leading: Icon(item.$2, size: 21),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push('/admin/${item.$3}'),
                        ),
                    ],
                  ),
                ),
              const Gap(16),
              HButton(
                label: 'Log out',
                outlined: true,
                icon: Icons.logout_rounded,
                onPressed: () => logout(context, ref),
              ),
              const Gap(20),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminMetric extends StatelessWidget {
  const _AdminMetric(this.value, this.label, this.icon);
  final String value, label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const Gap(8),
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}
