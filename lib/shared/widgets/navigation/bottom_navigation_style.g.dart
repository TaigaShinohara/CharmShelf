// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bottom_navigation_style.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// ボトムナビゲーションスタイルの選択状態。
///
/// 現状は「アプリ全体で1つ」の想定（タブごとに変えるとUXが崩れやすいため）。

@ProviderFor(BottomNavigationStyleNotifier)
final bottomNavigationStyleNotifierProvider =
    BottomNavigationStyleNotifierProvider._();

/// ボトムナビゲーションスタイルの選択状態。
///
/// 現状は「アプリ全体で1つ」の想定（タブごとに変えるとUXが崩れやすいため）。
final class BottomNavigationStyleNotifierProvider
    extends
        $NotifierProvider<
          BottomNavigationStyleNotifier,
          BottomNavigationStyle
        > {
  /// ボトムナビゲーションスタイルの選択状態。
  ///
  /// 現状は「アプリ全体で1つ」の想定（タブごとに変えるとUXが崩れやすいため）。
  BottomNavigationStyleNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bottomNavigationStyleNotifierProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bottomNavigationStyleNotifierHash();

  @$internal
  @override
  BottomNavigationStyleNotifier create() => BottomNavigationStyleNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BottomNavigationStyle value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BottomNavigationStyle>(value),
    );
  }
}

String _$bottomNavigationStyleNotifierHash() =>
    r'18d543de6149691e923b8f7d9b9fa206b6c62fa8';

/// ボトムナビゲーションスタイルの選択状態。
///
/// 現状は「アプリ全体で1つ」の想定（タブごとに変えるとUXが崩れやすいため）。

abstract class _$BottomNavigationStyleNotifier
    extends $Notifier<BottomNavigationStyle> {
  BottomNavigationStyle build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<BottomNavigationStyle, BottomNavigationStyle>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<BottomNavigationStyle, BottomNavigationStyle>,
              BottomNavigationStyle,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
