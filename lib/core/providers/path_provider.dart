import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/private_storage_service.dart';

part 'path_provider.g.dart';

@riverpod
Future<String> applicationDocumentsPath(Ref ref) async {
  final dir = await getPrivateStorageDirectory();
  return dir.path;
}

@Riverpod(keepAlive: true)
String appDocumentsPathSync(Ref ref) {
  throw UnimplementedError(
    'appDocumentsPathSyncProvider must be overridden in ProviderScope',
  );
}
