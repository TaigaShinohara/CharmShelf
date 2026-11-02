// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tab_navigation_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 現在選択されているタブのインデックスを管理するプロバイダー

@ProviderFor(CurrentTabIndex)
final currentTabIndexProvider = CurrentTabIndexProvider._();

/// 現在選択されているタブのインデックスを管理するプロバイダー
final class CurrentTabIndexProvider
    extends $NotifierProvider<CurrentTabIndex, int> {
  /// 現在選択されているタブのインデックスを管理するプロバイダー
  CurrentTabIndexProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentTabIndexProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentTabIndexHash();

  @$internal
  @override
  CurrentTabIndex create() => CurrentTabIndex();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$currentTabIndexHash() => r'6677b6e5a8cf6506dad7cd3e130f9eebd0226ad6';

/// 現在選択されているタブのインデックスを管理するプロバイダー

abstract class _$CurrentTabIndex extends $Notifier<int> {
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
