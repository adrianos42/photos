import 'dart:math';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/gestures.dart';

class AlphaEffect extends StatelessWidget {
  const AlphaEffect({
    required this.child,
    required this.renders,
    Key? key,
  }) : super(key: key);

  final Widget child;

  final bool renders;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: renders ? _RenderRadio() : null,
      child: child,
    );
  }
}

class _RenderRadio implements CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    var boxSize = (sqrt(size.width * size.width + size.height + size.height) / 30.0).clamp(6.0, 60.0).roundToDouble();

    var yBoxes = size.height / boxSize;
    var xBoxes = size.width / boxSize;

    final darkColor = Color(0xFF404040);
    final lightColor = Color(0xFF808080);

    var previousRowColor = darkColor;
    var rowColor = lightColor;

    for (int x = 0; x < xBoxes; x += 1) {
      final replace = rowColor;
      rowColor = previousRowColor;
      previousRowColor = replace;

      var colColor = rowColor;
      var previousColColor = previousRowColor;

      for (int y = 0; y < yBoxes; y += 1) {
        final replaceCol = colColor;
        colColor = previousColColor;
        previousColColor = replaceCol;

        canvas.clipRect(Rect.fromLTRB(0.0, 0.0, size.width, size.height));    
        canvas.drawRect(Rect.fromLTRB(boxSize * x, boxSize * y, boxSize * x + boxSize, boxSize * y + boxSize),
        Paint()..color = replaceCol);
      }
    }

    
  }

  @override
  void addListener(VoidCallback listener) {}

  @override
  bool? hitTest(Offset position) {}

  void removeListener(VoidCallback listener) {}

  @override
  SemanticsBuilderCallback? get semanticsBuilder => null;

  @override
  bool shouldRebuildSemantics(covariant CustomPainter oldDelegate) => false;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
