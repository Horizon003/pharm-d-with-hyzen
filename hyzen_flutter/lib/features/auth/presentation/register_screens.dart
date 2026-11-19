import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/surfaces.dart';
import '../../../core/widgets/searchable_picker.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../../core/utils/media_upload.dart';
import '../domain/reference_data.dart';
import '../domain/registration_draft.dart';
import '../domain/student_profile.dart';
import 'auth_controllers.dart';
import 'login_screens.dart';

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.step,
    required this.title,
    required this.subtitle,
  });
  final int step;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Semantics(
      label: 'Step $step of 3. $title',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STEP $step OF 3',
            style: t.textTheme.labelSmall?.copyWith(
              color: t.colorScheme.primary,
            ),
          ),
          const SizedBox(height: HSpace.xs),
          Row(
            children: [
              for (var i = 1; i <= 3; i++) ...[
                Expanded(
                  child: AnimatedContainer(
                    duration: HMotion.medium,
                    curve: HMotion.curve,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i <= step
                          ? t.colorScheme.primary
                          : t.colorScheme.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(HRadius.pill),
                    ),
                  ),
                ),
                if (i < 3) const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: HSpace.lg),
          Text(title, style: t.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(subtitle, style: t.textTheme.bodyMedium),
          const SizedBox(height: HSpace.lg),
        ],
      ),
    );
  }
}

class _FieldGap extends StatelessWidget {
  const _FieldGap();
  @override
  Widget build(BuildContext context) => const SizedBox(height: HSpace.md);
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: HSpace.xs, left: 2),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}

// ======================= STEP 1 =======================
class RegisterPersonalScreen extends ConsumerStatefulWidget {
  const RegisterPersonalScreen({super.key});
  @override
  ConsumerState<RegisterPersonalScreen> createState() =>
      _RegisterPersonalState();
}

class _RegisterPersonalState extends ConsumerState<RegisterPersonalScreen> {
  late final RegistrationDraft _d0 = ref.read(registrationProvider);
  late final _name = TextEditingController(text: _d0.fullName);
  late final _mobile = TextEditingController(text: _d0.mobile);
  late final _customCity = TextEditingController(text: _d0.customCity);
  final _mobileFocus = FocusNode();
  Map<String, String> _errors = {};
  bool _photoBusy = false;

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _customCity.dispose();
    _mobileFocus.dispose();
    super.dispose();
  }

  void _sync() {
    ref
        .read(registrationProvider.notifier)
        .update(
          (d) => d.copyWith(
            fullName: _name.text,
            mobile: _mobile.text,
            customCity: _customCity.text,
          ),
        );
  }

  void _next() {
    _sync();
    final e = ref.read(registrationProvider).validatePersonal();
    setState(() => _errors = e);
    if (e.isEmpty) context.push('/register/academic');
  }

  Future<void> _pickCity() async {
    final d = ref.read(registrationProvider);
    final v = await showSearchablePicker<String>(
      context: context,
      title: 'Select your city',
      hint: 'Search Pakistani cities',
      selected: d.city,
      options: [
        for (final c in ReferenceData.cities) PickerOption(value: c, title: c),
        const PickerOption(
          value: RegistrationDraft.otherCity,
          title: 'Enter my city',
          subtitle: 'Use any city, town or village',
        ),
      ],
    );
    if (v != null) {
      ref
          .read(registrationProvider.notifier)
          .update((d) => d.copyWith(city: v));
      setState(() => _errors.remove('city'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(registrationProvider);
    return PopScope(
      onPopInvokedWithResult: (_, __) => _sync(),
      child: AuthScaffold(
        title: 'Create account',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _StepHeader(
              step: 1,
              title: 'Personal details',
              subtitle: 'Tell us a little about yourself.',
            ),
            Center(
              child: Column(
                children: [
                  ProfileAvatar(
                    photoUrl: d.photoUrl,
                    radius: 37,
                    fallback: d.fullName.isEmpty ? 'H' : d.fullName,
                  ),
                  TextButton.icon(
                    onPressed: _photoBusy
                        ? null
                        : () async {
                            setState(() => _photoBusy = true);
                            try {
                              final url = await MediaUpload.pickAndUpload();
                              if (mounted && url != null) {
                                ref
                                    .read(registrationProvider.notifier)
                                    .update(
                                      (draft) => draft.copyWith(photoUrl: url),
                                    );
                              }
                            } catch (_) {
                              if (context.mounted) {
                                showHSnack(
                                  context,
                                  'Could not upload photo. Please retry.',
                                  error: true,
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _photoBusy = false);
                            }
                          },
                    icon: _photoBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_a_photo_outlined),
                    label: const Text('Use gallery photo (optional)'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: HSpace.md),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              onSubmitted: (_) => _mobileFocus.requestFocus(),
              onChanged: (_) => _errors.containsKey('fullName')
                  ? setState(() => _errors.remove('fullName'))
                  : null,
              decoration: InputDecoration(
                labelText: 'Full name',
                prefixIcon: const Icon(Icons.person_outline_rounded),
                errorText: _errors['fullName'],
              ),
            ),
            const _FieldGap(),
            TextField(
              controller: _mobile,
              focusNode: _mobileFocus,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.telephoneNumberNational],
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9 \-+]')),
                LengthLimitingTextInputFormatter(16),
              ],
              onChanged: (_) => _errors.containsKey('mobile')
                  ? setState(() => _errors.remove('mobile'))
                  : null,
              decoration: InputDecoration(
                labelText: 'Mobile number',
                hintText: '0300 1234567',
                errorText: _errors['mobile'],
                errorMaxLines: 2,
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 14, right: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('\u{1F1F5}\u{1F1F0}'),
                      const SizedBox(width: 6),
                      Text(
                        '+92',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: HSpace.lg),
            const _Label('Gender'),
            ChoiceRow<String>(
              options: [
                for (final e in ReferenceData.genders.entries)
                  PickerOption(value: e.key, title: e.value),
              ],
              value: d.gender,
              errorText: _errors['gender'],
              onChanged: (v) {
                ref
                    .read(registrationProvider.notifier)
                    .update((d) => d.copyWith(gender: v));
                setState(() => _errors.remove('gender'));
              },
            ),
            const SizedBox(height: HSpace.lg),
            PickerField(
              label: 'City',
              icon: Icons.location_city_rounded,
              value: d.city,
              errorText: _errors['city'],
              onTap: _pickCity,
            ),
            AnimatedSize(
              duration: HMotion.medium,
              curve: HMotion.curve,
              child: d.city == RegistrationDraft.otherCity
                  ? Padding(
                      padding: const EdgeInsets.only(top: HSpace.md),
                      child: TextField(
                        controller: _customCity,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'Your city',
                          errorText: _errors['customCity'],
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            const SizedBox(height: HSpace.lg),
            const _Label('Professional year'),
            ChoiceRow<int>(
              options: [
                for (final e in ReferenceData.professionalYears.entries)
                  PickerOption(value: e.key, title: e.value),
              ],
              value: d.professionalYear,
              errorText: _errors['professionalYear'],
              onChanged: (v) {
                ref
                    .read(registrationProvider.notifier)
                    .update((d) => d.copyWith(professionalYear: v));
                setState(() => _errors.remove('professionalYear'));
              },
            ),
            const SizedBox(height: HSpace.xxl),
            HButton(
              label: 'Continue',
              icon: Icons.arrow_forward_rounded,
              onPressed: _next,
            ),
            const SizedBox(height: HSpace.sm),
            TextButton(
              onPressed: () => context.pushReplacement('/login'),
              child: const Text('I already have an account'),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================= STEP 2 =======================
class RegisterAcademicScreen extends ConsumerStatefulWidget {
  const RegisterAcademicScreen({super.key});
  @override
  ConsumerState<RegisterAcademicScreen> createState() =>
      _RegisterAcademicState();
}

class _RegisterAcademicState extends ConsumerState<RegisterAcademicScreen> {
  late final RegistrationDraft _d0 = ref.read(registrationProvider);
  late final _inst = TextEditingController(text: _d0.institutionName);
  late final _uniName = TextEditingController(text: _d0.customUniversity);
  late final _uniCity = TextEditingController(text: _d0.customUniversityCity);
  late final _roll = TextEditingController(text: _d0.rollNumber);
  Map<String, String> _errors = {};

  @override
  void dispose() {
    for (final c in [_inst, _uniName, _uniCity, _roll]) {
      c.dispose();
    }
    super.dispose();
  }

  void _sync() => ref
      .read(registrationProvider.notifier)
      .update(
        (d) => d.copyWith(
          institutionName: _inst.text,
          customUniversity: _uniName.text,
          customUniversityCity: _uniCity.text,
          rollNumber: _roll.text,
        ),
      );

  void _next() {
    _sync();
    final e = ref.read(registrationProvider).validateAcademic();
    setState(() => _errors = e);
    if (e.isEmpty) context.push('/register/credentials');
  }

  Future<void> _pickUni() async {
    final d = ref.read(registrationProvider);
    final v = await showSearchablePicker<String>(
      context: context,
      title: 'Affiliated university',
      hint: 'Search universities',
      selected: d.universityId,
      options: [
        for (final u in ReferenceData.universities)
          PickerOption(
            value: u.id,
            title: u.name,
            subtitle: '${u.shortName} \u00B7 ${u.city}',
          ),
        const PickerOption(
          value: ReferenceData.otherId,
          title: 'Other',
          subtitle: 'My university isn\u2019t listed',
        ),
      ],
    );
    if (v != null) {
      ref
          .read(registrationProvider.notifier)
          .update((d) => d.copyWith(universityId: v));
      setState(() => _errors.remove('universityId'));
    }
  }

  String? _uniLabel(String? id) {
    if (id == null) return null;
    if (id == ReferenceData.otherId) return 'Other';
    final u = ReferenceData.universityById(id);
    return u == null ? null : '${u.name} (${u.shortName})';
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(registrationProvider);
    final affiliated = d.affiliation == AffiliationStatus.affiliated;
    return PopScope(
      onPopInvokedWithResult: (_, __) => _sync(),
      child: AuthScaffold(
        title: 'Create account',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _StepHeader(
              step: 2,
              title: 'Academic details',
              subtitle: 'Where are you studying Pharm-D?',
            ),
            TextField(
              controller: _inst,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              maxLines: null,
              onChanged: (_) => _errors.containsKey('institutionName')
                  ? setState(() => _errors.remove('institutionName'))
                  : null,
              decoration: InputDecoration(
                labelText: 'College / University name',
                prefixIcon: const Icon(Icons.school_outlined),
                errorText: _errors['institutionName'],
              ),
            ),
            const SizedBox(height: HSpace.lg),
            const _Label(
              'Is your college/university affiliated with another university?',
            ),
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
              value: d.affiliation,
              errorText: _errors['affiliation'],
              onChanged: (v) {
                ref
                    .read(registrationProvider.notifier)
                    .update((d) => d.copyWith(affiliation: v));
                setState(() => _errors.remove('affiliation'));
              },
            ),
            AnimatedSize(
              duration: HMotion.medium,
              curve: HMotion.curve,
              alignment: Alignment.topCenter,
              child: !affiliated
                  ? const SizedBox(width: double.infinity)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: HSpace.lg),
                        PickerField(
                          label: 'Affiliated university',
                          icon: Icons.account_balance_outlined,
                          value: _uniLabel(d.universityId),
                          errorText: _errors['universityId'],
                          onTap: _pickUni,
                        ),
                        if (d.universityId == ReferenceData.otherId) ...[
                          const _FieldGap(),
                          TextField(
                            controller: _uniName,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              labelText: 'University name',
                              errorText: _errors['customUniversity'],
                            ),
                          ),
                          const _FieldGap(),
                          TextField(
                            controller: _uniCity,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'University city (optional)',
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: HSpace.lg),
            TextField(
              controller: _roll,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Roll number (optional)',
                prefixIcon: Icon(Icons.badge_outlined),
                helperText: 'You can leave this blank.',
              ),
            ),
            const SizedBox(height: HSpace.xxl),
            HButton(
              label: 'Continue',
              icon: Icons.arrow_forward_rounded,
              onPressed: _next,
            ),
          ],
        ),
      ),
    );
  }
}

// ======================= STEP 3 =======================
class RegisterCredentialsScreen extends ConsumerStatefulWidget {
  const RegisterCredentialsScreen({super.key});
  @override
  ConsumerState<RegisterCredentialsScreen> createState() =>
      _RegisterCredentialsState();
}

class _RegisterCredentialsState
    extends ConsumerState<RegisterCredentialsScreen> {
  late final _email = TextEditingController(
    text: ref.read(registrationProvider).email,
  );
  final _pw = TextEditingController();
  final _confirm = TextEditingController();
  final _pwFocus = FocusNode();
  final _cFocus = FocusNode();
  Map<String, String> _errors = {};
  bool _busy = false;
  String? _submitError;

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    _confirm.dispose();
    _pwFocus.dispose();
    _cFocus.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    ref
        .read(registrationProvider.notifier)
        .update((d) => d.copyWith(email: _email.text.trim()));
    final d = ref.read(registrationProvider);
    final e = d.validateCredentials(_pw.text, _confirm.text);
    setState(() {
      _errors = e;
      _submitError = null;
    });
    if (e.isNotEmpty) return;
    if (d.validatePersonal().isNotEmpty) {
      context.go('/register/personal');
      return;
    }
    if (d.validateAcademic().isNotEmpty) {
      context.pop();
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(submitRegistrationProvider)(_pw.text);
      TextInput.finishAutofillContext();
      _pw.clear();
      _confirm.clear();
      if (mounted) context.go('/register/success');
    } on FriendlyException catch (ex) {
      if (mounted) setState(() => _submitError = ex.message);
    } catch (_) {
      if (mounted) {
        setState(() => _submitError = AuthErrorMapper.message('unknown'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final d = ref.watch(registrationProvider);
    return PopScope(
      onPopInvokedWithResult: (_, __) => ref
          .read(registrationProvider.notifier)
          .update((d) => d.copyWith(email: _email.text.trim())),
      child: AuthScaffold(
        title: 'Create account',
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _StepHeader(
                step: 3,
                title: 'Login credentials',
                subtitle:
                    'You\u2019ll use these to log in to PHARM D WITH HYZEN.',
              ),
              if (_submitError != null) ...[
                Container(
                  padding: const EdgeInsets.all(HSpace.sm),
                  decoration: BoxDecoration(
                    color: HColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(HRadius.md),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: HColors.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _submitError!,
                          style: t.textTheme.bodyMedium?.copyWith(
                            color: HColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const _FieldGap(),
              ],
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                autofillHints: const [
                  AutofillHints.email,
                  AutofillHints.newUsername,
                ],
                onSubmitted: (_) => _pwFocus.requestFocus(),
                decoration: InputDecoration(
                  labelText: 'Email address',
                  prefixIcon: const Icon(Icons.alternate_email_rounded),
                  errorText: _errors['email'],
                ),
              ),
              const _FieldGap(),
              PasswordField(
                controller: _pw,
                focusNode: _pwFocus,
                autofill: AutofillHints.newPassword,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _cFocus.requestFocus(),
                helper: 'At least 8 characters, with a letter and a number.',
                validator: (_) => _errors['password'],
              ),
              const _FieldGap(),
              PasswordField(
                controller: _confirm,
                focusNode: _cFocus,
                label: 'Confirm password',
                autofill: AutofillHints.newPassword,
                onSubmitted: (_) => _create(),
                validator: (_) => _errors['confirm'],
              ),
              if (_errors['password'] != null || _errors['confirm'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Text(
                    _errors['password'] ?? _errors['confirm']!,
                    style: t.inputDecorationTheme.errorStyle,
                  ),
                ),
              const SizedBox(height: HSpace.lg),
              SurfacePanel(
                radius: HRadius.md,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: CheckboxListTile(
                  value: d.acceptedTerms,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) {
                    ref
                        .read(registrationProvider.notifier)
                        .update((d) => d.copyWith(acceptedTerms: v ?? false));
                    setState(() => _errors.remove('terms'));
                  },
                  title: Wrap(
                    children: [
                      Text('I agree to the ', style: t.textTheme.bodyMedium),
                      InkWell(
                        onTap: () => context.push('/legal/terms'),
                        child: Text(
                          'Terms of Use',
                          style: t.textTheme.bodyMedium?.copyWith(
                            color: t.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(' and ', style: t.textTheme.bodyMedium),
                      InkWell(
                        onTap: () => context.push('/legal/privacy'),
                        child: Text(
                          'Privacy Policy',
                          style: t.textTheme.bodyMedium?.copyWith(
                            color: t.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text('.', style: t.textTheme.bodyMedium),
                    ],
                  ),
                  subtitle: _errors['terms'] == null
                      ? null
                      : Text(
                          _errors['terms']!,
                          style: t.inputDecorationTheme.errorStyle,
                        ),
                ),
              ),
              const SizedBox(height: HSpace.xxl),
              HButton(
                label: 'Create account',
                loading: _busy,
                onPressed: _create,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================= SUCCESS =======================
class RegisterSuccessScreen extends ConsumerWidget {
  const RegisterSuccessScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final p = ref.watch(lastCreatedProfileProvider);
    Widget row(IconData i, String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon: i, color: HColors.primary, size: 38),
          const SizedBox(width: HSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(k, style: t.textTheme.labelMedium),
                Text(v, style: t.textTheme.titleSmall),
              ],
            ),
          ),
        ],
      ),
    );
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: HBackground(
          intense: true,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(HSpace.screen),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: HSpace.xxl),
                  const Center(
                    child: IconBadge(
                      icon: Icons.check_rounded,
                      color: HColors.success,
                      size: 88,
                    ),
                  ),
                  const SizedBox(height: HSpace.lg),
                  Text(
                    'You\u2019re all set${p == null ? '' : ', ${p.firstName}'}.',
                    style: t.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: HSpace.xs),
                  Text(
                    'Your PHARM D WITH HYZEN account is ready.',
                    style: t.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: HSpace.xl),
                  if (p != null)
                    SurfacePanel(
                      radius: HRadius.xl,
                      padding: const EdgeInsets.all(HSpace.md),
                      child: Column(
                        children: [
                          row(
                            Icons.workspace_premium_outlined,
                            'Professional year',
                            ReferenceData.yearLabel(p.professionalYear),
                          ),
                          row(
                            Icons.school_outlined,
                            'Institution',
                            p.institutionName,
                          ),
                          if (p.affiliationDisplay != null)
                            row(
                              Icons.account_balance_outlined,
                              'Affiliated university',
                              p.affiliationDisplay!,
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: HSpace.xxl),
                  HButton(
                    label: 'Start learning',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: () {
                      ref.read(registrationProvider.notifier).reset();
                      context.go('/home');
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
