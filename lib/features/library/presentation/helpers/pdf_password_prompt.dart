import 'dart:async';

import 'package:flutter/material.dart';
import 'package:private_shelf/gen_l10n/app_localizations.dart';

/// One document load's password requests. Keep no password between requests.
/// pdfrx asks again only when the previously submitted value was rejected.
class PdfPasswordPrompt {
  bool _cancelled = false;
  bool _hasSubmitted = false;
  DialogRoute<String>? _route;
  Future<String?>? _pending;

  Future<String?> request(BuildContext context) {
    if (_cancelled || !context.mounted) return Future.value(null);
    return _pending ??= _show(context).whenComplete(() => _pending = null);
  }

  Future<String?> _show(BuildContext context) async {
    // A document loader can call during build. Navigation must wait for it.
    await WidgetsBinding.instance.endOfFrame;
    if (_cancelled || !context.mounted) return null;
    final route = DialogRoute<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PdfPasswordDialog(incorrect: _hasSubmitted),
    );
    _route = route;
    final result = await Navigator.of(context, rootNavigator: true).push(route);
    if (identical(_route, route)) _route = null;
    if (_cancelled) return null;
    _hasSubmitted = result != null;
    return result;
  }

  /// Retire this load when the file changes, retries, or the viewer is removed.
  void cancel() {
    _cancelled = true;
    final route = _route;
    _route = null;
    if (route == null) return;
    // This also runs from didUpdateWidget/dispose. Remove just our route after
    // the frame, never pop a newer dialog or mutate a Navigator during build.
    unawaited(
      WidgetsBinding.instance.endOfFrame.then((_) {
        if (route.isActive) route.navigator?.removeRoute(route);
      }),
    );
  }
}

class _PdfPasswordDialog extends StatefulWidget {
  const _PdfPasswordDialog({required this.incorrect});

  final bool incorrect;

  @override
  State<_PdfPasswordDialog> createState() => _PdfPasswordDialogState();
}

class _PdfPasswordDialogState extends State<_PdfPasswordDialog> {
  final _controller = TextEditingController();
  bool _finished = false;
  bool _obscured = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close(String? result) {
    if (_finished || ModalRoute.of(context)?.isCurrent != true) return;
    _finished = true;
    Navigator.of(context).pop(result);
  }

  void _submit() {
    // Preserve whitespace: it can be part of the document password.
    if (_controller.text.isNotEmpty) {
      _close(_controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      scrollable: true,
      title: Text(l10n.viewerPdfPasswordTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        obscureText: _obscured,
        autocorrect: false,
        enableSuggestions: false,
        enableIMEPersonalizedLearning: false,
        autofillHints: null,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: l10n.viewerPdfPasswordLabel,
          errorText: widget.incorrect ? l10n.viewerPdfPasswordIncorrect : null,
          errorMaxLines: 3,
          suffixIcon: IconButton(
            tooltip: _obscured
                ? l10n.viewerPdfShowPassword
                : l10n.viewerPdfHidePassword,
            onPressed: () => setState(() => _obscured = !_obscured),
            icon: Icon(_obscured ? Icons.visibility : Icons.visibility_off),
          ),
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => _close(null),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: _controller.text.isEmpty ? null : _submit,
          child: Text(l10n.viewerPdfPasswordOpen),
        ),
      ],
    );
  }
}
