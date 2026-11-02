// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tip_purchase_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(tipPurchaseService)
final tipPurchaseServiceProvider = TipPurchaseServiceProvider._();

final class TipPurchaseServiceProvider
    extends
        $FunctionalProvider<
          TipPurchaseService,
          TipPurchaseService,
          TipPurchaseService
        >
    with $Provider<TipPurchaseService> {
  TipPurchaseServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tipPurchaseServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tipPurchaseServiceHash();

  @$internal
  @override
  $ProviderElement<TipPurchaseService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TipPurchaseService create(Ref ref) {
    return tipPurchaseService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TipPurchaseService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TipPurchaseService>(value),
    );
  }
}

String _$tipPurchaseServiceHash() =>
    r'b94f8e141e9f989cc66eba9608703c9e640cbfcf';

@ProviderFor(TipPurchase)
final tipPurchaseProvider = TipPurchaseProvider._();

final class TipPurchaseProvider
    extends $AsyncNotifierProvider<TipPurchase, TipPurchaseState> {
  TipPurchaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tipPurchaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tipPurchaseHash();

  @$internal
  @override
  TipPurchase create() => TipPurchase();
}

String _$tipPurchaseHash() => r'a6d549c6a7f0a97aa38d42beca8c6f325fdc2cb8';

abstract class _$TipPurchase extends $AsyncNotifier<TipPurchaseState> {
  FutureOr<TipPurchaseState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<TipPurchaseState>, TipPurchaseState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<TipPurchaseState>, TipPurchaseState>,
              AsyncValue<TipPurchaseState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
