// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'operation_journal_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(operationJournalService)
final operationJournalServiceProvider = OperationJournalServiceProvider._();

final class OperationJournalServiceProvider
    extends
        $FunctionalProvider<
          OperationJournalService,
          OperationJournalService,
          OperationJournalService
        >
    with $Provider<OperationJournalService> {
  OperationJournalServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'operationJournalServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$operationJournalServiceHash();

  @$internal
  @override
  $ProviderElement<OperationJournalService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  OperationJournalService create(Ref ref) {
    return operationJournalService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OperationJournalService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OperationJournalService>(value),
    );
  }
}

String _$operationJournalServiceHash() =>
    r'8ffff2125af066b569b71eac76b4c63a774937d0';
