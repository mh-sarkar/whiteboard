part of whiteboard;

/// Subclass of [CustomPainter] to paint strokes
class _FreehandPainter extends CustomPainter {
  final List<_Stroke> strokes;
  final Color backgroundColor;

  /// [Color] for background of whiteboard.
  final ui.Image? backgroundImage;

  _FreehandPainter(
    this.strokes,
    this.backgroundColor,
    this.backgroundImage,
  );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    if (backgroundImage != null)
      canvas.drawImage(backgroundImage!, new Offset(0.0, 0.0), new Paint());
    else
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = backgroundColor,
      );

    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    for (final stroke in strokes) {
      final paint = Paint()
        ..strokeWidth = stroke.width
        ..color = stroke.erase ? Colors.transparent : stroke.color
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..blendMode = stroke.erase ? BlendMode.clear : BlendMode.srcOver;
      canvas.drawPath(stroke.path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
