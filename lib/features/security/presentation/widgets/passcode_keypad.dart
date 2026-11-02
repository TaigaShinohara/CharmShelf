import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:private_shelf/core/feedback/feedback_providers.dart';
import 'package:private_shelf/shared/widgets/text/app_text.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

class PasscodeKeypad extends ConsumerWidget {
  const PasscodeKeypad({
    super.key,
    required this.onDigitPress,
    required this.onDeletePress,
    this.onBiometricsPress,
    this.showBiometrics = false,
    this.enabled = true,
  });

  final void Function(int digit) onDigitPress;
  final VoidCallback onDeletePress;
  final VoidCallback? onBiometricsPress;
  final bool showBiometrics;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < 3; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var col = 1; col <= 3; col++)
                  _KeyButton(
                    digit: row * 3 + col,
                    onPressed: enabled
                        ? () {
                            ref.read(feedbackServiceProvider).lightImpact();
                            onDigitPress(row * 3 + col);
                          }
                        : null,
                  ),
              ],
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (showBiometrics)
              _IconButton(
                icon: Icons.fingerprint,
                tooltip: l10n.passcodeBiometrics,
                onPressed: enabled
                    ? () {
                        ref.read(feedbackServiceProvider).lightImpact();
                        onBiometricsPress?.call();
                      }
                    : null,
              )
            else
              const ExcludeSemantics(child: SizedBox(width: 80, height: 80)),
            _KeyButton(
              digit: 0,
              onPressed: enabled
                  ? () {
                      ref.read(feedbackServiceProvider).lightImpact();
                      onDigitPress(0);
                    }
                  : null,
            ),
            _IconButton(
              icon: Icons.backspace_outlined,
              tooltip: l10n.passcodeDelete,
              onPressed: enabled
                  ? () {
                      ref.read(feedbackServiceProvider).lightImpact();
                      onDeletePress();
                    }
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({required this.digit, required this.onPressed});

  final int digit;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Semantics(
        excludeSemantics: true,
        button: true,
        enabled: onPressed != null,
        label: '$digit',
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            shape: const CircleBorder(),
            side: BorderSide(color: Theme.of(context).dividerColor),
          ),
          child: AppText(
            '$digit',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Semantics(
        excludeSemantics: true,
        button: true,
        enabled: onPressed != null,
        label: tooltip,
        child: IconButton(
          tooltip: null,
          onPressed: onPressed,
          icon: Icon(icon, size: 32),
        ),
      ),
    );
  }
}
