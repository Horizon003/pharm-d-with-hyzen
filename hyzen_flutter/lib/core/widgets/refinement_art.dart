import 'package:flutter/material.dart';

enum RefinementGlyph { lecture, announcement, document, subject, panda, rank }

/// One shared, generated 2×3 clay illustration atlas, decoded once and reused.
class RefinementArt extends StatelessWidget {
  const RefinementArt(this.glyph, {super.key, this.size = 40});
  final RefinementGlyph glyph;
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: size * 2,
          maxWidth: size * 2,
          minHeight: size * 3,
          maxHeight: size * 3,
          child: Transform.translate(
            offset: Offset(
              -(glyph.index % 2) * size,
              -(glyph.index ~/ 2) * size,
            ),
            child: Image.asset(
              'assets/reference/refinement-atlas.png',
              width: size * 2,
              height: size * 3,
              fit: BoxFit.fill,
              cacheWidth: 1024,
            ),
          ),
        ),
      ),
    ),
  );
}
