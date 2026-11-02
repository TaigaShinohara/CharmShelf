// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'archive_media_item_use_case.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(archiveMediaItemUseCase)
final archiveMediaItemUseCaseProvider = ArchiveMediaItemUseCaseProvider._();

final class ArchiveMediaItemUseCaseProvider
    extends
        $FunctionalProvider<
          AsyncValue<ArchiveMediaItemUseCase>,
          ArchiveMediaItemUseCase,
          FutureOr<ArchiveMediaItemUseCase>
        >
    with
        $FutureModifier<ArchiveMediaItemUseCase>,
        $FutureProvider<ArchiveMediaItemUseCase> {
  ArchiveMediaItemUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'archiveMediaItemUseCaseProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$archiveMediaItemUseCaseHash();

  @$internal
  @override
  $FutureProviderElement<ArchiveMediaItemUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ArchiveMediaItemUseCase> create(Ref ref) {
    return archiveMediaItemUseCase(ref);
  }
}

String _$archiveMediaItemUseCaseHash() =>
    r'3624f68652561fc94552d9c24bdffbb2bc505c22';
