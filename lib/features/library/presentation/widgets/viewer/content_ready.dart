import 'package:flutter/material.dart';

/// Reports successful content after it has participated in a frame.
/// The owner deduplicates reports and checks that this is the settled page.
void reportViewerContentReady(BuildContext context, VoidCallback? callback) {
  if (callback == null) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted) callback();
  });
}
