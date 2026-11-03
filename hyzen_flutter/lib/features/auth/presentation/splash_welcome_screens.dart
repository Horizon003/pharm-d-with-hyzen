import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/rive_mascot.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HyzenBrandIcon(size: 72),
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
            const HyzenRiveMascot(
              state: HyzenRiveState.loading,
              size: 180,
              semanticLabel: 'Hyzen panda loading your study space',
            ),
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

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key, this.replay = false});
  final bool replay;
  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _pages = PageController();
  int _index = 0;
  bool _checkingFirstRun = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final completed =
          ref.read(sharedPrefsProvider).getBool('pref_tutorial_completed') ??
          false;
      if (completed && !widget.replay) {
        context.go('/login');
        return;
      }
      setState(() => _checkingFirstRun = false);
    });
  }

  Future<void> _finish({String destination = '/login'}) async {
    await ref
        .read(sharedPrefsProvider)
        .setBool('pref_tutorial_completed', true);
    if (!mounted) return;
    if (widget.replay) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    } else {
      context.go(destination);
    }
  }
  static const _content = [
    (
      'welcome',
      'Your smart\nPharm-D study partner',
      'Learn with notes, MCQs and past papers, organised around your professional year.',
    ),
    (
      'library',
      'Every library,\nat your fingertips.',
      'Find the right subject, practise questions and continue your pharmacy journey.',
    ),
    (
      'downloads',
      'Read anywhere.\nEven offline.',
      'Save your study notes once and open them again without an internet connection.',
    ),
  ];
  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    if (_checkingFirstRun) {
      return const Scaffold(
        body: Center(child: HyzenBrandIcon(size: 52)),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                children: [
                  const HyzenBrandIcon(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PHARM D',
                          style: t.textTheme.headlineMedium?.copyWith(
                            color: t.colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text('WITH HYZEN · Your pharmacy journey'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: _content.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final item = _content[i];
                  return LayoutBuilder(
                    builder: (context, c) => SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: i == 0
                          ? Column(
                              children: [
                                Container(
                                  height: (c.maxHeight * .52).clamp(170, 380),
                                  width: double.infinity,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(36),
                                    gradient: RadialGradient(
                                      center: const Alignment(0, -.2),
                                      radius: .95,
                                      colors: t.brightness == Brightness.dark
                                          ? const [
                                              Color(0xFF454548),
                                              Color(0xFF19191B),
                                            ]
                                          : const [
                                              Color(0xFFFAFAFA),
                                              Color(0xFFE2E2E5),
                                            ],
                                    ),
                                  ),
                                  child: const HyzenRiveMascot(
                                    state: HyzenRiveState.welcome,
                                    size: 210,
                                    semanticLabel: 'Hyzen panda welcoming you',
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(22),
                                  decoration: BoxDecoration(
                                    color: t.colorScheme.surface,
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Your Brain',
                                        style: t.textTheme.displaySmall
                                            ?.copyWith(fontSize: 36),
                                      ),
                                      Text(
                                        'Called. It wants more 👋',
                                        style: t.textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 18),
                                      Text(
                                        'Small lessons. Big wins. Your Pharm-D journey starts here.',
                                        style: t.textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                HyzenRiveMascot(
                                  key: ValueKey('onboarding-mascot-$i'),
                                  state: i == 1
                                      ? HyzenRiveState.studying
                                      : HyzenRiveState.downloading,
                                  size: (c.maxHeight * .42).clamp(180, 280),
                                  semanticLabel: i == 1
                                      ? 'Hyzen panda studying with a pharmacy notebook'
                                      : 'Hyzen panda helping you save files offline',
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  item.$2,
                                  textAlign: TextAlign.center,
                                  style: t.textTheme.displaySmall?.copyWith(
                                    fontSize: 29,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  item.$3,
                                  textAlign: TextAlign.center,
                                  style: t.textTheme.bodyLarge?.copyWith(
                                    color: t.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 3; i++)
                  AnimatedContainer(
                    duration: HMotion.fast,
                    margin: const EdgeInsets.all(3),
                    height: 6,
                    width: i == _index ? 25 : 12,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? t.colorScheme.primary
                          : t.colorScheme.primary.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
              child: FilledButton(
                onPressed: () => _index < 2
                    ? _pages.nextPage(
                        duration: HMotion.medium,
                        curve: Curves.easeOut,
                      )
                    : _finish(),
                style: FilledButton.styleFrom(
                  backgroundColor: t.brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                  foregroundColor: t.brightness == Brightness.dark
                      ? Colors.black
                      : Colors.white,
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  _index == 0
                      ? 'Get Started →'
                      : _index == 2
                      ? 'Log in →'
                      : 'Continue →',
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: _finish,
                  child: const Text('Skip'),
                ),
                TextButton(
                  onPressed: () => _finish(destination: '/register/personal'),
                  child: const Text('Create account'),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
