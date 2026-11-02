import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// Recreate cached settings, navigation, and security state after a full reset.
final freshStartCompletedCallbackProvider = Provider<VoidCallback>(
  (ref) => () {},
);

class FreshStartScope extends StatefulWidget {
  const FreshStartScope({
    super.key,
    required this.overrides,
    required this.child,
  });

  final List<Override> overrides;
  final Widget child;

  @override
  State<FreshStartScope> createState() => _FreshStartScopeState();
}

class _FreshStartScopeState extends State<FreshStartScope> {
  int _generation = 0;

  void _restart() {
    if (mounted) setState(() => _generation++);
  }

  @override
  Widget build(BuildContext context) => ProviderScope(
    key: ValueKey(_generation),
    // Preserve the existing explicit retry and error-recovery flow.
    retry: (_, _) => null,
    overrides: [
      ...widget.overrides,
      freshStartCompletedCallbackProvider.overrideWithValue(_restart),
    ],
    child: widget.child,
  );
}
