import 'dart:async';

/// Owns one native picker, including notification return and failure cleanup.
class ImportPickerSession {
  bool _active = false;

  Future<T?> run<T>({
    required Future<T?> Function() pick,
    required Future<void> Function() showNotification,
    required Future<void> Function() hideNotification,
    required Stream<void> returns,
  }) async {
    if (_active) return null;
    _active = true;
    final returned = Completer<T?>();
    final subscription = returns.listen((_) {
      if (!returned.isCompleted) returned.complete(null);
    });
    try {
      await showNotification();
      if (returned.isCompleted) return null;
      return await Future.any([pick(), returned.future]);
    } finally {
      await subscription.cancel();
      try {
        await hideNotification();
      } finally {
        _active = false;
      }
    }
  }
}
