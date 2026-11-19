import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/surfaces.dart';
import '../../../core/widgets/refinement_art.dart';

/// Shared scaffold for auth forms: persistent top bar with Back, keyboard-safe scroll.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.onBack,
  });
  final String title;
  final String? subtitle;
  final Widget child;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: HTopBar(title: title, subtitle: subtitle, onBack: onBack),
      body: HBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
            padding: const EdgeInsets.fromLTRB(
              HSpace.screen,
              HSpace.md,
              HSpace.screen,
              HSpace.xxl,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.validator,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
    this.autofill = AutofillHints.password,
    this.focusNode,
    this.helper,
  });
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final String autofill;
  final FocusNode? focusNode;
  final String? helper;
  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: _obscure,
      style: const TextStyle(
        fontSize: 16,
        height: 1.4,
        fontWeight: FontWeight.w500,
      ),
      enableSuggestions: false,
      autocorrect: false,
      autofillHints: [widget.autofill],
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helper,
        helperMaxLines: 2,
        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 19),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        suffixIcon: IconButton(
          tooltip: _obscure ? 'Show password' : 'Hide password',
          iconSize: 20,
          padding: const EdgeInsets.all(12),
          icon: Icon(
            _obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  final _pwFocus = FocusNode();
  bool _showForm = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    _pwFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return; // prevent duplicate submissions
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    if (!ref.read(firebaseReadyProvider)) {
      setState(
        () => _error =
            'Can\u2019t reach PHARM D WITH HYZEN right now. Please check your connection.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signIn(_email.text, _pw.text);
      TextInput.finishAutofillContext();
      // Router redirect handles navigation on auth change.
    } on FriendlyException catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    if (!_showForm) {
      return AccountChoiceScreen(
        onLogin: () => setState(() => _showForm = true),
      );
    }
    return HBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        AuthBackButton(
                          onPressed: () => setState(() {
                            _showForm = false;
                            _error = null;
                            _pw.clear();
                          }),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'PHARM D WITH HYZEN',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      key: const ValueKey('login-panda-hero'),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xfff5dfc9), Color(0xffe9e2f6)],
                        ),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: LayoutBuilder(
                        builder: (context, c) => Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Your study space',
                                    style: t.textTheme.labelLarge,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Welcome back',
                                    style: t.textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Your notes, focus and progress.\nAll in one familiar place.',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            RefinementArt(
                              RefinementGlyph.panda,
                              size: c.maxWidth < 290 ? 86 : 120,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      key: const ValueKey('login-form-panel'),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .85),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xffe5e0df)),
                      ),
                      child: Form(
                        key: _form,
                        child: AutofillGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Log in to your account',
                                style: t.textTheme.titleLarge,
                              ),
                              const SizedBox(height: 20),
                              if (_error != null) ...[
                                _ErrorBanner(message: _error!),
                                const SizedBox(height: 16),
                              ],
                              TextFormField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [
                                  AutofillHints.email,
                                  AutofillHints.username,
                                ],
                                autocorrect: false,
                                validator: Validators.email,
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                onFieldSubmitted: (_) =>
                                    _pwFocus.requestFocus(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  hintText: 'you@example.com',
                                  prefixIcon: Icon(
                                    Icons.alternate_email_rounded,
                                    size: 19,
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              PasswordField(
                                controller: _pw,
                                focusNode: _pwFocus,
                                validator: Validators.loginPassword,
                                onSubmitted: (_) => _submit(),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => context.push(
                                    '/forgot-password',
                                    extra: _email.text.trim(),
                                  ),
                                  child: const Text('Forgot password?'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              HButton(
                                label: 'Log in',
                                icon: Icons.arrow_forward_rounded,
                                loading: _busy,
                                onPressed: _submit,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text('New to Hyzen?'),
                        TextButton(
                          onPressed: () =>
                              context.pushReplacement('/register/personal'),
                          child: const Text('Create account'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key, required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 48,
    child: Center(
      child: Material(
        color: Colors.white.withValues(alpha: .8),
        borderRadius: BorderRadius.circular(12),
        child: IconButton(
          tooltip: 'Back',
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.arrow_back_rounded, size: 19),
          onPressed: onPressed,
        ),
      ),
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(HSpace.sm),
        decoration: BoxDecoration(
          color: HColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(HRadius.md),
          border: Border.all(color: HColors.error.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: HColors.error),
            const SizedBox(width: HSpace.xs),
            Expanded(
              child: Text(
                message,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: HColors.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});
  final String? initialEmail;
  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail ?? '');
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendReset(_email.text);
      if (mounted) setState(() => _sent = true);
    } on FriendlyException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = AuthErrorMapper.message('unknown'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return AuthScaffold(
      title: 'Reset password',
      child: AnimatedSwitcher(
        duration: HMotion.medium,
        child: _sent
            ? Column(
                key: const ValueKey('sent'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: HSpace.xxl),
                  const Center(
                    child: IconBadge(
                      icon: Icons.mark_email_read_rounded,
                      color: HColors.primary,
                      size: 80,
                    ),
                  ),
                  const SizedBox(height: HSpace.lg),
                  Text(
                    'Check your inbox',
                    style: t.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: HSpace.xs),
                  Text(
                    'If an account exists for ${_email.text.trim()}, you\u2019ll receive a link to reset your password. Check spam if you don\u2019t see it.',
                    style: t.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: HSpace.xl),
                  HButton(
                    label: 'Back to log in',
                    onPressed: () => context.pop(),
                  ),
                ],
              )
            : Form(
                key: _form,
                child: Column(
                  key: const ValueKey('form'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: HSpace.xl),
                    Text(
                      'Forgot your password?',
                      style: t.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: HSpace.xs),
                    Text(
                      'Enter the email you used for PHARM D WITH HYZEN and we\u2019ll send you a reset link.',
                      style: t.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: HSpace.xl),
                    if (_error != null) ...[
                      _ErrorBanner(message: _error!),
                      const SizedBox(height: HSpace.md),
                    ],
                    SurfacePanel(
                      radius: HRadius.lg,
                      padding: const EdgeInsets.all(HSpace.md),
                      child: TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.send,
                        onFieldSubmitted: (_) => _send(),
                        validator: Validators.email,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.alternate_email_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(height: HSpace.lg),
                    HButton(
                      label: 'Send reset link',
                      loading: _busy,
                      onPressed: _send,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class AccountChoiceScreen extends StatelessWidget {
  const AccountChoiceScreen({super.key, required this.onLogin});
  final VoidCallback onLogin;
  @override
  Widget build(BuildContext context) => HBackground(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AuthBackButton(
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go('/welcome'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xffffe8d0), Color(0xffe9e5f6)],
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PHARM D WITH HYZEN',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Center(
                          child: RefinementArt(
                            RefinementGlyph.panda,
                            size: 190,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'A little focus.\nA brighter future.',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Build a study rhythm that feels like yours.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Make yourself at home',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Keep learning with your notes, resources and progress.',
                  ),
                  const SizedBox(height: 20),
                  HButton(
                    label: 'Already a user? Log in',
                    onPressed: onLogin,
                    icon: Icons.arrow_forward_rounded,
                  ),
                  const SizedBox(height: 8),
                  HButton(
                    label: 'Create account',
                    outlined: true,
                    onPressed: () => context.push('/register/personal'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
