// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'locale_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AppLocaleAsync)
final appLocaleAsyncProvider = AppLocaleAsyncProvider._();

final class AppLocaleAsyncProvider
    extends $AsyncNotifierProvider<AppLocaleAsync, Locale?> {
  AppLocaleAsyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appLocaleAsyncProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appLocaleAsyncHash();

  @$internal
  @override
  AppLocaleAsync create() => AppLocaleAsync();
}

String _$appLocaleAsyncHash() => r'c5a87260a4c75ab79c0037eac41d5846d3028b5a';

abstract class _$AppLocaleAsync extends $AsyncNotifier<Locale?> {
  FutureOr<Locale?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Locale?>, Locale?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Locale?>, Locale?>,
              AsyncValue<Locale?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(appLocale)
final appLocaleProvider = AppLocaleProvider._();

final class AppLocaleProvider
    extends $FunctionalProvider<Locale?, Locale?, Locale?>
    with $Provider<Locale?> {
  AppLocaleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appLocaleProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appLocaleHash();

  @$internal
  @override
  $ProviderElement<Locale?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Locale? create(Ref ref) {
    return appLocale(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Locale? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Locale?>(value),
    );
  }
}

String _$appLocaleHash() => r'6da9d98d425f2a159e0c4dec5c47a5f69d2194fb';
