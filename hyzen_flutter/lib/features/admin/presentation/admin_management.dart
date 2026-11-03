import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/palettes.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../core/widgets/surfaces.dart';
import '../../../core/utils/media_upload.dart';
import '../../../core/utils/links.dart';
import '../../../core/errors/app_error.dart';
import '../../content/data/content_source.dart';
import '../../content/data/content_providers.dart';
import '../../content/domain/site_models.dart';
import '../../shop/data/shop_controllers.dart';
import '../data/admin_repository.dart';
import 'admin_draft_preview.dart';

class AdminField {
  const AdminField(
    this.key,
    this.label, {
    this.type = 'text',
    this.options = const [],
    this.required = false,
    this.fallback,
  });
  final String key, label, type;
  final List<String> options;
  final bool required;
  final Object? fallback;
}

const productFields = [
  AdminField('name', 'Product name', required: true),
  AdminField('category', 'Category', required: true, fallback: 'General'),
  AdminField('subcategory', 'Subcategory', fallback: 'General'),
  AdminField(
    'price',
    'Price (PKR)',
    type: 'number',
    required: true,
    fallback: 0,
  ),
  AdminField('compareAtPrice', 'Original price (optional)', type: 'number'),
  AdminField(
    'stockStatus',
    'Stock status',
    type: 'choice',
    options: ['in_stock', 'low_stock', 'out_of_stock', 'preorder'],
    fallback: 'in_stock',
  ),
  AdminField('stockCount', 'Available stock', type: 'number'),
  AdminField('shortDesc', 'Short description'),
  AdminField('fullDescHtml', 'Description', type: 'html'),
  AdminField('images', 'Image URLs · one per line', type: 'images'),
  AdminField(
    'variants',
    'Options · e.g. Size: Small, Medium, Large',
    type: 'variants',
  ),
  AdminField('featured', 'Featured product', type: 'bool'),
  AdminField('hidden', 'Hide from students', type: 'bool'),
];
const blogFields = [
  AdminField('title', 'Title', required: true),
  AdminField('slug', 'Slug', required: true),
  AdminField('author', 'Author', fallback: 'Haris'),
  AdminField('excerpt', 'Excerpt', type: 'multiline'),
  AdminField('contentHtml', 'Article', type: 'html'),
  AdminField('coverImage', 'Cover image', type: 'image'),
  AdminField(
    'status',
    'Status',
    type: 'choice',
    options: ['draft', 'published'],
    fallback: 'draft',
  ),
  AdminField('publishedAt', 'Publication date (ISO)'),
];
const creditFields = [
  AdminField('name', 'Name', required: true),
  AdminField('role', 'Role', fallback: 'Creator'),
  AdminField('designation', 'Designation'),
  AdminField('description', 'Bio', type: 'html'),
  AdminField('photo', 'Profile photo', type: 'image'),
  AdminField('featured', 'Featured creator', type: 'bool'),
  AdminField('accent', 'Accent colour (#RRGGBB)'),
  AdminField('glow', 'Website highlight colour (#RRGGBB)'),
];
const socialFields = [
  AdminField(
    'platform',
    'Platform',
    type: 'choice',
    options: [
      'instagram',
      'facebook',
      'youtube',
      'tiktok',
      'linkedin',
      'website',
    ],
    fallback: 'instagram',
  ),
  AdminField('url', 'URL', type: 'url', required: true),
  AdminField('enabled', 'Visible', type: 'bool', fallback: true),
];
List<AdminField> documentFields(String section) => switch (section) {
  'catalog' => const [
    AdminField(
      'mobileColumns',
      'Phone columns',
      type: 'choice',
      options: ['1', '2'],
      fallback: 2,
    ),
    AdminField(
      'tabletColumns',
      'Tablet columns',
      type: 'choice',
      options: ['2', '3'],
      fallback: 3,
    ),
    AdminField(
      'desktopColumns',
      'Desktop columns',
      type: 'choice',
      options: ['2', '3', '4'],
      fallback: 4,
    ),
    AdminField('cardRadius', 'Card radius', type: 'number', fallback: 16),
    AdminField('gridSpacing', 'Grid spacing', type: 'number', fallback: 14),
    AdminField(
      'cardShadow',
      'Shadow',
      type: 'choice',
      options: ['none', 'soft', 'medium', 'elevated'],
      fallback: 'soft',
    ),
  ],
  'delivery' => [
    const AdminField(
      'defaultCharge',
      'Default delivery (PKR)',
      type: 'number',
      fallback: 250,
    ),
    const AdminField(
      'freeDeliveryThreshold',
      'Free delivery above (PKR)',
      type: 'number',
      fallback: 10000,
    ),
    for (final p in DeliverySettings.provinces)
      AdminField('provinceRates.$p', '$p rate', type: 'number', fallback: 250),
  ],
  'announcement' => const [
    AdminField('enabled', 'Show announcement', type: 'bool'),
    AdminField('text', 'Message', type: 'multiline', required: true),
    AdminField('linkText', 'Button text'),
    AdminField('linkUrl', 'Button link', type: 'link'),
    AdminField(
      'colourMode',
      'Colour mode',
      type: 'choice',
      options: ['theme', 'custom'],
      fallback: 'theme',
    ),
    AdminField(
      'gradient.from',
      'Start colour',
      type: 'color',
      fallback: '#045936',
    ),
    AdminField('gradient.to', 'End colour', type: 'color', fallback: '#087747'),
    AdminField('textColor', 'Text colour', type: 'color', fallback: '#ffffff'),
    AdminField('fontSize', 'Text size', type: 'number', fallback: 13),
    AdminField('heightPx', 'Height', type: 'number', fallback: 40),
    AdminField(
      'animation',
      'Message motion',
      type: 'choice',
      options: ['none', 'scroll'],
      fallback: 'none',
    ),
    AdminField(
      'speed',
      'Scroll duration (seconds)',
      type: 'number',
      fallback: 24,
    ),
  ],
  'notice' => const [
    AdminField('enabled', 'Publish notification', type: 'bool', fallback: true),
    AdminField(
      'type',
      'Type',
      type: 'choice',
      options: ['announcement', 'update', 'info'],
      fallback: 'announcement',
    ),
    AdminField('eyebrow', 'Small heading'),
    AdminField('title', 'Title', required: true),
    AdminField('body', 'Message', type: 'multiline', required: true),
    AdminField('version', 'Version label'),
    AdminField('image', 'Image', type: 'image'),
    AdminField('imageAlt', 'Image description'),
    AdminField(
      'imageFit',
      'Image fitting',
      type: 'choice',
      options: ['contain', 'cover'],
      fallback: 'contain',
    ),
    AdminField('primaryText', 'Main button text'),
    AdminField('primaryUrl', 'Main link', type: 'link'),
    AdminField('secondaryText', 'Second button text'),
    AdminField('secondaryUrl', 'Second link', type: 'link'),
    AdminField('dismissText', 'Dismiss label', fallback: 'Keep studying'),
    AdminField('expires', 'Expires at (ISO, optional)', type: 'date'),
    AdminField(
      'repeat',
      'Display frequency',
      type: 'choice',
      options: ['once', 'session'],
      fallback: 'once',
    ),
    AdminField(
      'followTheme',
      'Use student theme',
      type: 'bool',
      fallback: true,
    ),
    AdminField(
      'background',
      'Screen colour',
      type: 'color',
      fallback: '#f5f6f0',
    ),
    AdminField('card', 'Card colour', type: 'color', fallback: '#ffffff'),
    AdminField('text', 'Text colour', type: 'color', fallback: '#172b23'),
    AdminField('accent', 'Accent colour', type: 'color', fallback: '#087747'),
    AdminField(
      'buttonText',
      'Button text colour',
      type: 'color',
      fallback: '#ffffff',
    ),
    AdminField('radius', 'Card radius', type: 'number', fallback: 28),
    AdminField('fontSize', 'Font size', type: 'number', fallback: 15),
    AdminField(
      'align',
      'Alignment',
      type: 'choice',
      options: ['center', 'left'],
      fallback: 'center',
    ),
    AdminField(
      'font',
      'Font',
      type: 'choice',
      options: ['sans', 'rounded', 'serif', 'system'],
      fallback: 'rounded',
    ),
    AdminField(
      'sound',
      'Sound',
      type: 'choice',
      options: ['none', 'chime'],
      fallback: 'none',
    ),
  ],
  'about' => const [
    AdminField('about', 'Platform story', type: 'html'),
    AdminField('founder', 'Founder story', type: 'html'),
    AdminField('mission', 'Mission', type: 'html'),
    AdminField('vision', 'Vision', type: 'html'),
  ],
  'settings' => const [
    AdminField('websiteName', 'Platform name', fallback: 'PHARM D WITH HYZEN'),
    AdminField('heroTitle', 'Home headline'),
    AdminField('heroSubtitle', 'Home subtitle'),
    AdminField('email', 'Contact email'),
    AdminField('contactNumber', 'Contact phone'),
    AdminField('whatsapp', 'WhatsApp'),
    AdminField('footerText', 'Footer'),
    AdminField('currency', 'Currency', fallback: 'PKR'),
    AdminField('logoUrl', 'Logo', type: 'image'),
    AdminField('brandPlateUrl', 'Brand image', type: 'image'),
    AdminField('faviconUrl', 'Website favicon', type: 'image'),
    AdminField('seoTitle', 'Website SEO title'),
    AdminField('seoDescription', 'Website SEO description', type: 'multiline'),
    AdminField(
      'notifications',
      'Enable notifications',
      type: 'bool',
      fallback: true,
    ),
    AdminField('shopComingSoon', 'Shop coming soon', type: 'bool'),
    AdminField(
      'androidLatestVersionCode',
      'Android latest version code',
      type: 'number',
    ),
    AdminField('androidVersionName', 'Android version name'),
    AdminField('androidApkUrl', 'Android APK direct HTTPS download URL'),
    AdminField('androidSha256', 'Android APK SHA-256 (64 hex characters)'),
    AdminField(
      'androidMinVersionCode',
      'Android minimum supported version code',
      type: 'number',
    ),
    AdminField(
      'androidReleaseNotes',
      'Android update release notes',
      type: 'multiline',
    ),
    AdminField(
      'androidForceUpdate',
      'Require latest Android update',
      type: 'bool',
    ),
    AdminField('accountAd1Enabled', 'Account ad 1 visible', type: 'bool'),
    AdminField(
      'accountAd1Image',
      'Account ad 1 image URL · 16:9',
      type: 'image',
    ),
    AdminField('accountAd1Title', 'Account ad 1 title'),
    AdminField('accountAd1Subtitle', 'Account ad 1 subtitle'),
    AdminField('accountAd1Route', 'Account ad 1 route or link'),
    AdminField('accountAd2Enabled', 'Account ad 2 visible', type: 'bool'),
    AdminField(
      'accountAd2Image',
      'Account ad 2 image URL · 16:9',
      type: 'image',
    ),
    AdminField('accountAd2Title', 'Account ad 2 title'),
    AdminField('accountAd2Subtitle', 'Account ad 2 subtitle'),
    AdminField('accountAd2Route', 'Account ad 2 route or link'),
    AdminField('accountAd3Enabled', 'Account ad 3 visible', type: 'bool'),
    AdminField(
      'accountAd3Image',
      'Account ad 3 image URL · 16:9',
      type: 'image',
    ),
    AdminField('accountAd3Title', 'Account ad 3 title'),
    AdminField('accountAd3Subtitle', 'Account ad 3 subtitle'),
    AdminField('accountAd3Route', 'Account ad 3 route or link'),
  ],
  _ => const [],
};
String sectionTitle(String section) => switch (section) {
  'notice' => 'Full-screen notifications',
  'about' => 'About & Blog',
  'blogs' => 'Blog posts',
  'connection' => 'Connection',
  'data' => 'Data Manager',
  'theme' => 'Theme studio',
  _ =>
    section.isEmpty
        ? 'Admin'
        : '${section[0].toUpperCase()}${section.substring(1)}',
};
String documentKey(String section) => switch (section) {
  'notice' || 'settings' => 'pw_settings',
  'catalog' => 'pw_catalog_settings',
  _ => 'pw_$section',
};

Future<void> adminAction(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() action, {
  String message = 'Saved',
}) async {
  try {
    await action();
    if (context.mounted) showHSnack(context, message);
  } catch (e) {
    if (context.mounted) {
      showHSnack(
        context,
        e is FriendlyException
            ? e.message
            : 'Could not save. Check your connection and admin access.',
        error: true,
      );
    }
  }
}

/// Stable field controllers and identity prevent keyboard loss on form rebuilds.
class AdminForm extends StatefulWidget {
  const AdminForm({
    super.key,
    required this.fields,
    required this.initial,
    required this.onSave,
    this.saveLabel = 'Save changes',
    this.header,
    this.onPreview,
    this.onlyChanged = false,
  });
  final bool onlyChanged;
  final List<AdminField> fields;
  final Map<String, dynamic> initial;
  final Future<void> Function(Map<String, dynamic>) onSave;
  final Future<void> Function(Map<String, dynamic>)? onPreview;
  final String saveLabel;
  final Widget? header;
  @override
  State<AdminForm> createState() => _AdminFormState();
}

class _AdminFormState extends State<AdminForm> {
  final dirty = <String>{};
  final form = GlobalKey<FormState>();
  final controllers = <String, TextEditingController>{};
  final values = <String, Object?>{};
  bool busy = false;
  String? upload;
  @override
  void initState() {
    super.initState();
    for (final f in widget.fields) {
      final v = getPath(widget.initial, f.key) ?? f.fallback;
      values[f.key] = v;
      controllers[f.key] = TextEditingController(
        text: f.type == 'variants' && v is List
            ? v
                  .whereType<Map>()
                  .map(
                    (m) =>
                        '${m['name']}: ${m['options'] is List ? (m['options'] as List).join(', ') : ''}',
                  )
                  .join('\n')
            : v is List
            ? v.join('\n')
            : v == null
            ? ''
            : '$v',
      );
      controllers[f.key]!.addListener(() => dirty.add(f.key));
    }
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> collect() {
    final out = <String, dynamic>{};
    for (final f in widget.fields) {
      final text = controllers[f.key]!.text.trim();
      out[f.key] = switch (f.type) {
        'bool' => values[f.key] == true || values[f.key] == 'true',
        'number' => text.isEmpty ? null : num.tryParse(text),
        'variants' =>
          text.split('\n').where((line) => line.trim().isNotEmpty).map((line) {
            final colon = line.indexOf(':');
            return <String, dynamic>{
              'name': line.substring(0, colon).trim(),
              'options': line
                  .substring(colon + 1)
                  .split(',')
                  .map((v) => v.trim())
                  .where((v) => v.isNotEmpty)
                  .toList(),
            };
          }).toList(),
        'lines' || 'images' =>
          text
              .split('\n')
              .map((v) => v.trim())
              .where((v) => v.isNotEmpty)
              .toList(),
        'choice' => num.tryParse('${values[f.key]}') ?? values[f.key] ?? '',
        _ => text,
      };
    }
    if (widget.onlyChanged) out.removeWhere((k, v) => !dirty.contains(k));
    return out;
  }

  String? validate(AdminField f, String? input) {
    final s = (input ?? '').trim();
    if (f.required && s.isEmpty) return 'Enter ${f.label.toLowerCase()}';
    if (s.isEmpty) return null;
    if (f.type == 'variants') {
      for (final line
          in s.split('\n').where((line) => line.trim().isNotEmpty)) {
        final colon = line.indexOf(':');
        if (colon <= 0 ||
            line
                .substring(colon + 1)
                .split(',')
                .every((v) => v.trim().isEmpty)) {
          return 'Use one option per line, e.g. Size: Small, Medium, Large';
        }
      }
    }
    if (f.type == 'number' &&
        (num.tryParse(s) == null ||
            !num.parse(s).isFinite ||
            num.parse(s) < 0)) {
      return 'Enter a number of zero or more';
    }
    if (f.type == 'color' && !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(s)) {
      return 'Use a colour such as #087747';
    }
    if (f.type == 'date' && DateTime.tryParse(s) == null) {
      return 'Use an ISO date, e.g. 2026-12-01T18:00:00Z';
    }
    if (['image', 'url', 'link'].contains(f.type)) {
      if (f.type == 'link' && s.startsWith('#/')) return null;
      final u = Uri.tryParse(s);
      if (u == null || u.scheme != 'https' || u.host.isEmpty) {
        return 'Enter a complete HTTPS link';
      }
    }
    return null;
  }

  void format(TextEditingController c, String tag) {
    final sel = c.selection;
    final start = sel.start < 0 ? c.text.length : sel.start,
        end = sel.end < 0 ? start : sel.end;
    final selected = c.text.substring(start, end);
    final value = '<$tag>${selected.isEmpty ? 'Text' : selected}</$tag>';
    c.value = TextEditingValue(
      text: c.text.replaceRange(start, end, value),
      selection: TextSelection.collapsed(offset: start + value.length),
    );
  }

  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.header != null) widget.header!,
        for (final f in widget.fields)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: f.type == 'bool'
                ? SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(f.label),
                    value: values[f.key] == true || values[f.key] == 'true',
                    onChanged: (v) => setState(() {
                      values[f.key] = v;
                      dirty.add(f.key);
                    }),
                  )
                : f.type == 'choice'
                ? DropdownButtonFormField<String>(
                    initialValue: '${values[f.key] ?? f.options.first}',
                    decoration: InputDecoration(labelText: f.label),
                    items:
                        [
                              ...{
                                ...f.options,
                                '${values[f.key] ?? f.options.first}',
                              },
                            ]
                            .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)),
                            )
                            .toList(),
                    onChanged: (v) => setState(() {
                      values[f.key] = v;
                      dirty.add(f.key);
                    }),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (f.type == 'html')
                        Wrap(
                          spacing: 6,
                          children: [
                            for (final pair in [
                              ('b', 'Bold'),
                              ('i', 'Italic'),
                              ('h3', 'Heading'),
                              ('p', 'Paragraph'),
                              ('li', 'List item'),
                            ])
                              TextButton(
                                onPressed: () =>
                                    format(controllers[f.key]!, pair.$1),
                                child: Text(pair.$2),
                              ),
                          ],
                        ),
                      TextFormField(
                        key: ValueKey(f.key),
                        controller: controllers[f.key],
                        validator: (v) => validate(f, v),
                        decoration: InputDecoration(
                          labelText: f.label,
                          alignLabelWithHint: true,
                        ),
                        keyboardType: f.type == 'number'
                            ? const TextInputType.numberWithOptions(
                                decimal: true,
                              )
                            : ['url', 'link', 'image'].contains(f.type)
                            ? TextInputType.url
                            : TextInputType.multiline,
                        minLines:
                            [
                              'html',
                              'multiline',
                              'lines',
                              'images',
                              'variants',
                            ].contains(f.type)
                            ? 3
                            : 1,
                        maxLines:
                            [
                              'html',
                              'multiline',
                              'lines',
                              'images',
                              'variants',
                            ].contains(f.type)
                            ? 8
                            : 1,
                      ),
                      if (f.type == 'image' || f.type == 'images')
                        TextButton.icon(
                          onPressed: upload != null
                              ? null
                              : () async {
                                  setState(() => upload = f.key);
                                  try {
                                    final url =
                                        await MediaUpload.pickAndUpload();
                                    if (url != null && mounted) {
                                      final c = controllers[f.key]!;
                                      c.text =
                                          f.type == 'images' &&
                                              c.text.isNotEmpty
                                          ? '${c.text}\n$url'
                                          : url;
                                      setState(() {});
                                    }
                                  } catch (_) {
                                    if (context.mounted) {
                                      showHSnack(
                                        context,
                                        'Image upload failed. Retry or paste an image URL.',
                                        error: true,
                                      );
                                    }
                                  } finally {
                                    if (mounted) setState(() => upload = null);
                                  }
                                },
                          icon: upload == f.key
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.add_photo_alternate_outlined),
                          label: const Text('Upload image'),
                        ),
                      if (f.type == 'image' &&
                          controllers[f.key]!.text.startsWith('https://'))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: NetImage(
                            controllers[f.key]!.text,
                            height: 130,
                          ),
                        ),
                    ],
                  ),
          ),
        if (widget.onPreview != null)
          OutlinedButton.icon(
            onPressed: busy || upload != null
                ? null
                : () async {
                    if (!form.currentState!.validate()) return;
                    setState(() => busy = true);
                    try {
                      await widget.onPreview!(collect());
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  },
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Preview as student'),
          ),
        HButton(
          label: widget.saveLabel,
          loading: busy,
          onPressed: upload != null
              ? null
              : () async {
                  if (!form.currentState!.validate()) return;
                  setState(() => busy = true);
                  try {
                    await widget.onSave(collect());
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
        ),
      ],
    ),
  );
}

class AdminDocumentScreen extends ConsumerWidget {
  const AdminDocumentScreen({super.key, required this.section});
  final String section;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = documentKey(section), a = ref.watch(adminValueProvider(key));
    return Scaffold(
      appBar: HTopBar(
        title: sectionTitle(section),
        actions: [
          if (section == 'settings')
            IconButton(
              tooltip: 'Section visibility',
              onPressed: () => context.push('/admin/sections'),
              icon: const Icon(Icons.toggle_on_outlined),
            ),
        ],
      ),
      body: a.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorState(
          message: 'Could not load settings',
          onRetry: () => ref.invalidate(adminValueProvider(key)),
        ),
        data: (v) {
          final root = asMap(v),
              initial = section == 'notice'
                  ? asMap(root['fullScreenNotice'])
                  : root;
          return ListView(
            padding: const EdgeInsets.all(HSpace.screen),
            children: [
              if (section == 'about')
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => context.push('/admin/manage/credits'),
                      child: const Text('Team & photos'),
                    ),
                    TextButton(
                      onPressed: () => context.push('/admin/manage/social'),
                      child: const Text('Social links'),
                    ),
                    TextButton(
                      onPressed: () => context.push('/admin/manage/blogs'),
                      child: const Text('Blog posts'),
                    ),
                  ],
                ),
              AdminForm(
                key: ValueKey(section),
                onlyChanged: section != 'notice',
                fields: documentFields(section),
                initial: initial,
                saveLabel: section == 'notice'
                    ? 'Save notification'
                    : 'Save changes',
                header: section == 'notice' || section == 'announcement'
                    ? const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text(
                          'Preview the student-facing version before saving or publishing. Previewing never changes live content.',
                        ),
                      )
                    : null,
                onPreview: section == 'notice' || section == 'announcement'
                    ? (updates) => showAdminDraftPreview(
                        context,
                        section,
                        mergeAdminDraft(initial, updates),
                      )
                    : null,
                onSave: (updates) async {
                  if (section == 'notice' &&
                      updates['enabled'] == true &&
                      initial['enabled'] != true &&
                      !await confirmDialog(
                        context,
                        title: 'Publish this notification?',
                        message:
                            'Students may see this notification after the server confirms the change.',
                        confirm: 'Publish',
                      )) {
                    return;
                  }
                  if (!context.mounted) return;
                  if (section == 'announcement' &&
                      updates['enabled'] == true &&
                      initial['enabled'] != true &&
                      !await confirmDialog(
                        context,
                        title: 'Publish this announcement?',
                        message:
                            'The announcement will become visible to students after the server confirms the change.',
                        confirm: 'Publish',
                      )) {
                    return;
                  }
                  if (!context.mounted) return;
                  await adminAction(
                    context,
                    ref,
                    () async {
                      final changed = <String, dynamic>{
                        for (final e in updates.entries)
                          if (jsonEncode(getPath(initial, e.key)) !=
                              jsonEncode(e.value))
                            e.key: e.value,
                      };
                      if (section == 'notice') {
                        await ref.read(adminRepositoryProvider).patch(key, {
                          'fullScreenNotice': {
                            ...initial,
                            ...updates,
                            'id': legacyUid('notice'),
                            'enabled': updates['enabled'],
                            'publishedAt': DateTime.now()
                                .toUtc()
                                .toIso8601String(),
                          },
                        });
                      } else {
                        if (section == 'announcement' &&
                            updates.containsKey('gradient.from')) {
                          changed['backgroundColor'] = updates['gradient.from'];
                        }
                        await ref
                            .read(adminRepositoryProvider)
                            .patch(key, changed);
                      }
                      await refreshContent(ref, [key]);
                    },
                    message: section == 'notice'
                        ? (updates['enabled'] == true
                            ? 'Notification published'
                            : 'Notification saved')
                        : 'Changes saved',
                  );
                },
              ),
              if (section == 'notice')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      if (!await confirmDialog(
                        context,
                        title: 'Withdraw this notification?',
                        message:
                            'Students will stop seeing the current full-screen notification.',
                        confirm: 'Withdraw',
                        destructive: true,
                      )) {
                        return;
                      }
                      if (!context.mounted) return;
                      await adminAction(
                        context,
                        ref,
                        () => ref.read(adminRepositoryProvider).patch(key, {
                          'fullScreenNotice.enabled': false,
                        }),
                        message: 'Notification withdrawn',
                      );
                    },
                    icon: const Icon(Icons.visibility_off_outlined),
                    label: const Text('Withdraw current notification'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class AdminListScreen extends ConsumerStatefulWidget {
  const AdminListScreen({super.key, required this.section});
  final String section;
  @override
  ConsumerState<AdminListScreen> createState() => _AdminListState();
}

class _AdminListState extends ConsumerState<AdminListScreen> {
  String query = '';
  String get key => 'pw_${widget.section}';
  String? get nested => widget.section == 'credits' ? 'cards' : null;
  List<AdminField> get fields => switch (widget.section) {
    'products' => productFields,
    'blogs' => blogFields,
    'credits' => creditFields,
    'social' => socialFields,
    _ => const [],
  };
  Future<void> editItem([Map<String, dynamic>? item]) async {
    final isNew = item == null;
    final initial =
        item ??
        {
          'id': legacyUid(widget.section),
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'order': 999,
        };
    final repository = ref.read(adminRepositoryProvider);
    Future<void> commit(Map<String, dynamic> values) async {
      await repository.changeList(key, (list) {
        final current = list.where((m) => m['id'] == initial['id']).firstOrNull;
        if (!isNew && current == null) {
          throw FriendlyException(
            'This item was removed. Refresh and try again.',
          );
        }
        final next = current ?? {...initial, 'order': list.length + 1};
        final slug = values['slug'] ?? next['slug'];
        if (widget.section == 'blogs' &&
            list.any((b) => b['id'] != initial['id'] && b['slug'] == slug)) {
          throw FriendlyException('That article slug already exists.');
        }
        for (final e in values.entries) {
          next[e.key] = e.value;
        }
        next['updatedAt'] = DateTime.now().toUtc().toIso8601String();
        if (next['status'] == 'published' &&
            '${next['publishedAt'] ?? ''}'.isEmpty) {
          next['publishedAt'] = DateTime.now().toUtc().toIso8601String();
        }
        if (current == null) list.add(next);
      }, nested: nested);
      if (mounted) await refreshContent(ref, [key]);
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
        child: FractionallySizedBox(
          heightFactor: .92,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${isNew ? 'Add' : 'Edit'} ${widget.section}',
                  style: Theme.of(c).textTheme.titleLarge,
                ),
                const Gap(20),
                AdminForm(
                  fields: fields,
                  initial: initial,
                  onlyChanged: !isNew,
                  onPreview: widget.section == 'blogs'
                      ? (values) => showAdminBlogPreview(
                          c,
                          mergeAdminDraft(initial, values),
                        )
                      : null,
                  onSave: (values) async {
                    if (widget.section == 'blogs' &&
                        values['status'] == 'published' &&
                        initial['status'] != 'published' &&
                        !await confirmDialog(
                          c,
                          title: 'Publish this article?',
                          message:
                              'The article will become visible in the student blog after the save is confirmed.',
                          confirm: 'Publish',
                        )) {
                      return;
                    }
                    if (!c.mounted) return;
                    try {
                      await commit(values);
                      if (c.mounted) Navigator.pop(c);
                      if (mounted) showHSnack(context, 'Saved');
                    } catch (e) {
                      if (c.mounted) {
                        showHSnack(
                          c,
                          e is FriendlyException
                              ? e.message
                              : 'Could not save. Your edits are kept here; check connection and retry.',
                          error: true,
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> action(String action, Map<String, dynamic> item) async {
    if (action == 'edit') return editItem(item);
    if (action == 'preview' && widget.section == 'blogs') {
      return showAdminBlogPreview(context, item);
    }
    if (widget.section == 'blogs' && action == 'visibility') {
      final publish = item['status'] != 'published';
      if (!await confirmDialog(
        context,
        title: publish ? 'Publish this article?' : 'Hide this article?',
        message: publish
            ? 'Students will be able to read this article after the server confirms the change.'
            : 'The article will no longer appear in the student blog.',
        confirm: publish ? 'Publish' : 'Hide',
      )) {
        return;
      }
    }
    if (!mounted) return;
    if (action == 'delete' &&
        !await confirmDialog(
          context,
          title: 'Delete this item?',
          message: 'It will be removed from the platform.',
          confirm: 'Delete',
          destructive: true,
        )) {
      return;
    }
    if (!mounted) return;
    await adminAction(context, ref, () async {
      await ref.read(adminRepositoryProvider).changeList(key, (list) {
        final i = list.indexWhere((m) => m['id'] == item['id']);
        if (i < 0) throw FriendlyException('Item was removed. Refresh.');
        if (action == 'delete') list.removeAt(i);
        if (action == 'duplicate') {
          list.insert(i + 1, {
            ...list[i],
            'id': legacyUid('copy'),
            'name': '${list[i]['name']} (copy)',
            'featured': false,
          });
        }
        if (action == 'visibility') {
          if (widget.section == 'products') {
            list[i]['hidden'] = list[i]['hidden'] != true;
          }
          if (widget.section == 'blogs') {
            list[i]['status'] = list[i]['status'] == 'published'
                ? 'draft'
                : 'published';
          }
          if (widget.section == 'social') {
            list[i]['enabled'] = list[i]['enabled'] == false;
          }
        }
        if (action == 'up' || action == 'down') {
          final j = i + (action == 'up' ? -1 : 1);
          if (j >= 0 && j < list.length) {
            final v = list.removeAt(i);
            list.insert(j, v);
          }
        }
        for (var j = 0; j < list.length; j++) {
          list[j]['order'] = j + 1;
        }
      }, nested: nested);
      await refreshContent(ref, [key]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = ref.watch(adminValueProvider(key));
    return Scaffold(
      appBar: HTopBar(title: sectionTitle(widget.section)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: editItem,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add new'),
      ),
      body: a.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorState(
          message: 'Could not load ${widget.section}',
          onRetry: () => ref.invalidate(adminValueProvider(key)),
        ),
        data: (v) {
          final all = asMapList(nested == null ? v : asMap(v)[nested])
            ..sort(
              (a, b) => (int.tryParse('${a['order']}') ?? 0).compareTo(
                int.tryParse('${b['order']}') ?? 0,
              ),
            );
          final list = all
              .where(
                (m) =>
                    jsonEncode(m).toLowerCase().contains(query.toLowerCase()),
              )
              .toList();
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverToBoxAdapter(
                  child: HSearchField(
                    hint: 'Search ${widget.section}',
                    onChanged: (v) => setState(() => query = v),
                  ),
                ),
              ),
              if (widget.section == 'credits')
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: DropdownButtonFormField<String>(
                      initialValue: '${asMap(v)['layout'] ?? 'stack'}',
                      decoration: const InputDecoration(
                        labelText: 'Website team layout',
                      ),
                      items:
                          [
                                ...{
                                  'stack',
                                  'grid2',
                                  'grid3',
                                  '${asMap(v)['layout'] ?? 'stack'}',
                                },
                              ]
                              .map(
                                (s) =>
                                    DropdownMenuItem(value: s, child: Text(s)),
                              )
                              .toList(),
                      onChanged: (value) => adminAction(
                        context,
                        ref,
                        () => ref.read(adminRepositoryProvider).patch(key, {
                          'layout': value,
                        }),
                      ),
                    ),
                  ),
                ),
              if (list.isEmpty)
                const SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'Nothing here yet',
                    message: 'Add your first item with the button below.',
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                sliver: SliverList.builder(
                  itemCount: list.length,
                  itemBuilder: (c, i) {
                    final m = list[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: HCard(
                        onTap: () => editItem(m),
                        child: Row(
                          children: [
                            IconBadge(
                              icon: widget.section == 'products'
                                  ? Icons.inventory_2_outlined
                                  : widget.section == 'blogs'
                                  ? Icons.article_outlined
                                  : Icons.person_outline_rounded,
                              color: HColors.primary,
                            ),
                            const Gap(12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${m['name'] ?? m['title'] ?? m['platform'] ?? 'Item'}',
                                    style: Theme.of(c).textTheme.titleSmall,
                                  ),
                                  Text(
                                    widget.section == 'products'
                                        ? '${money(num.tryParse('${m['price']}') ?? 0)} · ${m['stockStatus'] ?? ''}'
                                        : '${m['status'] ?? m['role'] ?? m['url'] ?? ''}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (m['hidden'] == true) const Text('Hidden'),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (s) => action(s, m),
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                if (widget.section == 'blogs')
                                  const PopupMenuItem(
                                    value: 'preview',
                                    child: Text('Preview as student'),
                                  ),
                                if ([
                                  'products',
                                  'blogs',
                                  'social',
                                ].contains(widget.section))
                                  const PopupMenuItem(
                                    value: 'visibility',
                                    child: Text('Change visibility'),
                                  ),
                                if (widget.section == 'products')
                                  const PopupMenuItem(
                                    value: 'duplicate',
                                    child: Text('Duplicate'),
                                  ),
                                const PopupMenuItem(
                                  value: 'up',
                                  child: Text('Move up'),
                                ),
                                const PopupMenuItem(
                                  value: 'down',
                                  child: Text('Move down'),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
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
        },
      ),
    );
  }
}

class AdminOrdersScreen extends ConsumerStatefulWidget {
  const AdminOrdersScreen({super.key});
  @override
  ConsumerState<AdminOrdersScreen> createState() => _OrdersState();
}

const orderStatuses = [
  'Pending',
  'Processing',
  'Paid',
  'Completed',
  'Cancelled',
  'Refunded',
];

class _OrdersState extends ConsumerState<AdminOrdersScreen> {
  String query = '', status = 'All';
  bool syncing = false;
  Future<void> sync() async {
    if (syncing) return;
    setState(() => syncing = true);
    await adminAction(context, ref, () async {
      await ref.read(adminRepositoryProvider).syncInboxes();
    });
    if (mounted) setState(() => syncing = false);
  }

  Future<void> detail(Map<String, dynamic> o) async {
    final tracking = TextEditingController(text: '${o['trackingId'] ?? ''}');
    var selected = '${o['status'] ?? 'Pending'}';
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${o['orderNumber'] ?? o['id']}',
                  style: Theme.of(c).textTheme.headlineSmall,
                ),
                const Gap(16),
                SelectableText(
                  '${asMap(o['customer'])['firstName'] ?? ''} ${asMap(o['customer'])['lastName'] ?? ''}\n${asMap(o['customer'])['phone'] ?? ''}\n${asMap(o['customer'])['email'] ?? ''}\n${asMap(o['address']).values.join(', ')}',
                ),
                const Gap(16),
                for (final item in asMapList(o['items']))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${item['name']} × ${item['qty']}'),
                    trailing: Text(
                      money(
                        (num.tryParse('${item['price']}') ?? 0) *
                            (num.tryParse('${item['qty']}') ?? 0),
                      ),
                    ),
                  ),
                Text(
                  'Total ${money(num.tryParse('${asMap(o['totals'])['grandTotal']}') ?? 0)}',
                  style: Theme.of(c).textTheme.titleLarge,
                ),
                const Gap(16),
                DropdownButtonFormField<String>(
                  initialValue: selected,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items:
                      [
                            ...{...orderStatuses, selected},
                          ]
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                  onChanged: (s) => set(() => selected = s!),
                ),
                const Gap(16),
                TextField(
                  controller: tracking,
                  decoration: const InputDecoration(labelText: 'Tracking ID'),
                ),
                const Gap(20),
                HButton(
                  label: 'Update order',
                  onPressed: () async {
                    await adminAction(
                      context,
                      ref,
                      () => ref.read(adminRepositoryProvider).updateOrder(
                        '${o['id']}',
                        {
                          'status': selected,
                          'trackingId': tracking.text.trim(),
                        },
                      ),
                      message: 'Order updated',
                    );
                    if (c.mounted) Navigator.pop(c);
                  },
                ),
                const Gap(8),
                OutlinedButton.icon(
                  onPressed: () => adminAction(context, ref, () async {
                    const escape = HtmlEscape();
                    final rows = asMapList(o['items'])
                        .map(
                          (i) =>
                              '<tr><td>${escape.convert('${i['name']}')}</td><td>${i['qty']}</td><td>${i['price']}</td></tr>',
                        )
                        .join();
                    await MediaUpload.exportText(
                      'Invoice_${o['orderNumber'] ?? o['id']}.html',
                      '<!doctype html><meta charset="utf-8"><title>Invoice</title><style>body{font:16px sans-serif;max-width:800px;margin:40px}td{padding:12px;border-bottom:1px solid #ddd}table{width:100%}</style><h1>PHARM D WITH HYZEN</h1><h2>Invoice ${escape.convert('${o['orderNumber']}')}</h2><p>${escape.convert(asMap(o['customer']).values.join(' · '))}</p><p>${escape.convert(asMap(o['address']).values.join(', '))}</p><table>$rows</table><h3>Total ${money(num.tryParse('${asMap(o['totals'])['grandTotal']}') ?? 0)}</h3><p>Status: ${escape.convert(selected)}</p>',
                      mime: 'text/html',
                    );
                  }, message: 'Invoice exported'),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Export invoice'),
                ),
                TextButton(
                  onPressed: () async {
                    if (await confirmDialog(
                          c,
                          title: 'Delete order?',
                          message:
                              'The order and verification link will be removed.',
                          confirm: 'Delete',
                          destructive: true,
                        ) &&
                        c.mounted &&
                        context.mounted) {
                      await adminAction(
                        c,
                        ref,
                        () => ref
                            .read(adminRepositoryProvider)
                            .updateOrder('${o['id']}', {}, remove: true),
                      );
                      if (c.mounted) Navigator.pop(c);
                    }
                  },
                  child: const Text('Delete order'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    tracking.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = ref.watch(adminValueProvider('pw_orders'));
    return Scaffold(
      appBar: HTopBar(
        title: 'Orders',
        actions: [
          IconButton(
            tooltip: 'Import new orders & messages',
            onPressed: syncing ? null : sync,
            icon: syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
          ),
          IconButton(
            tooltip: 'Export orders CSV',
            onPressed: () => adminAction(context, ref, () async {
              final rows = asMapList(a.valueOrNull);
              String cell(Object? v) => '"${'$v'.replaceAll('"', '""')}"';
              await MediaUpload.exportText(
                'hyzen_orders.csv',
                'Order,Status,Tracking,Name,Phone,City,Total,Date\r\n${rows.map((o) => [o['orderNumber'], o['status'], o['trackingId'], '${asMap(o['customer'])['firstName'] ?? ''} ${asMap(o['customer'])['lastName'] ?? ''}', asMap(o['customer'])['phone'], asMap(o['address'])['city'], asMap(o['totals'])['grandTotal'], o['createdAt']].map(cell).join(',')).join('\r\n')}',
                mime: 'text/csv',
              );
            }),
            icon: const Icon(Icons.download_rounded),
          ),
        ],
      ),
      body: a.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorState(
          message: 'Could not load orders',
          onRetry: () => ref.invalidate(adminValueProvider('pw_orders')),
        ),
        data: (v) {
          final list =
              asMapList(v)
                  .where(
                    (o) =>
                        (status == 'All' || o['status'] == status) &&
                        jsonEncode(
                          o,
                        ).toLowerCase().contains(query.toLowerCase()),
                  )
                  .toList()
                ..sort(
                  (a, b) => '${b['createdAt']}'.compareTo('${a['createdAt']}'),
                );
          return RefreshIndicator(
            onRefresh: sync,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                HSearchField(
                  hint: 'Order, name, phone or tracking',
                  onChanged: (v) => setState(() => query = v),
                ),
                const Gap(12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  items: ['All', ...orderStatuses]
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (s) => setState(() => status = s!),
                ),
                const Gap(20),
                if (list.isEmpty)
                  const EmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: 'No orders found',
                    message: 'Pull to import the website order inbox.',
                  ),
                for (final o in list)
                  ResourceTile(
                    icon: Icons.receipt_long_outlined,
                    color: HColors.primary,
                    eyebrow: '${o['status'] ?? ''}',
                    title: '${o['orderNumber'] ?? o['id']}',
                    subtitle:
                        '${asMap(o['customer'])['firstName'] ?? ''} · ${money(num.tryParse('${asMap(o['totals'])['grandTotal']}') ?? 0)}',
                    onTap: () => detail(o),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class AdminMessagesScreen extends ConsumerWidget {
  const AdminMessagesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(adminValueProvider('pw_messages'));
    return Scaffold(
      appBar: HTopBar(
        title: 'Messages',
        actions: [
          IconButton(
            tooltip: 'Import new messages',
            onPressed: () => adminAction(context, ref, () async {
              await ref.read(adminRepositoryProvider).syncInboxes();
            }),
            icon: const Icon(Icons.sync_rounded),
          ),
        ],
      ),
      body: a.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorState(
          message: 'Could not load messages',
          onRetry: () => ref.invalidate(adminValueProvider('pw_messages')),
        ),
        data: (v) {
          final list = asMapList(
            v,
          )..sort((a, b) => '${b['createdAt']}'.compareTo('${a['createdAt']}'));
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.mail_outline_rounded,
              title: 'Inbox is clear',
              message: 'Import messages with the sync button.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: list.length,
            itemBuilder: (c, i) {
              final m = list[i];
              return ResourceTile(
                icon: m['read'] == true
                    ? Icons.drafts_outlined
                    : Icons.mark_email_unread_outlined,
                color: HColors.primary,
                eyebrow: '${m['name']} · ${m['read'] == true ? 'Read' : 'New'}',
                title: '${m['subject'] ?? 'Message'}',
                subtitle: '${m['body'] ?? ''}',
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (c) => SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${m['name']}',
                          style: Theme.of(c).textTheme.titleLarge,
                        ),
                        SelectableText(
                          '${m['email']}\n${m['whatsapp'] ?? ''}\n\n${m['subject'] ?? ''}\n\n${m['body'] ?? ''}',
                        ),
                        const Gap(20),
                        HButton(
                          label: m['read'] == true
                              ? 'Mark unread'
                              : 'Mark read',
                          onPressed: () => adminAction(context, ref, () async {
                            await ref.read(adminRepositoryProvider).changeList(
                              'pw_messages',
                              (l) {
                                final row = l
                                    .where((r) => r['id'] == m['id'])
                                    .firstOrNull;
                                if (row != null) {
                                  row['read'] = m['read'] != true;
                                }
                              },
                            );
                            if (c.mounted) Navigator.pop(c);
                          }),
                        ),
                        const Gap(12),
                        OutlinedButton.icon(
                          onPressed: () => openLink(
                            context,
                            'mailto:${m['email']}?subject=${Uri.encodeComponent('Re: ${m['subject'] ?? 'your message'}')}',
                          ),
                          icon: const Icon(Icons.reply_rounded),
                          label: const Text('Reply by email'),
                        ),
                        if ('${m['whatsapp'] ?? ''}'.isNotEmpty)
                          TextButton(
                            onPressed: () => openLink(
                              context,
                              'https://wa.me/${'${m['whatsapp']}'.replaceAll(RegExp(r'[^0-9]'), '').replaceFirst(RegExp(r'^0'), '92')}',
                            ),
                            child: const Text('Open WhatsApp'),
                          ),
                        TextButton(
                          onPressed: () async {
                            if (await confirmDialog(
                                  c,
                                  title: 'Delete message?',
                                  message:
                                      'This removes the message from the inbox.',
                                  confirm: 'Delete',
                                  destructive: true,
                                ) &&
                                context.mounted) {
                              await adminAction(
                                context,
                                ref,
                                () => ref
                                    .read(adminRepositoryProvider)
                                    .changeList(
                                      'pw_messages',
                                      (l) => l.removeWhere(
                                        (r) => r['id'] == m['id'],
                                      ),
                                    ),
                              );
                              if (c.mounted) Navigator.pop(c);
                            }
                          },
                          child: const Text('Delete message'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class AdminStatsScreen extends ConsumerWidget {
  const AdminStatsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = asMapList(
          ref.watch(adminValueProvider('pw_orders')).valueOrNull,
        ),
        stats = asMap(ref.watch(adminValueProvider('pw_stats')).valueOrNull),
        users = asMapList(
          ref.watch(adminValueProvider('pw_users')).valueOrNull,
        );
    final revenue = orders
        .where(
          (o) => !['Cancelled', 'Rejected', 'Refunded'].contains(o['status']),
        )
        .fold<num>(
          0,
          (n, o) =>
              n + (num.tryParse('${asMap(o['totals'])['grandTotal']}') ?? 0),
        );
    final sold = <String, int>{};
    for (final o in orders) {
      for (final i in asMapList(o['items'])) {
        sold['${i['name']}'] =
            (sold['${i['name']}'] ?? 0) + (int.tryParse('${i['qty']}') ?? 0);
      }
    }
    final best = sold.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Scaffold(
      appBar: const HTopBar(title: 'Statistics'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          HeroPanel(
            eyebrow: 'Store performance',
            title: money(revenue),
            subtitle:
                'Revenue excluding cancelled, rejected and refunded orders',
            icon: Icons.insights_rounded,
          ),
          const Gap(20),
          for (final pair in [
            ('Orders', '${orders.length}'),
            ('Website students', '${users.length}'),
            ('Website visits', '${stats['visits'] ?? 0}'),
            ('PDF downloads', '${stats['downloads'] ?? 0}'),
            (
              'Best seller',
              best.isEmpty
                  ? 'No sales yet'
                  : '${best.first.key} · ${best.first.value} sold',
            ),
          ])
            ResourceTile(
              icon: Icons.bar_chart_rounded,
              color: HColors.primary,
              title: pair.$1,
              subtitle: pair.$2,
              trailing: const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}

class AdminConnectionScreen extends ConsumerStatefulWidget {
  const AdminConnectionScreen({super.key});
  @override
  ConsumerState<AdminConnectionScreen> createState() => _ConnectionState();
}

class _ConnectionState extends ConsumerState<AdminConnectionScreen> {
  String? status;
  bool busy = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const HTopBar(title: 'Connection'),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        HeroPanel(
          eyebrow: 'Connected services',
          title: 'Firebase + Cloudinary',
          subtitle: ref.watch(firebaseReadyProvider)
              ? 'Firebase initialized'
              : 'Firebase unavailable',
          icon: Icons.cloud_done_outlined,
        ),
        const Gap(20),
        ResourceTile(
          icon: Icons.verified_user_outlined,
          color: HColors.primary,
          title: 'Administrator access',
          subtitle: ref.watch(isAdminProvider)
              ? 'Authorized admin account'
              : 'Access denied',
          trailing: const SizedBox.shrink(),
        ),
        const ResourceTile(
          icon: Icons.photo_library_outlined,
          color: HColors.teal,
          title: 'Cloudinary media',
          subtitle: 'Photo uploads use your website’s unsigned preset.',
          trailing: SizedBox.shrink(),
        ),
        const Gap(16),
        if (status != null) Text(status!),
        HButton(
          label: 'Test server connection',
          loading: busy,
          onPressed: () async {
            setState(() => busy = true);
            try {
              await ref.read(adminRepositoryProvider).read('pw_settings');
              if (mounted) setState(() => status = 'Server read succeeded.');
            } catch (_) {
              if (mounted) {
                setState(
                  () => status =
                      'Server read failed. Check your connection and Firebase rules.',
                );
              }
            } finally {
              if (mounted) setState(() => busy = false);
            }
          },
        ),
      ],
    ),
  );
}

class AdminDataScreen extends ConsumerStatefulWidget {
  const AdminDataScreen({super.key});
  @override
  ConsumerState<AdminDataScreen> createState() => _DataState();
}

class _DataState extends ConsumerState<AdminDataScreen> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const HTopBar(title: 'Data Manager'),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const HeroPanel(
          eyebrow: 'Data tools',
          title: 'Keep your content organised.',
          subtitle: 'Export a backup before making large changes.',
          icon: Icons.storage_rounded,
        ),
        const Gap(20),
        HButton(
          label: 'Export full backup',
          loading: busy,
          onPressed: () async {
            setState(() => busy = true);
            await adminAction(context, ref, () async {
              final backup = await ref.read(adminRepositoryProvider).backup();
              await MediaUpload.exportText(
                'hyzen_backup.json',
                const JsonEncoder.withIndent('  ').convert(backup),
                mime: 'application/json',
              );
            }, message: 'Backup exported');
            if (mounted) setState(() => busy = false);
          },
        ),
        const Gap(12),
        OutlinedButton.icon(
          icon: const Icon(Icons.restore_rounded),
          label: const Text('Restore JSON backup'),
          onPressed: busy
              ? null
              : () async {
                  try {
                    final selected = await MediaUpload.channel
                        .invokeListMethod<dynamic>('pickDataFiles');
                    if (selected == null || selected.length != 1) {
                      throw FriendlyException('Choose one JSON backup.');
                    }
                    final value = selected.first as Map;
                    final decoded = jsonDecode(
                      utf8.decode(value['bytes'] as List<int>),
                    );
                    if (decoded is! Map) {
                      throw FriendlyException('Invalid backup.');
                    }
                    final backup = Map<String, dynamic>.from(decoded);
                    if (!context.mounted) return;
                    final confirmed = await confirmDialog(
                      context,
                      title: 'Restore ${backup.length} data sections?',
                      message:
                          'Selected sections will replace the current server data. Export a backup first.',
                      confirm: 'Restore',
                      destructive: true,
                    );
                    if (!confirmed || !context.mounted) return;
                    setState(() => busy = true);
                    await adminAction(
                      context,
                      ref,
                      () => ref.read(adminRepositoryProvider).restore(backup),
                      message: 'Backup restored',
                    );
                    for (final k in publicContentKeys) {
                      ref.invalidate(contentProvider(k));
                    }
                    if (mounted) setState(() => busy = false);
                  } catch (e) {
                    if (context.mounted) {
                      showHSnack(
                        context,
                        e is FriendlyException
                            ? e.message
                            : 'Choose a valid JSON backup.',
                        error: true,
                      );
                    }
                  }
                },
        ),
        const Gap(20),
        ResourceTile(
          icon: Icons.upload_file_rounded,
          color: HColors.teal,
          title: 'Bulk academic import',
          subtitle: 'Preview rows before adding to your libraries',
          onTap: () => context.push('/admin/import'),
        ),
        ResourceTile(
          icon: Icons.history_rounded,
          color: HColors.primary,
          title: 'Import history',
          onTap: () => context.push('/admin/manage/history'),
        ),
      ],
    ),
  );
}

class AdminHistoryScreen extends ConsumerWidget {
  const AdminHistoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(adminValueProvider('pw_import_history'));
    return Scaffold(
      appBar: const HTopBar(title: 'Import history'),
      body: a.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorState(
          message: 'Could not load history',
          onRetry: () =>
              ref.invalidate(adminValueProvider('pw_import_history')),
        ),
        data: (v) {
          final l = asMapList(v);
          return l.isEmpty
              ? const EmptyState(
                  icon: Icons.history_rounded,
                  title: 'No imports yet',
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    for (final m in l)
                      ResourceTile(
                        icon: Icons.upload_file_rounded,
                        color: HColors.primary,
                        title:
                            '${m['added'] ?? 0} added · ${m['skipped'] ?? 0} skipped',
                        subtitle:
                            '${m['files'] ?? m['fileName'] ?? ''}\n${m['createdAt'] ?? ''}',
                        trailing: const SizedBox.shrink(),
                      ),
                  ],
                );
        },
      ),
    );
  }
}

class AdminThemeScreen extends ConsumerStatefulWidget {
  const AdminThemeScreen({super.key});
  @override
  ConsumerState<AdminThemeScreen> createState() => _ThemeState();
}

class _ThemeState extends ConsumerState<AdminThemeScreen> {
  String selected = 'green';
  @override
  Widget build(BuildContext context) {
    final a = ref.watch(adminValueProvider('pw_settings'));
    return Scaffold(
      appBar: const HTopBar(title: 'Theme studio'),
      body: a.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorState(
          message: 'Could not load themes',
          onRetry: () => ref.invalidate(adminValueProvider('pw_settings')),
        ),
        data: (v) {
          final settings = asMap(v);
          final appearance = asMap(
            asMap(settings['themeAppearance'])[selected],
          );
          final logo = asMap(settings['themeLogos'])[selected];
          final initial = {
            'logo': logo == '__default' ? '' : logo ?? '',
            'ring': appearance['ring'] ?? '#dff4e8',
            'glow': appearance['glow'] ?? '#087747',
            'glitter': appearance['glitter'] ?? '#087747',
            'defaultTheme': settings['appTheme'] ?? 'green',
          };
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in brandPalettes.entries)
                    ChoiceChip(
                      label: Text(e.value.$1),
                      selected: selected == e.key,
                      onSelected: (_) => setState(() => selected = e.key),
                      avatar: CircleAvatar(
                        backgroundColor: e.value.$2,
                        radius: 9,
                      ),
                    ),
                ],
              ),
              const Gap(20),
              HCard(
                color: brandPalettes[selected]!.$2,
                child: Row(
                  children: [
                    const Icon(Icons.palette_outlined, color: Colors.white),
                    const Gap(12),
                    Expanded(
                      child: Text(
                        brandPalettes[selected]!.$1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(20),
              AdminForm(
                key: ValueKey(selected),
                fields: [
                  const AdminField('logo', 'Theme logo', type: 'image'),
                  const AdminField(
                    'ring',
                    'Website ring colour',
                    type: 'color',
                  ),
                  const AdminField(
                    'glow',
                    'Website highlight colour',
                    type: 'color',
                  ),
                  const AdminField(
                    'glitter',
                    'Website star colour',
                    type: 'color',
                  ),
                  AdminField(
                    'defaultTheme',
                    'Default app palette',
                    type: 'choice',
                    options: brandPalettes.keys.toList(),
                    fallback: 'green',
                  ),
                ],
                initial: initial,
                onSave: (m) => adminAction(
                  context,
                  ref,
                  () => ref.read(adminRepositoryProvider).patch('pw_settings', {
                    'themeLogos.$selected': '${m['logo']}'.isEmpty
                        ? '__default'
                        : m['logo'],
                    'themeAppearance.$selected.ring': m['ring'],
                    'themeAppearance.$selected.glow': m['glow'],
                    'themeAppearance.$selected.glitter': m['glitter'],
                    'appTheme': m['defaultTheme'],
                  }),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class AdminLecturesScreen extends ConsumerStatefulWidget {
  const AdminLecturesScreen({super.key});
  @override
  ConsumerState<AdminLecturesScreen> createState() => _LecturesState();
}

class _LecturesState extends ConsumerState<AdminLecturesScreen> {
  final path = <String>[], trail = <String>[];
  final children = ['semesters', 'subjects', 'topics'];
  final labels = ['Professional year', 'Semester', 'Subject', 'Lecture'];
  List<Map<String, dynamic>> at(List<Map<String, dynamic>> tree) {
    var list = tree;
    for (var i = 0; i < path.length; i++) {
      final node = list.where((m) => m['id'] == path[i]).firstOrNull;
      if (node == null) {
        throw FriendlyException('Item moved or removed. Go back and refresh.');
      }
      final next = asMapList(node[children[i]]);
      node[children[i]] = next;
      list = next;
    }
    return list;
  }

  Future<void> edit([Map<String, dynamic>? item]) async {
    final depth = path.length;
    final key = depth == 3 ? 'title' : 'label';
    final initial = item ?? {'id': legacyUid('lecture'), 'published': true};
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
        child: FractionallySizedBox(
          heightFactor: .9,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: AdminForm(
              fields: [
                AdminField(key, labels[depth], required: true),
                const AdminField(
                  'published',
                  'Published',
                  type: 'bool',
                  fallback: true,
                ),
                if (depth == 3) ...[
                  const AdminField(
                    'youtubeUrl',
                    'YouTube video URL',
                    type: 'url',
                  ),
                  const AdminField(
                    'playlistUrl',
                    'YouTube playlist URL',
                    type: 'url',
                  ),
                  const AdminField(
                    'externalUrl',
                    'External video URL',
                    type: 'url',
                  ),
                  const AdminField('speaker', 'Speaker'),
                  const AdminField(
                    'durationMin',
                    'Duration in minutes',
                    type: 'number',
                  ),
                ],
              ],
              initial: initial,
              onSave: (m) async {
                if (depth == 3 &&
                    [
                      'youtubeUrl',
                      'playlistUrl',
                      'externalUrl',
                    ].every((k) => '${m[k] ?? ''}'.isEmpty)) {
                  showHSnack(c, 'Add a video or playlist link.', error: true);
                  return;
                }
                Navigator.pop(c, m);
              },
            ),
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    await adminAction(
      context,
      ref,
      () => ref.read(adminRepositoryProvider).changeList('pw_lectures_tree', (
        tree,
      ) {
        final list = at(tree);
        final current = list.where((m) => m['id'] == initial['id']).firstOrNull;
        if (item != null && current == null) {
          throw FriendlyException('This item was removed.');
        }
        if (current != null) {
          current.addAll(result);
        } else {
          list.add({
            ...initial,
            ...result,
            'order': list.length + 1,
            if (depth < 3) children[depth]: [],
          });
        }
      }),
    );
    ref.invalidate(contentProvider('pw_lectures_tree'));
  }

  Future<void> action(String action, Map<String, dynamic> item) async {
    if (action == 'edit') return edit(item);
    if (action == 'delete' &&
        !await confirmDialog(
          context,
          title: 'Delete ${labels[path.length].toLowerCase()}?',
          message: 'Its nested content will also be removed.',
          confirm: 'Delete',
          destructive: true,
        )) {
      return;
    }
    if (!mounted) return;
    await adminAction(
      context,
      ref,
      () => ref.read(adminRepositoryProvider).changeList('pw_lectures_tree', (
        tree,
      ) {
        final list = at(tree);
        final i = list.indexWhere((m) => m['id'] == item['id']);
        if (i < 0) return;
        if (action == 'delete') list.removeAt(i);
        if (action == 'publish') {
          list[i]['published'] = list[i]['published'] == false;
        }
        if (action == 'up' || action == 'down') {
          final j = i + (action == 'up' ? -1 : 1);
          if (j >= 0 && j < list.length) {
            final node = list.removeAt(i);
            list.insert(j, node);
          }
        }
        for (var j = 0; j < list.length; j++) {
          list[j]['order'] = j + 1;
        }
      }),
    );
    ref.invalidate(contentProvider('pw_lectures_tree'));
  }

  void back() {
    setState(() {
      path.removeLast();
      trail.removeLast();
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = ref.watch(adminValueProvider('pw_lectures_tree'));
    return PopScope(
      canPop: path.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && path.isNotEmpty) back();
      },
      child: Scaffold(
        appBar: HTopBar(
          title: trail.isEmpty ? 'Manage lectures' : trail.last,
          onBack: path.isEmpty ? null : back,
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: edit,
          icon: const Icon(Icons.add),
          label: Text('Add ${labels[path.length]}'),
        ),
        body: a.when(
          loading: () => const SkeletonList(),
          error: (e, _) => ErrorState(
            message: 'Could not load lectures',
            onRetry: () =>
                ref.invalidate(adminValueProvider('pw_lectures_tree')),
          ),
          data: (v) {
            List<Map<String, dynamic>> list;
            try {
              list = at(asMapList(v));
            } catch (e) {
              return ErrorState(
                message: 'This item has changed.',
                onRetry: () => setState(() {
                  path.clear();
                  trail.clear();
                }),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              children: [
                Text(
                  trail.join(' › '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Gap(16),
                if (list.isEmpty)
                  const EmptyState(
                    icon: Icons.video_library_outlined,
                    title: 'No content yet',
                  ),
                for (final node in list)
                  ResourceTile(
                    icon: path.length == 3
                        ? Icons.play_circle_outline
                        : Icons.folder_outlined,
                    color: HColors.primary,
                    eyebrow: node['published'] == false
                        ? 'Hidden'
                        : 'Published',
                    title:
                        '${node[path.length == 3 ? 'title' : 'label'] ?? 'Untitled'}',
                    onTap: path.length == 3
                        ? () => edit(node)
                        : () => setState(() {
                            path.add('${node['id']}');
                            trail.add('${node['label']}');
                          }),
                    trailing: PopupMenuButton<String>(
                      onSelected: (s) => action(s, node),
                      itemBuilder: (_) => [
                        for (final pair in [
                          ('edit', 'Edit'),
                          ('publish', 'Change visibility'),
                          ('up', 'Move up'),
                          ('down', 'Move down'),
                          ('delete', 'Delete'),
                        ])
                          PopupMenuItem(value: pair.$1, child: Text(pair.$2)),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
