// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_thumbnail_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// サムネイル未生成のローカル画像に対してオンデマンドで軽量サムネイルを生成・提供するプロバイダー

@ProviderFor(localThumbnail)
final localThumbnailProvider = LocalThumbnailFamily._();

/// サムネイル未生成のローカル画像に対してオンデマンドで軽量サムネイルを生成・提供するプロバイダー

final class LocalThumbnailProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  /// サムネイル未生成のローカル画像に対してオンデマンドで軽量サムネイルを生成・提供するプロバイダー
  LocalThumbnailProvider._({
    required LocalThumbnailFamily super.from,
    required MediaItem super.argument,
  }) : super(
         retry: null,
         name: r'localThumbnailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$localThumbnailHash();

  @override
  String toString() {
    return r'localThumbnailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    final argument = this.argument as MediaItem;
    return localThumbnail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is LocalThumbnailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$localThumbnailHash() => r'2ddeda8495399cbf1dedac2401e52f9144f20fcd';

/// サムネイル未生成のローカル画像に対してオンデマンドで軽量サムネイルを生成・提供するプロバイダー

final class LocalThumbnailFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String?>, MediaItem> {
  LocalThumbnailFamily._()
    : super(
        retry: null,
        name: r'localThumbnailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// サムネイル未生成のローカル画像に対してオンデマンドで軽量サムネイルを生成・提供するプロバイダー

  LocalThumbnailProvider call(MediaItem item) =>
      LocalThumbnailProvider._(argument: item, from: this);

  @override
  String toString() => r'localThumbnailProvider';
}
