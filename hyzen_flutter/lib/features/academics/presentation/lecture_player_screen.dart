import 'package:flutter/material.dart';
import '../../../core/utils/youtube.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/refinement_art.dart';
import '../../../core/widgets/surfaces.dart';
import '../../study_progress/document_study_scope.dart';
import 'player/lecture_surface.dart';

class LecturePlayerScreen extends StatefulWidget {
  const LecturePlayerScreen({
    super.key,
    required this.title,
    required this.url,
  });
  final String title, url;
  @override
  State<LecturePlayerScreen> createState() => _LecturePlayerScreenState();
}

class _LecturePlayerScreenState extends State<LecturePlayerScreen> {
  bool ready = false;
  @override
  Widget build(BuildContext context) {
    final uri = youtubeEmbedUri(widget.url);
    return HBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const HTopBar(title: 'Lecture room'),
        body: SafeArea(
          child: DocumentStudyScope(
            ready: ready,
            child: LayoutBuilder(
              builder: (context, c) {
                final player = ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: ColoredBox(
                    color: const Color(0xff101014),
                    child: uri == null
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                'This lecture needs a valid YouTube video or playlist link.',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          )
                        : LectureSurface(
                            uri: uri,
                            onReady: () {
                              if (mounted && !ready) {
                                setState(() => ready = true);
                              }
                            },
                          ),
                  ),
                );
                if (c.maxWidth > c.maxHeight * 1.4) {
                  return Padding(
                    padding: const EdgeInsets.all(8),
                    child: player,
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    AspectRatio(aspectRatio: 16 / 9, child: player),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const RefinementArt(RefinementGlyph.lecture, size: 42),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Stay in your study space. Use the player controls to pause, replay or change playback speed.',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Some creators restrict embedded playback. If the player says this video is unavailable, ask for an embeddable lecture link.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
