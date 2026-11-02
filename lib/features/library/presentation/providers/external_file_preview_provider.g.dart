// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'external_file_preview_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 外部参照ファイルの一時パスを取得・保持するプロバイダー。
///
/// 画面の再ビルドによって `copyToTemp` が何度も呼ばれるのを防ぎ、
/// Android/iOS での安定した画像表示を実現します。

@ProviderFor(externalFilePreview)
final externalFilePreviewProvider = ExternalFilePreviewFamily._();

/// 外部参照ファイルの一時パスを取得・保持するプロバイダー。
///
/// 画面の再ビルドによって `copyToTemp` が何度も呼ばれるのを防ぎ、
/// Android/iOS での安定した画像表示を実現します。

final class ExternalFilePreviewProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  /// 外部参照ファイルの一時パスを取得・保持するプロバイダー。
  ///
  /// 画面の再ビルドによって `copyToTemp` が何度も呼ばれるのを防ぎ、
  /// Android/iOS での安定した画像表示を実現します。
  ExternalFilePreviewProvider._({
    required ExternalFilePreviewFamily super.from,
    required MediaItem super.argument,
  }) : super(
         retry: null,
         name: r'externalFilePreviewProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$externalFilePreviewHash();

  @override
  String toString() {
    return r'externalFilePreviewProvider'
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
    return externalFilePreview(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ExternalFilePreviewProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$externalFilePreviewHash() =>
    r'b35e61004e2d414745f77fda115e6f9ec7c3dfc2';

/// 外部参照ファイルの一時パスを取得・保持するプロバイダー。
///
/// 画面の再ビルドによって `copyToTemp` が何度も呼ばれるのを防ぎ、
/// Android/iOS での安定した画像表示を実現します。

final class ExternalFilePreviewFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String?>, MediaItem> {
  ExternalFilePreviewFamily._()
    : super(
        retry: null,
        name: r'externalFilePreviewProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 外部参照ファイルの一時パスを取得・保持するプロバイダー。
  ///
  /// 画面の再ビルドによって `copyToTemp` が何度も呼ばれるのを防ぎ、
  /// Android/iOS での安定した画像表示を実現します。

  ExternalFilePreviewProvider call(MediaItem item) =>
      ExternalFilePreviewProvider._(argument: item, from: this);

  @override
  String toString() => r'externalFilePreviewProvider';
}
