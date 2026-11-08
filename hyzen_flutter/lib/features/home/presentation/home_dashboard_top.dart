import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../study_progress/study_tracker.dart';
import '../../study_progress/campus_rank_screen.dart';
import 'home_time_artwork.dart';

const _blue = Color(0xFF174E8B);

/// Native Flutter reconstruction of the approved Home dashboard summary.
class HomeDashboardTop extends ConsumerWidget {
  const HomeDashboardTop({super.key, required this.year});
  final int? year;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(studyTrackerProvider);
    final weeklyBoard = ref.watch(campusBoardProvider('week')).valueOrNull;
    final rank = weeklyBoard?.mine?.rank;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = dark ? Colors.white : const Color(0xFF091936);
    final percent = (p.todaySeconds / (p.dailyGoal * 60))
        .clamp(0.0, 1.0)
        .toDouble();
    final progressColor = dark ? const Color(0xFF79BCFF) : _blue;
    final heroHeight =
        148 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 4.0);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 9, 16, 0),
          child: Material(
            color: dark ? const Color(0xFF191A1C) : const Color(0xFFF9FBFF),
            borderRadius: BorderRadius.circular(26),
            elevation: dark ? 0 : 2,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push('/study-progress'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: dark
                        ? const Color(0xFF323C4B)
                        : const Color(0xFF9DBBDE),
                  ),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 42,
                      height: 42,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: CircularProgressIndicator(
                              value: percent,
                              strokeWidth: 6,
                              strokeCap: StrokeCap.round,
                              color: progressColor,
                              backgroundColor: dark
                                  ? Colors.white24
                                  : const Color(0xFFD2DFEF),
                            ),
                          ),
                          Icon(
                            Icons.menu_book_rounded,
                            color: progressColor,
                            size: 26,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Study Time',
                            style: TextStyle(
                              color: text,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              formatStudyTime(p.todaySeconds),
                              style: TextStyle(
                                color: text,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 54,
                      color: dark ? Colors.white24 : const Color(0xFF9DACBF),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.gps_fixed_rounded,
                                size: 17,
                                color: progressColor,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  'Daily Goal',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: text,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${p.dailyGoal ~/ 60}h ${(p.dailyGoal % 60).toString().padLeft(2, '0')}m',
                            style: TextStyle(
                              color: text,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 7),
                          LinearProgressIndicator(
                            value: percent,
                            color: progressColor,
                            minHeight: 5,
                            borderRadius: BorderRadius.circular(6),
                            backgroundColor: dark
                                ? Colors.white24
                                : const Color(0xFFD3E0F0),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${(percent * 100).round()}%',
                              style: TextStyle(
                                color: text,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _StatTile(
                  value: '${p.currentStreak} Days',
                  label: 'Study Streak',
                  icon: Icons.local_fire_department_rounded,
                  tint: const Color(0xFFFF923D),
                  onTap: () => context.push('/study-streak'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  value: rank == null
                      ? '—'
                      : '#$rank${weeklyBoard!.cached ? '*' : ''}',
                  label: weeklyBoard?.cached == true
                      ? 'Saved rank'
                      : 'Prof. Rank',
                  icon: Icons.emoji_events_rounded,
                  tint: const Color(0xFFE3B22E),
                  onTap: () => context.push('/campus-rank'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  value:
                      '${p.weekSeconds ~/ 3600}h ${(p.weekSeconds ~/ 60) % 60}m',
                  label: 'This Week',
                  icon: Icons.track_changes_rounded,
                  tint: progressColor,
                  onTap: () => context.push('/study-goals'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: HomePhaseArtwork(
            height: heroHeight,
            builder: (context, phase) => Stack(
              children: [
                Positioned.fill(
                  child: HomeLandscape(
                    phase: phase,
                    height: heroHeight,
                    key: const ValueKey('home-hero-art'),
                  ),
                ),
                Positioned(
                  top: 14,
                  left: 12,
                  right: 12,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      key: const ValueKey('home-continue-study'),
                      onPressed: () {
                        p.start();
                        context.go('/study');
                      },
                      icon: const Icon(Icons.play_arrow_rounded, size: 19),
                      label: const Text('Continue to Study'),
                      style: FilledButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: dark ? const Color(0xFF21588F) : _blue,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  bottom: 14,
                  child: Material(
                    key: const ValueKey('home-professional-badge'),
                    color: dark
                        ? const Color(0xEE152338)
                        : const Color(0xEFFFFFFF),
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      onTap: () => context.push('/profile'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.school_outlined,
                              size: 17,
                              color: dark ? Colors.white : _blue,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              year == null
                                  ? 'Your academic year'
                                  : 'Pharm D · Year $year',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                color: dark
                                    ? Colors.white
                                    : const Color(0xFF142C4F),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.icon,
    required this.tint,
    required this.onTap,
  });
  final String value, label;
  final IconData icon;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? const Color(0xFF1C1D20) : const Color(0xFFF7FAFF),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      elevation: dark ? 0 : 2,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 19, color: tint),
                    const SizedBox(width: 4),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          value,
                          maxLines: 1,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
