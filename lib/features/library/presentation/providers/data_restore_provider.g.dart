// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_restore_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DataRestoreNotifier)
final dataRestoreNotifierProvider = DataRestoreNotifierProvider._();

final class DataRestoreNotifierProvider
    extends $NotifierProvider<DataRestoreNotifier, DataRestoreState> {
  DataRestoreNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dataRestoreNotifierProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dataRestoreNotifierHash();

  @$internal
  @override
  DataRestoreNotifier create() => DataRestoreNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DataRestoreState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DataRestoreState>(value),
    );
  }
}

String _$dataRestoreNotifierHash() =>
    r'c763fbea2b32b0c85ae6e34bef33a205b240f03f';

abstract class _$DataRestoreNotifier extends $Notifier<DataRestoreState> {
  DataRestoreState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DataRestoreState, DataRestoreState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DataRestoreState, DataRestoreState>,
              DataRestoreState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
