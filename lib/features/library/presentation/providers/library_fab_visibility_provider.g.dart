// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_fab_visibility_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// ライブラリ画面のFAB（追加ボタン）の表示状態を管理するプロバイダー。
///
/// 下にスクロールすると非表示になり、上にスクロールするか、
/// 一定時間操作がないと自動的に再表示される。

@ProviderFor(LibraryFabVisibility)
final libraryFabVisibilityProvider = LibraryFabVisibilityProvider._();

/// ライブラリ画面のFAB（追加ボタン）の表示状態を管理するプロバイダー。
///
/// 下にスクロールすると非表示になり、上にスクロールするか、
/// 一定時間操作がないと自動的に再表示される。
final class LibraryFabVisibilityProvider
    extends $NotifierProvider<LibraryFabVisibility, bool> {
  /// ライブラリ画面のFAB（追加ボタン）の表示状態を管理するプロバイダー。
  ///
  /// 下にスクロールすると非表示になり、上にスクロールするか、
  /// 一定時間操作がないと自動的に再表示される。
  LibraryFabVisibilityProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryFabVisibilityProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryFabVisibilityHash();

  @$internal
  @override
  LibraryFabVisibility create() => LibraryFabVisibility();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$libraryFabVisibilityHash() =>
    r'50cb0d3384d0e2102253114c9ec24802e0e48bcd';

/// ライブラリ画面のFAB（追加ボタン）の表示状態を管理するプロバイダー。
///
/// 下にスクロールすると非表示になり、上にスクロールするか、
/// 一定時間操作がないと自動的に再表示される。

abstract class _$LibraryFabVisibility extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
