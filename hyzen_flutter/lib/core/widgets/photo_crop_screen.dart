import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// The circular guide overlays (and is excluded from) the square crop export.
/// Every profile surface renders that same square inside ClipOval, so its preview
/// and saved composition agree, without stretching the source photograph.
class PhotoCropScreen extends StatefulWidget {
  const PhotoCropScreen({super.key, required this.bytes});
  final Uint8List bytes;
  @override
  State<PhotoCropScreen> createState() => _PhotoCropScreenState();
}

class _PhotoCropScreenState extends State<PhotoCropScreen> {
  final _capture = GlobalKey();
  final _transform = TransformationController();
  bool _busy = false;
  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _capture.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(
        pixelRatio: 512 / boundary.size.width,
      );
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (mounted && data != null) {
        Navigator.pop(context, data.buffer.asUint8List());
      }
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not crop photo. Please retry.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Crop profile photo'),
      actions: [
        TextButton(
          onPressed: _busy ? null : _save,
          child: const Text('Use photo'),
        ),
      ],
    ),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text('Move and zoom your photo inside the circle.'),
        ),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(
                    key: _capture,
                    child: ClipRect(
                      child: InteractiveViewer(
                        transformationController: _transform,
                        minScale: 1,
                        maxScale: 5,
                        child: Image.memory(
                          widget.bytes,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                    ),
                  ),
                  const IgnorePointer(
                    child: CustomPaint(painter: _CircleGuide()),
                  ),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: TextButton.icon(
            onPressed: () => _transform.value = Matrix4.identity(),
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reset crop'),
          ),
        ),
      ],
    ),
  );
}

class _CircleGuide extends CustomPainter {
  const _CircleGuide();
  @override
  void paint(Canvas canvas, Size size) {
    final circle = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2,
    );
    final mask = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(circle);
    canvas.drawPath(mask, Paint()..color = Colors.black54);
    canvas.drawOval(
      circle,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_CircleGuide oldDelegate) => false;
}
