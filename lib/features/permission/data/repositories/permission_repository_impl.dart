import 'dart:io';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/repositories/permission_repository.dart';

part 'permission_repository_impl.g.dart';

class PermissionRepositoryImpl implements PermissionRepository {
  @override
  Future<PermissionResult> getNotificationPermissionStatus() async {
    return _mapStatus(await ph.Permission.notification.status);
  }

  @override
  Future<PermissionResult> requestStoragePermission() async {
    ph.PermissionStatus status;
    if (Platform.isAndroid) {
      // Android 13+ (API 33+) では storage は非推奨となり photos/videos を使用
      final photosStatus = await ph.Permission.photos.status;
      if (photosStatus.isGranted || photosStatus.isLimited) {
        return PermissionResult.granted;
      }

      // まず photos 権限を要求
      status = await ph.Permission.photos.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        // Android 12以下向けに従来の storage 権限も試行
        final storageStatus = await ph.Permission.storage.request();
        if (storageStatus.isGranted) {
          status = storageStatus;
        }
      }
    } else {
      // iOS
      status = await ph.Permission.photos.request();
    }
    return _mapStatus(status);
  }

  @override
  Future<PermissionResult> getManageStoragePermissionStatus() async {
    if (!Platform.isAndroid) {
      return PermissionResult.granted;
    }
    // Release uses scoped document access; legacy callers must not assume
    // device-wide access even if an older version had obtained it.
    return PermissionResult.denied;
  }

  @override
  Future<PermissionResult> requestManageStoragePermission() async {
    if (!Platform.isAndroid) {
      return PermissionResult.granted;
    }
    return PermissionResult.denied;
  }

  @override
  Future<PermissionResult> requestNotificationPermission() async {
    final status = await ph.Permission.notification.request();
    return _mapStatus(status);
  }

  @override
  Future<bool> openAppSettings() async {
    return ph.openAppSettings();
  }

  PermissionResult _mapStatus(ph.PermissionStatus status) {
    switch (status) {
      case ph.PermissionStatus.granted:
      case ph.PermissionStatus.limited:
        return PermissionResult.granted;
      case ph.PermissionStatus.denied:
        return PermissionResult.denied;
      case ph.PermissionStatus.permanentlyDenied:
        return PermissionResult.permanentlyDenied;
      case ph.PermissionStatus.restricted:
        return PermissionResult.restricted;
      case ph.PermissionStatus.provisional:
        return PermissionResult.granted; // iOSの暫定許可
    }
  }
}

@riverpod
PermissionRepository permissionRepository(Ref ref) {
  return PermissionRepositoryImpl();
}

@riverpod
Future<PermissionResult> notificationPermissionStatus(
  Ref ref,
) {
  return ref
      .watch(permissionRepositoryProvider)
      .getNotificationPermissionStatus();
}
