// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_media_stream_use_case.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(getMediaStreamUseCase)
final getMediaStreamUseCaseProvider = GetMediaStreamUseCaseProvider._();

final class GetMediaStreamUseCaseProvider
    extends
        $FunctionalProvider<
          GetMediaStreamUseCase,
          GetMediaStreamUseCase,
          GetMediaStreamUseCase
        >
    with $Provider<GetMediaStreamUseCase> {
  GetMediaStreamUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'getMediaStreamUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$getMediaStreamUseCaseHash();

  @$internal
  @override
  $ProviderElement<GetMediaStreamUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  GetMediaStreamUseCase create(Ref ref) {
    return getMediaStreamUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GetMediaStreamUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GetMediaStreamUseCase>(value),
    );
  }
}

String _$getMediaStreamUseCaseHash() =>
    r'26d89326f9ec6c6da1cd851701956ea378b16231';
