import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../gen_l10n/app_localizations.dart';
import '../data/device_storage.dart';

/// Shared by onboarding and the device browser. Never requests without a tap.
class DeviceAccessPanel extends ConsumerStatefulWidget {
  const DeviceAccessPanel({
    super.key,
    this.onChanged,
    this.showExplanation = true,
  });
  final VoidCallback? onChanged;
  final bool showExplanation;
  @override
  ConsumerState<DeviceAccessPanel> createState() => _DeviceAccessPanelState();
}

class _DeviceAccessPanelState extends ConsumerState<DeviceAccessPanel>
    with WidgetsBindingObserver {
  bool _allowed = false, _busy = false, _error = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_check(notify: false));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_check());
  }

  Future<void> _check({bool notify = true}) async {
    try {
      final allowed = await ref.read(deviceStorageProvider).allowed();
      if (!mounted) return;
      final changed = allowed != _allowed;
      setState(() {
        _allowed = allowed;
        _error = false;
      });
      if (changed && notify) widget.onChanged?.call();
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _request() async {
    setState(() => _busy = true);
    try {
      await ref.read(deviceStorageProvider).requestPermission();
      await _check();
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showExplanation) ...[
          Text(l.deviceAccessExplanation),
          const SizedBox(height: 16),
        ],
        if (_error) Text(l.deviceReadError),
        if (_allowed)
          Text(l.deviceAccessGranted)
        else
          FilledButton(
            onPressed: _busy ? null : _request,
            child: Text(l.deviceAllowAccess),
          ),
      ],
    );
  }
}
