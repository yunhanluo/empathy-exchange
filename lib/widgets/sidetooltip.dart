import 'package:flutter/material.dart';
import 'dart:async';

class CustomSideTooltip extends StatefulWidget {
  final Widget child;
  Widget? tooltip;
  final AxisDirection preferredDirection;

  CustomSideTooltip(
      {required this.child,
      this.tooltip,
      this.preferredDirection = AxisDirection.right,
      super.key});

  @override
  _CustomSideTooltipState createState() => _CustomSideTooltipState();
}

class _CustomSideTooltipState extends State<CustomSideTooltip> {
  final GlobalKey _widgetKey = GlobalKey();

  Timer? _timer;

  Widget? tool;

  void _showTooltip() {
    // Get the position and size of the target widget
    final RenderBox renderBox =
        _widgetKey.currentContext!.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;

    _timer?.cancel();

    setState(() {
      tool = Positioned(
        // Position the tooltip based on the target offset and direction
        left: widget.preferredDirection == AxisDirection.right
            ? offset.dx + size.width + 8.0 // To the right, with padding
            : null,
        right: widget.preferredDirection == AxisDirection.left
            ? MediaQuery.of(context).size.width - offset.dx + 8.0 // To the left
            : null,
        top: offset.dy + (size.height / 2) - 16.0, // Centered vertically
        child: Row(children: <Widget>[
          widget.tooltip ?? const SizedBox.shrink(),
        ]),
      );
    });
  }

  void _hideTooltip() {
    _timer?.cancel();

    setState(() {
      tool = widget.child;
    });
  }

  @override
  void dispose() {
    _hideTooltip();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use GestureDetector for mobile (long press) and MouseRegion for web/desktop (hover)
    return GestureDetector(
      key: _widgetKey,
      onLongPress: _showTooltip,
      onLongPressUp: _hideTooltip,
      child: MouseRegion(
        onHover: (_) => _showTooltip(),
        onExit: (_) => Timer(const Duration(milliseconds: 1250), _hideTooltip),
        child: tool ?? widget.child,
      ),
    );
  }
}
