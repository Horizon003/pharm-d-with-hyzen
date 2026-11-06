import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/config/brand.dart';
import '../../../core/widgets/hyzen_art.dart';

extension ResizeImageCompatibility on ResizeImage {
  ImageProvider get image => imageProvider;
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(Brand.logoAsset, width: 72, height: 72),
            const SizedBox(height: 16),
            Text(
              'PHARM D',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: HColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Text('WITH HYZEN · Your pharmacy journey'),
            const SizedBox(height: 20),
            const HyzenArt('welcome', size: 280),
            const SizedBox(height: 24),
            const SizedBox(
              width: 120,
              child: LinearProgressIndicator(minHeight: 5),
            ),
            const SizedBox(height: 12),
            const Text('Preparing your study space…'),
          ],
        ),
      ),
    ),
  );
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

/// Screen 01: Editorial Minimal onboarding.
/// The three existing pages and their authentication routes are preserved.
class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _pages = PageController();
  int _index = 0;

  static const _deepTeal = Color(0xFF087F76);
  static const _grayFilter = ColorFilter.matrix([
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0,      0,      0,      1, 0,
  ]);

  static const _content = [
    (
      'welcome',
      'Your future in\npharmacy starts here.',
      'Study smarter with notes, MCQs and past papers organised around your professional year.',
      'WELCOME TO HYZEN',
    ),
    (
      'library',
      'Your library.\nAlways within reach.',
      'Find subjects, explore study materials and continue your Pharm-D journey in one place.',
      'STUDY WITH CLARITY',
    ),
    (
      'downloads',
      'Learn anywhere.\nEven offline.',
      'Save your study notes and open them again when you do not have an internet connection.',
      'READY WHEN YOU ARE',
    ),
  ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _onPrimaryPressed() {
    if (_index == _content.length - 1) {
      context.push('/login');
      return;
    }
    _pages.nextPage(duration: HMotion.medium, curve: Curves.easeInOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? const Color(0xFF101112) : Colors.white;
    final ink = dark ? const Color(0xFFF8F8F8) : const Color(0xFF111111);
    final secondary = dark ? const Color(0xFFB0B0B0) : const Color(0xFF737373);
    final panel = dark ? const Color(0xFF1C2020) : const Color(0xFFF4F6F5);
    final inactive = dark ? const Color(0xFF515656) : const Color(0xFFD9DEDC);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
                  child: Row(
                    children: [
                      Image.asset(
                        Brand.logoAsset,
                        width: 37,
                        height: 37,
                        color: ink,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PHARM D WITH HYZEN',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: ink,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                            Text(
                              'Your pharmacy journey',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: secondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/login'),
                        style: TextButton.styleFrom(foregroundColor: secondary),
                        child: const Text('Skip'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: _content.length,
                    onPageChanged: (page) => setState(() => _index = page),
                    itemBuilder: (context, i) {
                      final page = _content[i];
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final artHeight =
                              (constraints.maxHeight * .41).clamp(165.0, 310.0).toDouble();
                          return SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(24, 30, 24, 14),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: (constraints.maxHeight - 44).clamp(0.0, double.infinity).toDouble(),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    page.$4,
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: _deepTeal,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.8,
                                    ),
                                  ),
                                  const SizedBox(height: 15),
                                  Text(
                                    page.$2,
                                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                      color: ink,
                                      fontSize: 34,
                                      height: 1.13,
                                      letterSpacing: -1.25,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 15),
                                  Text(
                                    page.$3,
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: secondary,
                                      fontSize: 14,
                                      height: 1.55,
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  Container(
                                    height: artHeight,
                                    width: double.infinity,
                                    clipBehavior: Clip.antiAlias,
                                    decoration: BoxDecoration(
                                      color: panel,
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: ColorFiltered(
                                              colorFilter: _grayFilter,
                                              child: i == 0
                                                  ? Image.asset(
                                                      'assets/illustrations/welcome.png',
                                                      fit: BoxFit.contain,
                                                    )
                                                  : Center(
                                                      child: HyzenArt(
                                                        page.$1,
                                                        size: artHeight * .79,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 17,
                                          right: 17,
                                          child: Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: _deepTeal.withValues(alpha: .11),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.auto_awesome_outlined,
                                              color: _deepTeal,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Semantics(
                  label: 'Onboarding page ${_index + 1} of ${_content.length}',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _content.length; i++)
                        AnimatedContainer(
                          duration: HMotion.fast,
                          curve: Curves.easeOut,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 5,
                          width: i == _index ? 25 : 8,
                          decoration: BoxDecoration(
                            color: i == _index ? _deepTeal : inactive,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
                  child: FilledButton(
                    onPressed: _onPrimaryPressed,
                    style: FilledButton.styleFrom(
                      backgroundColor: ink,
                      foregroundColor: background,
                      minimumSize: const Size.fromHeight(56),
                      shape: const StadiumBorder(),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _index == 0
                              ? 'Get Started'
                              : _index == 2
                                  ? 'Log in'
                                  : 'Continue',
                        ),
                        const SizedBox(width: 9),
                        const Icon(Icons.arrow_forward_rounded, size: 19),
                      ],
                    ),
                  ),
                ),
                if (_index != 2)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account?',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: secondary,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/login'),
                        style: TextButton.styleFrom(foregroundColor: ink),
                        child: const Text('Log in'),
                      ),
                    ],
                  ),
                Center(
                  child: TextButton(
                    onPressed: () => context.push('/register/personal'),
                    style: TextButton.styleFrom(foregroundColor: _deepTeal),
                    child: const Text('Create account'),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
