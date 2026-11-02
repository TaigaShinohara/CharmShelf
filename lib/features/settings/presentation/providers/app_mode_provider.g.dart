// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_mode_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AppModeAsync)
final appModeAsyncProvider = AppModeAsyncProvider._();

final class AppModeAsyncProvider
    extends $AsyncNotifierProvider<AppModeAsync, AppMode> {
  AppModeAsyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appModeAsyncProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appModeAsyncHash();

  @$internal
  @override
  AppModeAsync create() => AppModeAsync();
}

String _$appModeAsyncHash() => r'0362626299338310d65dc26166c4490fd2132f25';

abstract class _$AppModeAsync extends $AsyncNotifier<AppMode> {
  FutureOr<AppMode> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<AppMode>, AppMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AppMode>, AppMode>,
              AsyncValue<AppMode>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(appMode)
final appModeProvider = AppModeProvider._();

final class AppModeProvider
    extends $FunctionalProvider<AppMode, AppMode, AppMode>
    with $Provider<AppMode> {
  AppModeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appModeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appModeHash();

  @$internal
  @override
  $ProviderElement<AppMode> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppMode create(Ref ref) {
    return appMode(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppMode>(value),
    );
  }
}

String _$appModeHash() => r'8c9376dcc322ef0120875643cf3aef2278f4f29e';

@ProviderFor(isExternalMode)
final isExternalModeProvider = IsExternalModeProvider._();

final class IsExternalModeProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  IsExternalModeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isExternalModeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isExternalModeHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return isExternalMode(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isExternalModeHash() => r'd785bd5bbe0ef43ccd1e9e817b43b3091ceb2d72';
