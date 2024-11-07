import 'package:flutter/material.dart';

/// This class represents a [CustomPainter] that draws a [scanWindow] rectangle.
class ScanWindowPainter extends CustomPainter {
  /// Construct a new [ScanWindowPainter] instance.
  const ScanWindowPainter({
    required this.scanWindow,
    this.color = const Color(0x80000000),
  });

  /// The color for the scan window box.
  final Color color;

  /// The rectangle defining the scan window.
  ///
  /// Defaults to [Colors.black] with 50% opacity.
  final Rect scanWindow;

  @override
  void paint(Canvas canvas, Size size) {
    if (scanWindow.isEmpty || scanWindow.isInfinite) {
      return;
    }

    // Define the main overlay path covering the entire screen
    final backgroundPath = Path()..addRect(Offset.zero & size);

    // Define the cutout path in the center
    final cutoutPath = Path()..addRect(scanWindow);

    // Combine the two paths: overlay minus the cutout area
    final overlayWithCutoutPath = Path.combine(PathOperation.difference, backgroundPath, cutoutPath);

    // Paint the overlay with the cutout
    final paint = Paint()..color = Colors.black.withOpacity(0.5);
    canvas.drawPath(overlayWithCutoutPath, paint);
  }

  @override
  bool shouldRepaint(ScanWindowPainter oldDelegate) {
    return oldDelegate.scanWindow != scanWindow || oldDelegate.color != color;
  }
}
