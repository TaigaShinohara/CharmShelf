import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:private_shelf/features/security/domain/repositories/security_repository.dart';

part 'security_repository_provider.g.dart';

@riverpod
SecurityRepository securityRepository(Ref ref) {
  throw UnimplementedError('Provider was not overridden');
}
