import 'package:flutter/material.dart';

/// Enveloppe un élément (ex. chip de statut) : un **appui prolongé** affiche une
/// petite info-bulle premium (fond blanc, contour + pointe à la couleur donnée)
/// avec [infoText] ; elle disparaît au relâchement. Le [onTap] éventuel reste
/// actif (le long-press ne le déclenche pas).
class LongPressInfoBubble extends StatefulWidget {
  final Widget child;
  final String infoText;
  final Color color;
  final VoidCallback? onTap;

  const LongPressInfoBubble({
    super.key,
    required this.child,
    required this.infoText,
    required this.color,
    this.onTap,
  });

  @override
  State<LongPressInfoBubble> createState() => _LongPressInfoBubbleState();
}

class _LongPressInfoBubbleState extends State<LongPressInfoBubble> {
  static const double _tailHeight = 7;

  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  void _show() {
    if (_entry != null) return;
    _entry = OverlayEntry(
      builder: (context) => Positioned(
        // Au moins une contrainte (left/top) pour que l'overlay dimensionne
        // l'enfant à son contenu au lieu de l'étirer au plein écran.
        left: 0,
        top: 0,
        child: CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.topCenter,
          followerAnchor: Alignment.bottomCenter,
          offset: const Offset(0, -6),
          child: Material(
            color: Colors.transparent,
            child: MediaQuery.withNoTextScaling(child: _bubble()),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_entry!);
  }

  void _hide() {
    _entry?.remove();
    _entry = null;
  }

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  Widget _bubble() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6 + _tailHeight),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: _BubbleTailBorder(
          color: widget.color,
          radius: 9,
          tailWidth: 12,
          tailHeight: _tailHeight,
          strokeWidth: 1.2,
        ),
        shadows: [
          BoxShadow(
            color: widget.color.withValues(alpha: 0.22),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        widget.infoText,
        style: TextStyle(
            color: widget.color, fontSize: 13, fontWeight: FontWeight.bold),
        maxLines: 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPressStart: (_) => _show(),
        onLongPressEnd: (_) => _hide(),
        onLongPressCancel: _hide,
        child: widget.child,
      ),
    );
  }
}

/// Forme de bulle : corps arrondi + pointe centrée vers le bas.
class _BubbleTailBorder extends ShapeBorder {
  final Color color;
  final double radius;
  final double tailWidth;
  final double tailHeight;
  final double strokeWidth;

  const _BubbleTailBorder({
    required this.color,
    required this.radius,
    required this.tailWidth,
    required this.tailHeight,
    required this.strokeWidth,
  });

  Path _buildPath(Rect rect) {
    final body = Rect.fromLTRB(
        rect.left, rect.top, rect.right, rect.bottom - tailHeight);
    final r = Radius.circular(radius);
    final tailCenter = rect.center.dx;
    final tailLeft = tailCenter - tailWidth / 2;
    final tailRight = tailCenter + tailWidth / 2;

    return Path()
      ..moveTo(body.left + radius, body.top)
      ..lineTo(body.right - radius, body.top)
      ..arcToPoint(Offset(body.right, body.top + radius), radius: r)
      ..lineTo(body.right, body.bottom - radius)
      ..arcToPoint(Offset(body.right - radius, body.bottom), radius: r)
      ..lineTo(tailRight, body.bottom)
      ..lineTo(tailCenter + 1.5, body.bottom + tailHeight - 1.5)
      ..quadraticBezierTo(tailCenter, body.bottom + tailHeight,
          tailCenter - 1.5, body.bottom + tailHeight - 1.5)
      ..lineTo(tailLeft, body.bottom)
      ..lineTo(body.left + radius, body.bottom)
      ..arcToPoint(Offset(body.left, body.bottom - radius), radius: r)
      ..lineTo(body.left, body.top + radius)
      ..arcToPoint(Offset(body.left + radius, body.top), radius: r)
      ..close();
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _buildPath(rect);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _buildPath(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    canvas.drawPath(_buildPath(rect), paint);
  }

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.only(bottom: tailHeight);

  @override
  ShapeBorder scale(double t) => _BubbleTailBorder(
        color: color,
        radius: radius * t,
        tailWidth: tailWidth * t,
        tailHeight: tailHeight * t,
        strokeWidth: strokeWidth * t,
      );
}
