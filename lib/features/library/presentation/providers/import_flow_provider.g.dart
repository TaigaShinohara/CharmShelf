// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'import_flow_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ImportFlowNotifier)
final importFlowNotifierProvider = ImportFlowNotifierProvider._();

final class ImportFlowNotifierProvider
    extends $NotifierProvider<ImportFlowNotifier, ImportFlowState> {
  ImportFlowNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'importFlowNotifierProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$importFlowNotifierHash();

  @$internal
  @override
  ImportFlowNotifier create() => ImportFlowNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ImportFlowState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ImportFlowState>(value),
    );
  }
}

String _$importFlowNotifierHash() =>
    r'36ddd1130e1a1445bcabdc6b36612b8b5a5d8c26';

abstract class _$ImportFlowNotifier extends $Notifier<ImportFlowState> {
  ImportFlowState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ImportFlowState, ImportFlowState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ImportFlowState, ImportFlowState>,
              ImportFlowState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
