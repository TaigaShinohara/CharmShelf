import 'dart:async';
import 'package:flutter/material.dart';

/// Keep the layout stable and avoid flashing a spinner for fast local work.
class DeferredProgressBar extends StatefulWidget {
  const DeferredProgressBar({super.key, required this.active});
  final bool active;

  @override
  State<DeferredProgressBar> createState() => _DeferredProgressBarState();
}

class _DeferredProgressBarState extends State<DeferredProgressBar> {
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _update();
  }

  @override
  void didUpdateWidget(DeferredProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _update();
  }

  void _update() {
    _timer?.cancel();
    if (!widget.active) {
      _visible = false;
    } else {
      _timer = Timer(const Duration(milliseconds: 120), () {
        if (mounted) setState(() => _visible = true);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 2,
    child: _visible ? const LinearProgressIndicator(minHeight: 2) : null,
  );
}
