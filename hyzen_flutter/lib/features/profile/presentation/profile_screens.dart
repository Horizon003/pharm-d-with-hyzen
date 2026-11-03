import 'dart:async';
import 'profile_promotions.dart';
import '../../academics/data/drive_gateway.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../updates/update_ui.dart';
import '../../content/data/content_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/config/brand.dart';
import '../../../core/utils/media_upload.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/searchable_picker.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../core/storage/local_store.dart';
import '../../auth/domain/reference_data.dart';
import '../../auth/domain/student_profile.dart';
import '../../auth/presentation/auth_controllers.dart';
import '../../downloads/data/downloads_controller.dart';
import '../../downloads/domain/download_record.dart';
import '../../home/data/recent_controller.dart';
import '../../content/data/content_source.dart';
import 'widgets/account_widgets.dart';
import '../../../app/safe_nav.dart';

Future<void> logout(BuildContext context, WidgetRef ref) async {
  if (!await confirmDialog(
    context,
    title: 'Log out?',
    message: 'Your downloads stay on this device.',
    confirm: 'Log out',
  )) {
    return;
  }
  try {
    await DriveGateway.instance.disconnect();
    await ref.read(authRepositoryProvider).signOut();
    ref.read(lastCreatedProfileProvider.notifier).state = null;
    if (context.mounted) context.go('/welcome');
  } catch (_) {
    if (context.mounted) {
      showHSnack(context, 'Could not log out. Please retry.', error: true);
    }
  }
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, this.onClose, this.onNavigate});
  final VoidCallback? onClose;
  final ValueChanged<String>? onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final p = ref.watch(profileProvider).valueOrNull;
    final admin = ref.watch(isAdminProvider);
    final name = _accountName(p, user?.displayName, admin);
    void go(String path) {
      if (onNavigate != null) {
        onNavigate!(path);
      } else {
        context.open(path);
      }
    }

    return AccountPage(
      title: 'Account',
      close: true,
      onBack: onClose ?? () => _accountBack(context),
      onRefresh: () async {
        ref.invalidate(profileProvider);
        await ref.read(profileProvider.future);
      },
      children: [
        AccountProfileCard(
          name: name,
          subtitle: p?.rollNumber?.isNotEmpty == true
              ? 'Account info · ${p!.rollNumber}'
              : 'Account info',
          photoUrl: p?.photoUrl ?? user?.photoURL,
          onTap: () => go('/profile/info'),
        ),
        const SizedBox(height: 22),
        SettingsCard(
          raised: true,
          children: [
            SettingsRow(title: 'Settings', onTap: () => go('/settings')),
          ],
        ),
        const SizedBox(height: 20),
        SettingsCard(
          raised: true,
          children: [
            SettingsRow(title: 'My orders', onTap: () => go('/orders')),
            SettingsRow(title: 'Downloads', onTap: () => go('/downloads')),
          ],
        ),
        if (admin) ...[
          const SizedBox(height: 20),
          SettingsCard(
            raised: true,
            children: [
              SettingsRow(title: 'Admin dashboard', onTap: () => go('/admin')),
            ],
          ),
        ],
        const SizedBox(height: 20),
        SettingsCard(
          raised: true,
          children: [
            SettingsRow(title: 'Contact us', onTap: () => go('/contact')),
            SettingsRow(
              title: 'About',
              value: ref.watch(appVersionProvider).valueOrNull,
              onTap: () => go('/about'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        RoundedPrimaryButton(
          label: 'Edit profile',
          onPressed: () => go('/profile/edit'),
        ),
        const SizedBox(height: 22),
        // Keep the existing admin-managed promotions and shop/offline links.
        const ProfilePromotions(),
        const SizedBox(height: 22),
        DestructiveActionButton(
          label: 'Log out',
          onPressed: () async {
            // The dialog and route change use the sheet's still-mounted context.
            await logout(context, ref);
          },
        ),
      ],
    );
  }
}

String _accountName(StudentProfile? p, String? authName, bool admin) {
  if (p?.fullName.trim().isNotEmpty == true) return p!.fullName;
  if (authName?.trim().isNotEmpty == true) return authName!;
  return admin ? 'Administrator' : 'Student';
}

void _accountBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/home');
  }
}

class AccountInfoScreen extends ConsumerWidget {
  const AccountInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileProvider);
    final p = state.valueOrNull;
    final user = ref.watch(authStateProvider).valueOrNull;
    final name = _accountName(p, user?.displayName, ref.watch(isAdminProvider));
    final announcements = ref.watch(boolPrefProvider('pref_announcements'));
    void edit() => context.open('/profile/edit');
    return AccountPage(
      title: 'Account info',
      onBack: () => _accountBack(context),
      children: [
        const SizedBox(height: 8),
        Center(
          child: AccountAvatar(
            photoUrl: p?.photoUrl ?? user?.photoURL,
            fallback: name,
            radius: 46,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: edit,
            child: Text(
              'Change Photo',
              style: TextStyle(
                color: AccountStyle.linkOf(context),
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        if (state.isLoading && p == null)
          const Padding(
            padding: EdgeInsets.all(16),
            child: LinearProgressIndicator(),
          ),
        if (state.hasError && p == null)
          SettingsCard(
            children: [
              SettingsRow(
                title: 'Retry profile',
                subtitle: 'Your account details could not load.',
                onTap: () => ref.invalidate(profileProvider),
              ),
            ],
          ),
        SettingsCard(
          children: [
            SettingsRow(title: 'Name', value: name, onTap: edit),
            // Username is not a field in the current students schema.
            SettingsRow(title: 'Email', value: p?.email ?? user?.email ?? '—'),
            if (p != null)
              SettingsRow(
                title: 'Phone Number',
                value: p.mobile.isEmpty ? 'Add' : PkPhone.pretty(p.mobile),
                onTap: edit,
              ),
          ],
        ),
        const SizedBox(height: 22),
        SettingsCard(
          children: [
            SettingsRow(
              title: 'Notifications',
              onTap: () => context.push('/notifications'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SettingsCard(
          children: [
            SettingsRow(
              title: 'Show announcements',
              trailing: AccountToggle(
                label: 'Show announcements',
                value: announcements,
                onChanged: (v) => ref
                    .read(boolPrefProvider('pref_announcements').notifier)
                    .set(v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SettingsCard(
          children: [
            SettingsRow(
              title: 'Security',
              onTap: () => context.open('/settings'),
            ),
            SettingsRow(
              title: 'Privacy',
              onTap: () => context.push('/legal/privacy'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        if (p != null) ...[
          const AccountSectionHeader('Academic details'),
          SettingsCard(
            children: [
              SettingsRow(
                title: 'Professional year',
                value: ReferenceData.yearLabel(p.professionalYear),
                onTap: edit,
              ),
              SettingsRow(
                title: 'Institution',
                value: p.institutionName,
                onTap: edit,
              ),
              SettingsRow(
                title: 'Roll number',
                value: p.rollNumber ?? 'Add',
                onTap: edit,
              ),
              SettingsRow(
                title: 'Affiliation',
                value: p.affiliationDisplay ?? 'Non-affiliated',
                onTap: edit,
              ),
              SettingsRow(title: 'City', value: p.city, onTap: edit),
              SettingsRow(
                title: 'Gender',
                value: ReferenceData.genders[p.gender] ?? p.gender,
              ),
            ],
          ),
        ],
        const SizedBox(height: 22),
        RoundedPrimaryButton(label: 'Edit profile', onPressed: edit),
        // Deletion is intentionally absent: there is no backend deletion flow.
      ],
    );
  }
}

/// Edit safe fields only (uid/email/role/createdAt immutable — enforced in rules too).
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  StudentProfile? _p;
  late TextEditingController _name, _mobile, _inst, _roll, _customUni;
  String? _city;
  int? _year;
  AffiliationStatus? _aff;
  String? _uni;
  bool _busy = false, _photoBusy = false, _saved = false;
  String? _photo;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authStateProvider).valueOrNull;
    _p =
        ref.read(profileProvider).valueOrNull ??
        (user == null
            ? null
            : StudentProfile(
                uid: user.uid,
                fullName: user.displayName ?? '',
                mobile: '',
                gender: 'other',
                city: '',
                professionalYear: 1,
                institutionName: '',
                affiliationStatus: AffiliationStatus.nonAffiliated,
                email: user.email ?? '',
              ));
    final p = _p;
    _photo = p?.photoUrl ?? user?.photoURL;
    _name = TextEditingController(text: p?.fullName ?? '');
    _mobile = TextEditingController(
      text: PkPhone.normalize(p?.mobile ?? '') == null
          ? ''
          : '0${PkPhone.normalize(p!.mobile)!.substring(3)}',
    );
    _inst = TextEditingController(text: p?.institutionName ?? '');
    _roll = TextEditingController(text: p?.rollNumber ?? '');
    _customUni = TextEditingController(text: p?.customUniversity ?? '');
    _city = p?.city;
    _year = p?.professionalYear;
    _aff = p?.affiliationStatus;
    _uni =
        p?.affiliatedUniversity?.id ??
        ((p?.customUniversity ?? '').isNotEmpty ? ReferenceData.otherId : null);
  }

  @override
  void dispose() {
    for (final c in [_name, _mobile, _inst, _roll, _customUni]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    final p = _p;
    if (p == null || !_form.currentState!.validate()) return;
    if (_aff == AffiliationStatus.affiliated && _uni == null) {
      showHSnack(context, 'Select your affiliated university', error: true);
      return;
    }
    setState(() => _busy = true);
    final known = ReferenceData.universityById(_uni);
    final next = p.copyWith(
      photoUrl: _photo,
      fullName: _name.text.trim(),
      mobile: PkPhone.normalize(_mobile.text),
      city: _city,
      professionalYear: _year,
      institutionName: _inst.text.trim(),
      affiliationStatus: _aff,
      clearUniversity: true,
      affiliatedUniversity: _aff == AffiliationStatus.affiliated ? known : null,
      customUniversity:
          _aff == AffiliationStatus.affiliated && _uni == ReferenceData.otherId
          ? _customUni.text.trim()
          : null,
      rollNumber: _roll.text.trim(),
    );
    try {
      final pending = ref.read(pendingProfileStoreProvider);
      await pending.save(p.uid, next.toWriteMap());
      // The profile stream retries cloud writes; local edits appear immediately.
      ref.invalidate(profileProvider);
      final user = ref.read(authStateProvider).valueOrNull;
      unawaited(() async {
        try {
          await user?.updateDisplayName(next.fullName);
          if (next.photoUrl?.startsWith('https://') == true) {
            await user?.updatePhotoURL(next.photoUrl);
          }
        } catch (_) {}
      }());
      if (mounted) {
        _p = next;
        setState(() => _saved = true);
        showHSnack(context, 'Changes saved');
      }
    } catch (e) {
      if (mounted) {
        showHSnack(
          context,
          'Couldn\u2019t save. Check your connection and try again.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_p == null) {
      return const Scaffold(
        appBar: HTopBar(title: 'Edit profile'),
        body: EmptyState(
          icon: Icons.person_off_rounded,
          title: 'Profile unavailable',
        ),
      );
    }
    final t = AccountStyle.theme(context);
    return AccountTheme(
      child: Scaffold(
        backgroundColor: AccountStyle.backgroundOf(context),
        appBar: AppBar(
          backgroundColor: AccountStyle.backgroundOf(context),
          leadingWidth: 72,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
            child: CircularNavigationButton(
              onPressed: () => _accountBack(context),
            ),
          ),
          title: const Text(
            'Edit profile',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        body: SafeArea(
          child: Form(
            key: _form,
            onChanged: () {
              if (_saved) setState(() => _saved = false);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                HSpace.screen,
                20,
                HSpace.screen,
                HSpace.xxl,
              ),
              children: [
                Center(
                  child: Column(
                    children: [
                      ProfileAvatar(
                        photoUrl: _photo,
                        radius: 44,
                        fallback: _name.text,
                      ),
                      TextButton.icon(
                        onPressed: _photoBusy
                            ? null
                            : () async {
                                setState(() => _photoBusy = true);
                                try {
                                  final url = await MediaUpload.pickAndUpload();
                                  if (url != null && mounted) {
                                    setState(() => _photo = url);
                                  }
                                } catch (_) {
                                  if (context.mounted) {
                                    showHSnack(
                                      context,
                                      'Photo upload failed. Please retry.',
                                      error: true,
                                    );
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() => _photoBusy = false);
                                  }
                                }
                              },
                        icon: _photoBusy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add_a_photo_outlined),
                        label: const Text('Change profile photo'),
                      ),
                    ],
                  ),
                ),
                const Gap(HSpace.md),
                _EditCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Personal', style: t.textTheme.titleMedium),
                      const Gap(HSpace.md),
                      TextFormField(
                        controller: _name,
                        validator: Validators.fullName,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                        ),
                      ),
                      const Gap(HSpace.md),
                      TextFormField(
                        controller: _mobile,
                        keyboardType: TextInputType.phone,
                        validator: Validators.phone,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        onChanged: (_) => setState(() => _saved = false),
                        decoration: const InputDecoration(
                          labelText: 'Mobile',
                          hintText: '0300 1234567',
                        ),
                      ),
                      const Gap(HSpace.md),
                      PickerField(
                        label: 'City',
                        value: _city,
                        icon: Icons.location_city_rounded,
                        onTap: () async {
                          final v = await showSearchablePicker<String>(
                            context: context,
                            title: 'City',
                            options: [
                              for (final c in ReferenceData.cities)
                                PickerOption(value: c, title: c),
                              const PickerOption(
                                value: 'Other',
                                title: 'Enter my city',
                              ),
                            ],
                            selected: _city,
                          );
                          if (v == 'Other' && context.mounted) {
                            final city = TextEditingController(text: _city);
                            final chosen = await showDialog<String>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text('Your city'),
                                content: TextField(
                                  controller: city,
                                  autofocus: true,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: const InputDecoration(
                                    labelText: 'City, town or village',
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(c),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(c, city.text.trim()),
                                    child: const Text('Use city'),
                                  ),
                                ],
                              ),
                            );
                            city.dispose();
                            if (chosen != null &&
                                chosen.isNotEmpty &&
                                mounted) {
                              setState(() => _city = chosen);
                            }
                          } else if (v != null && mounted) {
                            setState(() => _city = v);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const Gap(HSpace.md),
                _EditCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Academic', style: t.textTheme.titleMedium),
                      const Gap(HSpace.md),
                      ChoiceRow<int>(
                        options: ReferenceData.professionalYears.entries
                            .map(
                              (e) => PickerOption(
                                value: e.key,
                                title: e.value.replaceAll(' Professional', ''),
                              ),
                            )
                            .toList(),
                        value: _year,
                        onChanged: (v) => setState(() => _year = v),
                      ),
                      const Gap(HSpace.md),
                      TextFormField(
                        controller: _inst,
                        validator: (v) => Validators.required(v, 'Institution'),
                        decoration: const InputDecoration(
                          labelText: 'College / University',
                        ),
                      ),
                      const Gap(HSpace.md),
                      ChoiceRow<AffiliationStatus>(
                        options: const [
                          PickerOption(
                            value: AffiliationStatus.affiliated,
                            title: 'Affiliated',
                          ),
                          PickerOption(
                            value: AffiliationStatus.nonAffiliated,
                            title: 'Non-affiliated',
                          ),
                        ],
                        value: _aff,
                        onChanged: (v) => setState(() => _aff = v),
                      ),
                      if (_aff == AffiliationStatus.affiliated) ...[
                        const Gap(HSpace.md),
                        PickerField(
                          label: 'Affiliated university',
                          value: _uni == ReferenceData.otherId
                              ? 'Other'
                              : ReferenceData.universityById(_uni)?.name,
                          onTap: () async {
                            final v = await showSearchablePicker<String>(
                              context: context,
                              title: 'Affiliated university',
                              options: [
                                ...ReferenceData.universities.map(
                                  (u) => PickerOption(
                                    value: u.id,
                                    title: '${u.name} (${u.shortName})',
                                    subtitle: u.city,
                                  ),
                                ),
                                const PickerOption(
                                  value: ReferenceData.otherId,
                                  title: 'Other',
                                ),
                              ],
                              selected: _uni,
                            );
                            if (v != null) setState(() => _uni = v);
                          },
                        ),
                        if (_uni == ReferenceData.otherId) ...[
                          const Gap(HSpace.md),
                          TextFormField(
                            controller: _customUni,
                            validator: (v) =>
                                Validators.required(v, 'University name'),
                            decoration: const InputDecoration(
                              labelText: 'University name',
                            ),
                          ),
                        ],
                      ],
                      const Gap(HSpace.md),
                      TextFormField(
                        controller: _roll,
                        decoration: const InputDecoration(
                          labelText: 'Roll number (optional)',
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(HSpace.lg),
                RoundedPrimaryButton(
                  label: _saved ? 'Changes saved ✓' : 'Save changes',
                  loading: _busy,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditCard extends StatelessWidget {
  const _EditCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => SettingsCard(
    children: [Padding(padding: const EdgeInsets.all(18), child: child)],
  );
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _search = TextEditingController();
  bool _resetBusy = false;
  bool _matches(String value) =>
      _search.text.trim().isEmpty ||
      value.toLowerCase().contains(_search.text.trim().toLowerCase());

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _resetPassword(String email) async {
    if (_resetBusy ||
        !await confirmDialog(
          context,
          title: 'Reset password?',
          message: 'Send a password reset link to $email?',
          confirm: 'Send link',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => _resetBusy = true);
    try {
      await ref.read(authRepositoryProvider).sendReset(email);
      if (mounted) showHSnack(context, 'Password reset email sent');
    } catch (_) {
      if (mounted) {
        showHSnack(
          context,
          'Could not send the email. Please retry.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _resetBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(profileProvider).valueOrNull;
    final user = ref.watch(authStateProvider).valueOrNull;
    final mode = ref.watch(themeModeProvider);
    final textScale = ref.watch(doublePrefProvider('pref_text_scale'));
    final reduceMotion = ref.watch(boolPrefProvider('pref_reduce_motion'));
    final notif = ref.watch(boolPrefProvider('pref_announcements'));
    final used = ref
        .watch(downloadsProvider)
        .values
        .where((r) => r.isReady)
        .fold(0, (s, r) => s + r.sizeBytes);
    final email = user?.email;
    return AccountPage(
      title: 'Settings',
      onBack: () => _accountBack(context),
      children: [
        WorkspaceIdentityCard(
          name: _accountName(p, user?.displayName, ref.watch(isAdminProvider)),
          subtitle: [
            if (p?.rollNumber?.trim().isNotEmpty == true) p!.rollNumber!,
            if (email?.trim().isNotEmpty == true) email!,
          ].join(' · '),
          year: ReferenceData.yearLabel(
            ref.watch(professionalYearProvider),
          ),
          photoUrl: p?.photoUrl ?? user?.photoURL,
          onEditProfile: () => context.open('/profile/edit'),
          onChangeYear: () => context.open('/profile/edit'),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search settings',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(_search.clear),
                ),
          ),
        ),
        const SizedBox(height: 20),
        SettingsCard(
          raised: true,
          children: [
            SettingsRow(
              title: 'Show announcements',
              trailing: AccountToggle(
                label: 'Show announcements',
                value: notif,
                onChanged: (v) => ref
                    .read(boolPrefProvider('pref_announcements').notifier)
                    .set(v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_matches(
          'personal academic professional year profile app updates release',
        )) ...[
          const AccountSectionHeader('Personal & academic'),
          SettingsCard(
            raised: true,
            children: [
              if (_matches('professional year profile academic'))
                SettingsRow(
                  title: 'Professional year & profile',
                  value: ReferenceData.yearLabel(
                    ref.watch(professionalYearProvider),
                  ),
                  onTap: () => context.open('/profile/edit'),
                ),
              if (_matches('app updates release'))
                SettingsRow(
                  title: 'App updates',
                  onTap: () => checkForUpdate(
                    context,
                    ref.read(siteSettingsProvider).raw,
                  ),
                ),
            ],
          ),
        ],
        if (_matches('appearance theme light dark auto')) ...[
          const AccountSectionHeader('Appearance'),
          SettingsCard(
            children: [
              SettingsRow(
                title: 'App theme',
                value: switch (mode) {
                  ThemeMode.light => 'Light',
                  ThemeMode.dark => 'Dark',
                  ThemeMode.system => 'Auto',
                },
                onTap: () => _chooseTheme(context, ref, mode),
              ),
            ],
          ),
        ],
        if (_matches('accessibility text size font scale reduce motion animation')) ...[
          const AccountSectionHeader('Accessibility'),
          SettingsCard(
            children: [
              SettingsRow(
                title: 'Text size',
                value: '${(textScale * 100).round()}%',
                subtitle: 'Adjust text size without changing your phone settings',
                onTap: () => _chooseTextScale(context, ref, textScale),
              ),
              SettingsRow(
                title: 'Reduce motion',
                subtitle: 'Use fewer moving transitions throughout the app',
                trailing: Switch.adaptive(
                  value: reduceMotion,
                  onChanged: (value) => ref
                      .read(boolPrefProvider('pref_reduce_motion').notifier)
                      .set(value),
                ),
              ),
            ],
          ),
        ],
        ...[
          const AccountSectionHeader('Notifications'),
          SettingsCard(
            children: [
              SettingsRow(
                title: 'Notification inbox',
                onTap: () => context.push('/notifications'),
              ),
            ],
          ),
        ],
        if (_matches('security password privacy terms')) ...[
          const AccountSectionHeader('Security & privacy'),
          SettingsCard(
            children: [
              if (email != null &&
                  email.isNotEmpty &&
                  _matches('security password'))
                SettingsRow(
                  title: 'Reset password',
                  value: _resetBusy ? 'Sending…' : null,
                  onTap: _resetBusy ? null : () => _resetPassword(email),
                ),
              if (_matches('privacy'))
                SettingsRow(
                  title: 'Privacy Policy',
                  onTap: () => context.push('/legal/privacy'),
                ),
              if (_matches('terms'))
                SettingsRow(
                  title: 'Terms of Use',
                  onTap: () => context.push('/legal/terms'),
                ),
            ],
          ),
        ],
        if (_matches('storage downloads cache history')) ...[
          const AccountSectionHeader('Storage'),
          SettingsCard(
            children: [
              SettingsRow(
                title: 'Offline files',
                value: formatBytes(used),
                subtitle: kIsWeb
                    ? 'Save Offline is available in the Android app.'
                    : null,
              ),
              SettingsRow(
                title: 'Manage downloads',
                onTap: () => context.go('/downloads'),
              ),
              SettingsRow(
                title: 'Clear content cache',
                onTap: () async {
                  await JsonBox(Boxes.contentCache).clear();
                  for (final key in publicContentKeys) {
                    forcedRefresh.add(key);
                    ref.invalidate(contentProvider(key));
                  }
                  if (context.mounted) {
                    showHSnack(context, 'Cache cleared. Content will reload.');
                  }
                },
              ),
              SettingsRow(
                title: 'Clear history',
                onTap: () async {
                  await ref.read(recentProvider.notifier).clear();
                  if (context.mounted) showHSnack(context, 'History cleared');
                },
              ),
            ],
          ),
        ],
        if (_matches('tutorial guide walkthrough help')) ...[
          const AccountSectionHeader('Help & support'),
          SettingsCard(
            children: [
              SettingsRow(
                title: 'Replay app tutorial',
                subtitle: 'A quick guide to your study library and offline files',
                onTap: () => context.push('/tutorial'),
              ),
              SettingsRow(
                title: 'Contact support',
                onTap: () => context.push('/contact'),
              ),
            ],
          ),
        ],
        if (_matches('about version')) ...[
          const SizedBox(height: 22),
          SettingsCard(
            children: [
              SettingsRow(
                title: 'About ${Brand.shortName}',
                value: ref.watch(appVersionProvider).valueOrNull,
                onTap: () => context.push('/about'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 22),
        DestructiveActionButton(
          label: 'Log out',
          onPressed: () => logout(context, ref),
        ),
      ],
    );
  }
}

Future<void> _chooseTextScale(
  BuildContext context,
  WidgetRef ref,
  double current,
) async {
  var selected = current;
  final next = await showModalBottomSheet<double>(
    context: context,
    backgroundColor: AccountStyle.cardOf(context),
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AccountSectionHeader('Text size'),
              Text(
                '${(selected * 100).round()}% preview',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18 * selected,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Slider(
                value: selected,
                min: .85,
                max: 1.35,
                divisions: 10,
                label: '${(selected * 100).round()}%',
                onChanged: (value) =>
                    setSheetState(() => selected = value),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Smaller'),
                  Text('Larger'),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, 1.0),
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, selected),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (next != null && context.mounted) {
    ref.read(doublePrefProvider('pref_text_scale').notifier).set(next);
  }
}

Future<void> _chooseTheme(
  BuildContext context,
  WidgetRef ref,
  ThemeMode mode,
) async {
  final next = await showModalBottomSheet<ThemeMode>(
    context: context,
    backgroundColor: AccountStyle.cardOf(context),
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AccountSectionHeader('App theme'),
            for (final item in const [
              (ThemeMode.light, 'Light'),
              (ThemeMode.dark, 'Dark'),
              (ThemeMode.system, 'Auto'),
            ])
              SettingsRow(
                title: item.$2,
                trailing: mode == item.$1
                    ? Icon(
                        Icons.check_rounded,
                        color: AccountStyle.linkOf(context),
                      )
                    : null,
                onTap: () => Navigator.pop(context, item.$1),
              ),
          ],
        ),
      ),
    ),
  );
  if (next != null && context.mounted) {
    ref.read(themeModeProvider.notifier).set(next);
  }
}
