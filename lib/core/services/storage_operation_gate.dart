import 'dart:async';
import '../error/app_error.dart';
import '../error/result.dart';

/// Blocks conflicting storage work while legacy data is being changed.
/// Nested calls made by the migration itself may use the normal services.
class StorageOperationBusy implements Exception {
  const StorageOperationBusy();
}

abstract final class StorageOperationGate {
  static final _zoneKey = Object();
  static int _normalOperations = 0;
  static bool _maintenanceRunning = false;
  static bool recoveryRequired = false;

  static bool get isBusy => _normalOperations > 0 || _maintenanceRunning;

  static Future<T> run<T>(Future<T> Function() action) async {
    if (Zone.current[_zoneKey] == true) return action();
    if (_maintenanceRunning || recoveryRequired) {
      throw const StorageOperationBusy();
    }
    _normalOperations++;
    try {
      return await runZoned(action, zoneValues: {_zoneKey: true});
    } finally {
      _normalOperations--;
    }
  }

  static Future<Result<T, AppError>> runResult<T>(
    Future<Result<T, AppError>> Function() action,
  ) async {
    try {
      return await run(action);
    } on StorageOperationBusy catch (error) {
      return Result.failure(
        AppError.file(
          'A data transfer must finish before this operation can start.',
          original: error,
        ),
      );
    }
  }

  static Future<T> maintenance<T>(Future<T> Function() action) async {
    if (isBusy) throw const StorageOperationBusy();
    _maintenanceRunning = true;
    try {
      return await runZoned(action, zoneValues: {_zoneKey: true});
    } finally {
      _maintenanceRunning = false;
    }
  }
}
