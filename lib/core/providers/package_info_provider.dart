import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'package_info_provider.g.dart';

@riverpod
Future<PackageInfo> packageInfo(Ref ref) async {
  return PackageInfo.fromPlatform();
}

@riverpod
String appVersion(Ref ref) {
  return ref
      .watch(packageInfoProvider)
      .when(
        data: (info) => 'v${info.version}',
        loading: () => 'v?.?.?',
        error: (error, stackTrace) => 'v?.?.?',
      );
}

@riverpod
String buildNumber(Ref ref) {
  return ref
      .watch(packageInfoProvider)
      .when(
        data: (info) => info.buildNumber,
        loading: () => '?',
        error: (error, stackTrace) => '?',
      );
}

@riverpod
String appName(Ref ref) {
  return ref
      .watch(packageInfoProvider)
      .when(
        data: (info) => info.appName,
        loading: () => '',
        error: (error, stackTrace) => '',
      );
}
