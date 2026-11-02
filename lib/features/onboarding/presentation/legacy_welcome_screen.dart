import 'package:flutter/material.dart';
import '../../../gen_l10n/app_localizations.dart';

/// Choose a fresh start or open the existing transfer flow before storage access.
class LegacyWelcomeScreen extends StatefulWidget {
  const LegacyWelcomeScreen({
    super.key,
    required this.onChoice,
    required this.hasResidualData,
  });
  final Future<void> Function(String choice) onChoice;
  final Future<bool> Function() hasResidualData;

  @override
  State<LegacyWelcomeScreen> createState() => _LegacyWelcomeScreenState();
}

class _LegacyWelcomeScreenState extends State<LegacyWelcomeScreen> {
  bool _returning = false;
  bool _busy = false;
  bool _confirming = false;
  bool _failed = false;
  String? _resetChoice;

  Future<void> _transfer() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await widget.onChoice('transfer');
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start({required bool returning}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      // A retry resumes the confirmed operation, without asking to delete again.
      if (_resetChoice == null) {
        final needsConfirmation = returning || await widget.hasResidualData();
        if (!mounted) return;
        if (needsConfirmation) {
          setState(() => _confirming = true);
          final l = AppLocalizations.of(context)!;
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(l.freshStartConfirmTitle),
              scrollable: true,
              content: Text(l.freshStartConfirmBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l.commonCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l.freshStartConfirmAction),
                ),
              ],
            ),
          );
          if (!mounted) return;
          setState(() => _confirming = false);
          if (confirmed != true) return;
        }
        setState(() => _resetChoice = returning ? 'fresh' : 'first');
      }
      await widget.onChoice(_resetChoice!);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final resetting = _resetChoice != null;
    return PopScope(
      canPop: !_busy && !resetting && !_returning,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy && !resetting && _returning) {
          setState(() {
            _returning = false;
            _failed = false;
          });
        }
      },
      child: Scaffold(
        appBar: _returning && !resetting
            ? AppBar(
                leading: BackButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _returning = false;
                          _failed = false;
                        }),
                ),
              )
            : null,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.auto_awesome_outlined,
                      size: 56,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      resetting
                          ? l.freshStartProgress
                          : _returning
                          ? l.legacyReturningEntry
                          : l.legacyWelcomeTitle,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    if (!resetting && !_returning) Text(l.legacyWelcomeBody),
                    const SizedBox(height: 32),
                    if (resetting) ...[
                      if (_failed) Text(l.freshStartFailure),
                      if (!_busy)
                        FilledButton(
                          onPressed: () => _start(returning: _returning),
                          child: Text(l.commonRetry),
                        ),
                    ] else if (_returning) ...[
                      FilledButton(
                        onPressed: _busy ? null : _transfer,
                        child: Text(l.legacyTransferTitle),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _busy ? null : () => _start(returning: true),
                        child: Text(l.legacyStartWithoutTransfer),
                      ),
                    ] else ...[
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _start(returning: false),
                        child: Text(l.legacyFirstUse),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() => _returning = true),
                        child: Text(l.legacyReturningEntry),
                      ),
                    ],
                    if (_busy && !_confirming) const LinearProgressIndicator(),
                    if (_failed && !resetting) ...[
                      const SizedBox(height: 16),
                      Text(
                        l.freshStartCheckFailure,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
