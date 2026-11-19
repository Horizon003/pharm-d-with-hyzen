import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/links.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../shell/app_shell.dart';
import '../../shop/data/shop_controllers.dart';
import '../data/content_providers.dart';
import '../domain/site_models.dart';

class BlogScreen extends ConsumerStatefulWidget {
  const BlogScreen({super.key});
  @override
  ConsumerState<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends ConsumerState<BlogScreen> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final posts = ref.watch(blogsProvider);
    final enabled = ref.watch(sectionEnabledProvider('blog'));
    final list = (posts.valueOrNull?.data ?? const <BlogPost>[])
        .where(
          (p) => '${p.title} ${p.excerpt} ${p.author}'.toLowerCase().contains(
            _query.toLowerCase(),
          ),
        )
        .toList();
    return TabPage(
      title: 'Blog',
      subtitle: 'Ideas, updates and student stories',
      onRefresh: () => refreshContent(ref, ['pw_blogs']),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: HSpace.screen),
          sliver: SliverList.list(
            children: [
              if (!enabled)
                const EmptyState(
                  icon: Icons.lock_rounded,
                  title: 'Blog is temporarily unavailable',
                )
              else ...[
                HSearchField(
                  hint: 'Search articles',
                  onChanged: (q) => setState(() => _query = q),
                ),
                const Gap(HSpace.md),
                if (!posts.hasValue && posts.isLoading) const SkeletonList(),
                if (!posts.hasValue && posts.hasError)
                  ErrorState(
                    message: 'Could not load articles.',
                    onRetry: () => refreshContent(ref, ['pw_blogs']),
                  ),
                if (posts.hasValue && list.isEmpty)
                  EmptyState(
                    icon: Icons.article_outlined,
                    title: _query.isEmpty ? 'No articles yet' : 'No matches',
                    message: 'New articles will appear here.',
                  ),
                for (final p in list)
                  ResourceTile(
                    icon: Icons.article_rounded,
                    color: HColors.info,
                    title: p.title,
                    eyebrow: p.author,
                    subtitle: HtmlText.plain(p.excerpt),
                    onTap: () =>
                        context.push('/blog/${Uri.encodeComponent(p.id)}'),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class BlogPostScreen extends ConsumerWidget {
  const BlogPostScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(blogsProvider);
    final post = async.valueOrNull?.data
        .where((p) => p.id == id || p.slug == id)
        .firstOrNull;
    return TabPage(
      title: post?.title ?? 'Article',
      onRefresh: () => refreshContent(ref, ['pw_blogs']),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: HSpace.screen),
          sliver: SliverList.list(
            children: [
              if (!ref.watch(sectionEnabledProvider('blog')))
                const EmptyState(
                  icon: Icons.lock_rounded,
                  title: 'Blog is temporarily unavailable',
                )
              else if (!async.hasValue && async.isLoading)
                const SkeletonList()
              else if (!async.hasValue && async.hasError)
                ErrorState(
                  message: 'Could not load this article.',
                  onRetry: () => refreshContent(ref, ['pw_blogs']),
                )
              else if (post == null)
                const EmptyState(
                  icon: Icons.article_outlined,
                  title: 'Article unavailable',
                  message: 'It may have been moved or unpublished.',
                )
              else ...[
                if (post.coverImage.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(HRadius.lg),
                    child: NetImage(post.coverImage, height: 210),
                  ),
                const Gap(HSpace.md),
                Text(
                  post.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Gap(HSpace.sm),
                Text(
                  [
                    post.author,
                    if (post.publishedAt != null)
                      post.publishedAt!
                          .toLocal()
                          .toIso8601String()
                          .split('T')
                          .first,
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Gap(HSpace.lg),
                HtmlText(post.contentHtml),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

IconData _socialIcon(String platform, String url) {
  final p = '$platform $url'.toLowerCase();
  if (p.contains('instagram')) return FontAwesomeIcons.instagram;
  if (p.contains('facebook')) return FontAwesomeIcons.facebook;
  if (p.contains('whatsapp') || p.contains('wa.me')) {
    return FontAwesomeIcons.whatsapp;
  }
  if (p.contains('youtube') || p.contains('youtu.be')) {
    return FontAwesomeIcons.youtube;
  }
  if (p.contains('linkedin')) return FontAwesomeIcons.linkedin;
  if (p.contains('github')) return FontAwesomeIcons.github;
  if (p.contains('tiktok')) return FontAwesomeIcons.tiktok;
  if (p.contains('telegram') || p.contains('t.me')) {
    return FontAwesomeIcons.telegram;
  }
  if (p.contains('twitter') || p.contains('x.com')) {
    return FontAwesomeIcons.xTwitter;
  }
  return Icons.language_rounded;
}

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final about = ref.watch(aboutProvider);
    final credits = [...ref.watch(creditsProvider)];
    credits.sort((a, b) {
      int rank(CreditCard c) => c.name.toLowerCase().contains('haris')
          ? 0
          : RegExp(
              'owner|founder|developer',
              caseSensitive: false,
            ).hasMatch(c.role)
          ? 1
          : c.featured
          ? 2
          : 3;
      return rank(a).compareTo(rank(b));
    });
    final owner = credits.isEmpty ? null : credits.first;
    final social = ref.watch(socialProvider);
    final data = about.valueOrNull?.data;
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    return TabPage(
      title: 'About',
      subtitle: 'PHARM D WITH HYZEN',
      onRefresh: () =>
          refreshContent(ref, ['pw_about', 'pw_credits', 'pw_social']),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: HSpace.screen),
          sliver: SliverList.list(
            children: [
              if (!ref.watch(sectionEnabledProvider('about')))
                const EmptyState(
                  icon: Icons.lock_rounded,
                  title: 'About is temporarily unavailable',
                )
              else ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        scheme.primaryContainer.withValues(alpha: .65),
                        scheme.surface,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 84,
                            height: 84,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: scheme.primary.withValues(alpha: .3),
                                width: 2,
                              ),
                            ),
                            child: ClipOval(
                              child: owner != null && owner.photo.isNotEmpty
                                  ? NetImage(owner.photo, height: 78)
                                  : Icon(
                                      Icons.person_rounded,
                                      size: 46,
                                      color: scheme.primary,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'OWNER AND DEVELOPER',
                                  style: t.textTheme.labelSmall?.copyWith(
                                    color: scheme.primary,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const Gap(7),
                                Text(
                                  owner?.name ?? 'Haris Aslam',
                                  style: t.textTheme.headlineSmall,
                                ),
                                if (owner != null &&
                                    owner.designation.isNotEmpty) ...[
                                  const Gap(4),
                                  Text(
                                    owner.designation,
                                    style: t.textTheme.bodySmall,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Gap(20),
                      Text(
                        'Built for your next chapter.',
                        style: t.textTheme.titleLarge,
                      ),
                      const Gap(8),
                      if (owner != null &&
                          HtmlText.plain(owner.description).isNotEmpty)
                        HtmlText(owner.description)
                      else if (data != null &&
                          HtmlText.plain(data.founder).isNotEmpty)
                        HtmlText(data.founder)
                      else
                        const Text(
                          'Study resources, notes and a practical PDF workspace for Pharm-D students.',
                        ),
                      if (social.isNotEmpty) ...[
                        const Gap(18),
                        Wrap(
                          spacing: 9,
                          runSpacing: 9,
                          children: [
                            for (final s in social)
                              IconButton.filledTonal(
                                tooltip: s.platform,
                                onPressed: () => openLink(context, s.url),
                                icon: FaIcon(
                                  _socialIcon(s.platform, s.url),
                                  size: 20,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const Gap(22),
                if (!about.hasValue && about.isLoading)
                  const SkeletonList(count: 2),
                if (!about.hasValue && about.hasError)
                  ErrorState(
                    message: 'Could not load our story.',
                    onRetry: () => refreshContent(ref, ['pw_about']),
                  ),
                if (data != null) ...[
                  for (final section in [
                    ('The story', data.about, Icons.auto_stories_outlined),
                    ('Our vision', data.vision, Icons.visibility_outlined),
                    ('Our mission', data.mission, Icons.school_outlined),
                  ])
                    if (HtmlText.plain(section.$2).isNotEmpty) ...[
                      PanelBlock(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  section.$3,
                                  color: scheme.primary,
                                  size: 21,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    section.$1,
                                    style: t.textTheme.titleLarge,
                                  ),
                                ),
                              ],
                            ),
                            const Gap(12),
                            HtmlText(section.$2),
                          ],
                        ),
                      ),
                      const Gap(14),
                    ],
                ],
                if (credits.length > 1) ...[
                  const SectionHeader(title: 'Contributors'),
                  const Gap(10),
                  for (final c in credits.skip(1))
                    ResourceTile(
                      icon: Icons.person_outline_rounded,
                      color: scheme.primary,
                      title: c.name,
                      subtitle: c.designation,
                      trailing: c.photo.isEmpty
                          ? null
                          : ClipOval(
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: NetImage(c.photo, height: 44),
                              ),
                            ),
                    ),
                ],
                const Gap(12),
                Text(
                  'Learn. Practise. Grow.',
                  textAlign: TextAlign.center,
                  style: t.textTheme.labelLarge?.copyWith(
                    color: scheme.primary,
                  ),
                ),
                const Gap(24),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class ContactScreen extends ConsumerStatefulWidget {
  const ContactScreen({super.key});
  @override
  ConsumerState<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends ConsumerState<ContactScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _email = TextEditingController(),
      _phone = TextEditingController(),
      _subject = TextEditingController(),
      _body = TextEditingController();
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider).valueOrNull;
    final user = ref.read(authStateProvider).valueOrNull;
    _name.text = profile?.fullName ?? user?.displayName ?? '';
    _email.text = user?.email ?? '';
    _phone.text = profile?.mobile ?? '';
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _subject, _body]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await submitContactMessage(
        ref.read(firestoreProvider),
        name: _name.text,
        email: _email.text,
        whatsapp: _phone.text,
        subject: _subject.text,
        body: _body.text,
      );
      if (!mounted) return;
      _subject.clear();
      _body.clear();
      showHSnack(context, 'Message sent to the PHARM D WITH HYZEN team');
    } on FriendlyException catch (e) {
      if (mounted) showHSnack(context, e.message, error: true);
    } catch (_) {
      if (mounted) {
        showHSnack(
          context,
          'Message could not be sent. Please try again.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(siteSettingsProvider);
    return Scaffold(
      appBar: const HTopBar(title: 'Contact us'),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(HSpace.screen),
          children: [
            const Text(
              'Questions, suggestions or a missing study file? Send the PHARM D WITH HYZEN team a message.',
            ),
            const Gap(HSpace.lg),
            if (settings.email.isNotEmpty)
              ResourceTile(
                icon: Icons.email_outlined,
                color: HColors.primary,
                title: settings.email,
                onTap: () => openLink(context, 'mailto:${settings.email}'),
              ),
            if (settings.whatsapp.isNotEmpty)
              ResourceTile(
                icon: Icons.chat_outlined,
                color: HColors.teal,
                title: 'WhatsApp',
                onTap: () => openLink(context, whatsappUrl(settings.whatsapp)),
              ),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter your name' : null,
            ),
            const Gap(HSpace.md),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: Validators.email,
            ),
            const Gap(HSpace.md),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'WhatsApp number (optional)',
              ),
            ),
            const Gap(HSpace.md),
            TextFormField(
              controller: _subject,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Subject'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter a subject' : null,
            ),
            const Gap(HSpace.md),
            TextFormField(
              controller: _body,
              minLines: 5,
              maxLines: 10,
              maxLength: 4000,
              decoration: const InputDecoration(labelText: 'Message'),
              validator: (v) => (v ?? '').trim().length < 10
                  ? 'Write at least 10 characters'
                  : null,
            ),
            const Gap(HSpace.lg),
            HButton(
              label: 'Send message',
              icon: Icons.send_rounded,
              loading: _busy,
              onPressed: _busy ? null : _send,
            ),
          ],
        ),
      ),
    );
  }
}
