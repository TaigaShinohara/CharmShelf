// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'back_navigation_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// タブルート内の画面が戻る操作を処理した回数を管理します。
///
/// ネストされたNavigatorのルート画面は、フォルダ階層や選択モードなどを
/// 画面内状態として保持します。MainTabPageはこのリビジョンを比較することで、
/// 画面内状態が戻された場合はアプリを終了せず、何も処理されなかった場合だけ
/// アプリをバックグラウンドへ移動できます。

@ProviderFor(BackNavigationRevision)
final backNavigationRevisionProvider = BackNavigationRevisionProvider._();

/// タブルート内の画面が戻る操作を処理した回数を管理します。
///
/// ネストされたNavigatorのルート画面は、フォルダ階層や選択モードなどを
/// 画面内状態として保持します。MainTabPageはこのリビジョンを比較することで、
/// 画面内状態が戻された場合はアプリを終了せず、何も処理されなかった場合だけ
/// アプリをバックグラウンドへ移動できます。
final class BackNavigationRevisionProvider
    extends $NotifierProvider<BackNavigationRevision, int> {
  /// タブルート内の画面が戻る操作を処理した回数を管理します。
  ///
  /// ネストされたNavigatorのルート画面は、フォルダ階層や選択モードなどを
  /// 画面内状態として保持します。MainTabPageはこのリビジョンを比較することで、
  /// 画面内状態が戻された場合はアプリを終了せず、何も処理されなかった場合だけ
  /// アプリをバックグラウンドへ移動できます。
  BackNavigationRevisionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backNavigationRevisionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backNavigationRevisionHash();

  @$internal
  @override
  BackNavigationRevision create() => BackNavigationRevision();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$backNavigationRevisionHash() =>
    r'c3d166139738bd0a61b16572edc07a52d6dead67';

/// タブルート内の画面が戻る操作を処理した回数を管理します。
///
/// ネストされたNavigatorのルート画面は、フォルダ階層や選択モードなどを
/// 画面内状態として保持します。MainTabPageはこのリビジョンを比較することで、
/// 画面内状態が戻された場合はアプリを終了せず、何も処理されなかった場合だけ
/// アプリをバックグラウンドへ移動できます。

abstract class _$BackNavigationRevision extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
