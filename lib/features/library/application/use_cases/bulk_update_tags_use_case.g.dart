// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bulk_update_tags_use_case.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(bulkUpdateTagsUseCase)
final bulkUpdateTagsUseCaseProvider = BulkUpdateTagsUseCaseProvider._();

final class BulkUpdateTagsUseCaseProvider
    extends
        $FunctionalProvider<
          BulkUpdateTagsUseCase,
          BulkUpdateTagsUseCase,
          BulkUpdateTagsUseCase
        >
    with $Provider<BulkUpdateTagsUseCase> {
  BulkUpdateTagsUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bulkUpdateTagsUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bulkUpdateTagsUseCaseHash();

  @$internal
  @override
  $ProviderElement<BulkUpdateTagsUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BulkUpdateTagsUseCase create(Ref ref) {
    return bulkUpdateTagsUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BulkUpdateTagsUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BulkUpdateTagsUseCase>(value),
    );
  }
}

String _$bulkUpdateTagsUseCaseHash() =>
    r'a5da9b2f39779ff18dd05b6aa05066b8ca9028c5';
