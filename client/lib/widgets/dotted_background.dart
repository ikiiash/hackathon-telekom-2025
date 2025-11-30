import 'package:flutter/material.dart';

/// Reusable widget that provides a polka dot pattern background
class DottedBackground extends StatelessWidget {
  final Widget child;
  final Color? dotColor;
  final double? dotRadius;
  final double? spacing;

  const DottedBackground({
    super.key,
    required this.child,
    this.dotColor,
    this.dotRadius,
    this.spacing,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Polka dot pattern background
        Positioned.fill(
          child: CustomPaint(
            painter: PolkaDotPainter(
              dotColor: dotColor ?? Colors.red.withOpacity(0.05),
              dotRadius: dotRadius ?? 15.0,
              spacing: spacing ?? 60.0,
            ),
          ),
        ),
        // Content
        child,
      ],
    );
  }
}

/// Custom painter for polka dot pattern
class PolkaDotPainter extends CustomPainter {
  final Color dotColor;
  final double dotRadius;
  final double spacing;

  PolkaDotPainter({
    required this.dotColor,
    required this.dotRadius,
    required this.spacing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    int rowIndex = 0;
    for (double y = 0; y < size.height + spacing; y += spacing) {
      int colIndex = 0;
      for (double x = 0; x < size.width + spacing; x += spacing) {
        // Chess/checkerboard pattern: alternate dots
        if ((rowIndex + colIndex) % 2 == 0) {
          canvas.drawCircle(Offset(x, y), dotRadius, paint);
        }
        colIndex++;
      }
      rowIndex++;
    }
  }

  @override
  bool shouldRepaint(PolkaDotPainter oldDelegate) {
    return oldDelegate.dotColor != dotColor ||
        oldDelegate.dotRadius != dotRadius ||
        oldDelegate.spacing != spacing;
  }
}
