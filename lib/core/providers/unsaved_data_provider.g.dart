// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unsaved_data_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 未保存データを持つ画面のキーを管理するプロバイダー
///
/// 各画面で編集中のデータがある場合、screenKeyを登録することで
/// タブ切り替え時やルート復帰時に確認ダイアログを表示できます。

@ProviderFor(UnsavedDataKeys)
final unsavedDataKeysProvider = UnsavedDataKeysProvider._();

/// 未保存データを持つ画面のキーを管理するプロバイダー
///
/// 各画面で編集中のデータがある場合、screenKeyを登録することで
/// タブ切り替え時やルート復帰時に確認ダイアログを表示できます。
final class UnsavedDataKeysProvider
    extends $NotifierProvider<UnsavedDataKeys, Set<String>> {
  /// 未保存データを持つ画面のキーを管理するプロバイダー
  ///
  /// 各画面で編集中のデータがある場合、screenKeyを登録することで
  /// タブ切り替え時やルート復帰時に確認ダイアログを表示できます。
  UnsavedDataKeysProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'unsavedDataKeysProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$unsavedDataKeysHash();

  @$internal
  @override
  UnsavedDataKeys create() => UnsavedDataKeys();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }
}

String _$unsavedDataKeysHash() => r'cf56b730a7f270a4bc885a4196dfce6423f56023';

/// 未保存データを持つ画面のキーを管理するプロバイダー
///
/// 各画面で編集中のデータがある場合、screenKeyを登録することで
/// タブ切り替え時やルート復帰時に確認ダイアログを表示できます。

abstract class _$UnsavedDataKeys extends $Notifier<Set<String>> {
  Set<String> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Set<String>, Set<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Set<String>, Set<String>>,
              Set<String>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
