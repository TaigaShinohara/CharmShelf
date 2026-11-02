import 'storage_operation_gate.dart';

/// Serializes migration publication with filesystem-to-library reconciliation.
/// Keyed by the open database; failures do not poison subsequent operations.
abstract final class LibraryStorageLock {
  static final _tails = Expando<Future<void>>();
  static Future<T> run<T>(Object database, Future<T> Function() action) {
    return StorageOperationGate.run(() async {
      final next = (_tails[database] ?? Future<void>.value()).then(
        (_) => action(),
      );
      _tails[database] = next.then<void>(
        (_) {},
        onError: (Object _, StackTrace _) {},
      );
      return next;
    });
  }
}
