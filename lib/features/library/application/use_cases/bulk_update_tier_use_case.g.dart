// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bulk_update_tier_use_case.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(bulkUpdateTierUseCase)
final bulkUpdateTierUseCaseProvider = BulkUpdateTierUseCaseProvider._();

final class BulkUpdateTierUseCaseProvider
    extends
        $FunctionalProvider<
          BulkUpdateTierUseCase,
          BulkUpdateTierUseCase,
          BulkUpdateTierUseCase
        >
    with $Provider<BulkUpdateTierUseCase> {
  BulkUpdateTierUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bulkUpdateTierUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bulkUpdateTierUseCaseHash();

  @$internal
  @override
  $ProviderElement<BulkUpdateTierUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BulkUpdateTierUseCase create(Ref ref) {
    return bulkUpdateTierUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BulkUpdateTierUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BulkUpdateTierUseCase>(value),
    );
  }
}

String _$bulkUpdateTierUseCaseHash() =>
    r'2993a8f7b9dce7b084424c5053390463f8bfaf31';
