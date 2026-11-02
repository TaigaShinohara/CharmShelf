// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_view_settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// ビューワーのページ送り方向を永続化する。

@ProviderFor(ViewerPageDirectionAsync)
final viewerPageDirectionAsyncProvider = ViewerPageDirectionAsyncProvider._();

/// ビューワーのページ送り方向を永続化する。
final class ViewerPageDirectionAsyncProvider
    extends
        $AsyncNotifierProvider<ViewerPageDirectionAsync, ViewerPageDirection> {
  /// ビューワーのページ送り方向を永続化する。
  ViewerPageDirectionAsyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'viewerPageDirectionAsyncProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$viewerPageDirectionAsyncHash();

  @$internal
  @override
  ViewerPageDirectionAsync create() => ViewerPageDirectionAsync();
}

String _$viewerPageDirectionAsyncHash() =>
    r'd40785c082df173df477158ad7d3fe122bced6f4';

/// ビューワーのページ送り方向を永続化する。

abstract class _$ViewerPageDirectionAsync
    extends $AsyncNotifier<ViewerPageDirection> {
  FutureOr<ViewerPageDirection> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<ViewerPageDirection>, ViewerPageDirection>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ViewerPageDirection>, ViewerPageDirection>,
              AsyncValue<ViewerPageDirection>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(viewerPageDirection)
final viewerPageDirectionProvider = ViewerPageDirectionProvider._();

final class ViewerPageDirectionProvider
    extends
        $FunctionalProvider<
          ViewerPageDirection,
          ViewerPageDirection,
          ViewerPageDirection
        >
    with $Provider<ViewerPageDirection> {
  ViewerPageDirectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'viewerPageDirectionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$viewerPageDirectionHash();

  @$internal
  @override
  $ProviderElement<ViewerPageDirection> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ViewerPageDirection create(Ref ref) {
    return viewerPageDirection(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ViewerPageDirection value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ViewerPageDirection>(value),
    );
  }
}

String _$viewerPageDirectionHash() =>
    r'f06e6dde79a4eb7b5fe405ff6559909e83ee8650';

/// ライブラリ全体のデフォルト表示モード（グリッド/リスト）を永続化する

@ProviderFor(GlobalViewModeAsync)
final globalViewModeAsyncProvider = GlobalViewModeAsyncProvider._();

/// ライブラリ全体のデフォルト表示モード（グリッド/リスト）を永続化する
final class GlobalViewModeAsyncProvider
    extends $AsyncNotifierProvider<GlobalViewModeAsync, ViewMode> {
  /// ライブラリ全体のデフォルト表示モード（グリッド/リスト）を永続化する
  GlobalViewModeAsyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'globalViewModeAsyncProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$globalViewModeAsyncHash();

  @$internal
  @override
  GlobalViewModeAsync create() => GlobalViewModeAsync();
}

String _$globalViewModeAsyncHash() =>
    r'3b617f1eb9fed28b47deb60e17ef124d6b6eb13a';

/// ライブラリ全体のデフォルト表示モード（グリッド/リスト）を永続化する

abstract class _$GlobalViewModeAsync extends $AsyncNotifier<ViewMode> {
  FutureOr<ViewMode> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ViewMode>, ViewMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ViewMode>, ViewMode>,
              AsyncValue<ViewMode>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// ライブラリ全体の簡易表示モードを永続化する

@ProviderFor(GlobalSimpleDisplayAsync)
final globalSimpleDisplayAsyncProvider = GlobalSimpleDisplayAsyncProvider._();

/// ライブラリ全体の簡易表示モードを永続化する
final class GlobalSimpleDisplayAsyncProvider
    extends $AsyncNotifierProvider<GlobalSimpleDisplayAsync, bool> {
  /// ライブラリ全体の簡易表示モードを永続化する
  GlobalSimpleDisplayAsyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'globalSimpleDisplayAsyncProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$globalSimpleDisplayAsyncHash();

  @$internal
  @override
  GlobalSimpleDisplayAsync create() => GlobalSimpleDisplayAsync();
}

String _$globalSimpleDisplayAsyncHash() =>
    r'dd957b61838da3de8c9fa3aeeb8fecd1bddbf17c';

/// ライブラリ全体の簡易表示モードを永続化する

abstract class _$GlobalSimpleDisplayAsync extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 同期的にアクセスするためのヘルパー

@ProviderFor(globalViewMode)
final globalViewModeProvider = GlobalViewModeProvider._();

/// 同期的にアクセスするためのヘルパー

final class GlobalViewModeProvider
    extends $FunctionalProvider<ViewMode, ViewMode, ViewMode>
    with $Provider<ViewMode> {
  /// 同期的にアクセスするためのヘルパー
  GlobalViewModeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'globalViewModeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$globalViewModeHash();

  @$internal
  @override
  $ProviderElement<ViewMode> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ViewMode create(Ref ref) {
    return globalViewMode(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ViewMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ViewMode>(value),
    );
  }
}

String _$globalViewModeHash() => r'4adb077e9487330201ffc0cb84d1e53311e1abd4';

@ProviderFor(globalSimpleDisplay)
final globalSimpleDisplayProvider = GlobalSimpleDisplayProvider._();

final class GlobalSimpleDisplayProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  GlobalSimpleDisplayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'globalSimpleDisplayProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$globalSimpleDisplayHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return globalSimpleDisplay(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$globalSimpleDisplayHash() =>
    r'd9b38c9dd28784645263de6cf2eaf30089ab5f00';
