import 'package:flutter/material.dart';
import '../theme/tokens.dart';

class SlideContinue extends StatefulWidget {
  const SlideContinue({
    super.key,
    required this.label,
    required this.semanticLabel,
    required this.onComplete,
  });
  final String label, semanticLabel;
  final VoidCallback onComplete;
  @override
  State<SlideContinue> createState() => _SlideContinueState();
}

class _SlideContinueState extends State<SlideContinue> {
  double _offset = 0;
  bool _dragging = false, _completed = false;
  void _complete() {
    if (_completed) return;
    _completed = true;
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: widget.semanticLabel,
    onTap: _complete,
    child: ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, box) {
          final travel = (box.maxWidth - 56).clamp(1.0, double.infinity);
          return GestureDetector(
            key: const ValueKey('onboarding-slide'),
            behavior: HitTestBehavior.opaque,
            onTap: _complete,
            onHorizontalDragStart: (_) => setState(() => _dragging = true),
            onHorizontalDragUpdate: (event) => setState(
              () => _offset = (_offset + event.delta.dx).clamp(0.0, travel),
            ),
            onHorizontalDragEnd: (_) {
              if (_offset >= travel * .72) {
                _complete();
              } else {
                setState(() {
                  _dragging = false;
                  _offset = 0;
                });
              }
            },
            onHorizontalDragCancel: () => setState(() {
              _dragging = false;
              _offset = 0;
            }),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFE9E2F3),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 38),
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: _dragging
                        ? Duration.zero
                        : HMotion.duration(context, HMotion.fast),
                    left: 4 + _offset,
                    top: 4,
                    bottom: 4,
                    child: Container(
                      width: 48,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_forward_rounded, size: 19),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}
