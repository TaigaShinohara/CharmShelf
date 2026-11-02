// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_recent_media_use_case.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(getRecentMediaUseCase)
final getRecentMediaUseCaseProvider = GetRecentMediaUseCaseProvider._();

final class GetRecentMediaUseCaseProvider
    extends
        $FunctionalProvider<
          AsyncValue<GetRecentMediaUseCase>,
          GetRecentMediaUseCase,
          FutureOr<GetRecentMediaUseCase>
        >
    with
        $FutureModifier<GetRecentMediaUseCase>,
        $FutureProvider<GetRecentMediaUseCase> {
  GetRecentMediaUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'getRecentMediaUseCaseProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$getRecentMediaUseCaseHash();

  @$internal
  @override
  $FutureProviderElement<GetRecentMediaUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<GetRecentMediaUseCase> create(Ref ref) {
    return getRecentMediaUseCase(ref);
  }
}

String _$getRecentMediaUseCaseHash() =>
    r'09db4006d9a8e947248b5142448e2bc261c6f9e7';
