// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'external_thumbnail_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(externalThumbnail)
final externalThumbnailProvider = ExternalThumbnailFamily._();

final class ExternalThumbnailProvider
    extends
        $FunctionalProvider<
          AsyncValue<Uint8List?>,
          Uint8List?,
          FutureOr<Uint8List?>
        >
    with $FutureModifier<Uint8List?>, $FutureProvider<Uint8List?> {
  ExternalThumbnailProvider._({
    required ExternalThumbnailFamily super.from,
    required MediaItem super.argument,
  }) : super(
         retry: null,
         name: r'externalThumbnailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$externalThumbnailHash();

  @override
  String toString() {
    return r'externalThumbnailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Uint8List?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Uint8List?> create(Ref ref) {
    final argument = this.argument as MediaItem;
    return externalThumbnail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ExternalThumbnailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$externalThumbnailHash() => r'27ec55a4a3d994648f76cec688fcac3ed8e5cdcb';

final class ExternalThumbnailFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Uint8List?>, MediaItem> {
  ExternalThumbnailFamily._()
    : super(
        retry: null,
        name: r'externalThumbnailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ExternalThumbnailProvider call(MediaItem item) =>
      ExternalThumbnailProvider._(argument: item, from: this);

  @override
  String toString() => r'externalThumbnailProvider';
}
