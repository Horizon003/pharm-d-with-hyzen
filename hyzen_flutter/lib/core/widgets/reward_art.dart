import 'package:flutter/material.dart';

/// Generated, equal-cell illustrations share one cached texture.
class RewardArt extends StatelessWidget {
  const RewardArt(
    this.index, {
    super.key,
    this.size = 48,
    this.claimed = false,
  });
  final int index;
  final double size;
  final bool claimed;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            left: -(index % 4) * size,
            top: -(index ~/ 4) * size,
            width: size * 4,
            height: size * 4,
            child: Image.asset(
              'assets/reference/reward-pandas.png',
              fit: BoxFit.fill,
              cacheWidth: 1256,
            ),
          ),
          if (claimed)
            Positioned.fill(child: CustomPaint(painter: _ClaimSash())),
        ],
      ),
    ),
  );
}

class _ClaimSash extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xffd14f50)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * .23, size.height * .77),
      Offset(size.width * .77, size.height * .23),
      p,
    );
  }

  @override
  bool shouldRepaint(_ClaimSash old) => false;
}
