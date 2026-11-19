import 'dart:math' as math;
import '../../../core/widgets/workspace_icons.dart';
import '../../../core/widgets/slide_continue.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
            const HyzenBrandIcon(size: 64),
            const SizedBox(height: 14),
            Text(
              'Pharm D with Hyzen',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const HyzenRiveMascot(
              state: HyzenRiveState.loading,
              size: 140,
              semanticLabel: 'Hyzen panda loading your study space',
            ),
            const SizedBox(height: 16),
            const SizedBox(
              width: 100,
              child: LinearProgressIndicator(minHeight: 3),
            ),
            const SizedBox(height: 12),
            Text(
              'Preparing your study space…',
              style: Theme.of(context).textTheme.bodySmall,
            ),
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

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _pages = PageController();
  int _index = 0;
  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _continue() {
    if (_index == 2) {
      context.push('/login');
      return;
    }
    _pages.nextPage(
      duration: HMotion.duration(context, HMotion.medium),
      curve: HMotion.curve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pharm D with Hyzen',
                      style: t.textTheme.labelMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/login'),
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: 3,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => LayoutBuilder(
                  builder: (context, c) {
                    final artHeight = (c.maxHeight * .62).clamp(220.0, 430.0);
                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          SizedBox(
                            height: artHeight,
                            width: double.infinity,
                            child: i == 0
                                ? Stack(
                                    alignment: Alignment.bottomCenter,
                                    children: [
                                      const Positioned.fill(
                                        child: CustomPaint(
                                          painter: _LearningArcs(),
                                        ),
                                      ),
                                      WorkspaceIcon(
                                        WorkspaceGlyph.panda,
                                        size: artHeight * .82,
                                      ),
                                    ],
                                  )
                                : Center(
                                    child: HyzenRiveMascot(
                                      state: i == 1
                                          ? HyzenRiveState.studying
                                          : HyzenRiveState.downloading,
                                      size: artHeight * .85,
                                    ),
                                  ),
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(36),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  i == 0
                                      ? 'Thrilled to join\nyour learning\njourney!'
                                      : i == 1
                                      ? 'Your pharmacy\nlibrary, together.'
                                      : 'Take your notes.\nStudy anywhere.',
                                  textAlign: TextAlign.center,
                                  style: t.textTheme.displaySmall?.copyWith(
                                    fontSize: c.maxWidth < 350 ? 27 : 32,
                                    height: 1.17,
                                    letterSpacing: -.9,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  i == 0
                                      ? 'Learn, practise and grow with Hyzen.\nYour pharmacy journey starts here.'
                                      : i == 1
                                      ? 'Notes, MCQs, lectures and past papers,\norganised around your professional year.'
                                      : 'Save your study material once.\nRead it again, even when you are offline.',
                                  textAlign: TextAlign.center,
                                  style: t.textTheme.bodyMedium?.copyWith(
                                    color: HColors.ink2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 3; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: 4,
                    width: i == _index ? 18 : 4,
                    decoration: BoxDecoration(
                      color: i == _index ? HColors.ink : HColors.outlineStrong,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: SlideContinue(
                    key: ValueKey('welcome-slide-$_index'),
                    label: _index == 2
                        ? 'Slide to log in'
                        : 'Slide to continue',
                    semanticLabel: _index == 2
                        ? 'Log in'
                        : 'Continue onboarding',
                    onComplete: _continue,
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.push('/register/personal'),
              child: const Text('Create account'),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _LearningArcs extends CustomPainter {
  const _LearningArcs();
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .5, size.height * .94);
    final radius = size.width * .54;
    for (final (i, color) in [
      const Color(0xFFDBDBE0),
      HColors.sage,
      HColors.apricot,
      const Color(0xFFB9DFEA),
    ].indexed) {
      final r = radius - i * 22;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        math.pi + .14,
        math.pi - .28,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_LearningArcs oldDelegate) => false;
}
