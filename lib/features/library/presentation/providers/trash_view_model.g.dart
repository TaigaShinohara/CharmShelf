// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trash_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TrashViewModel)
final trashViewModelProvider = TrashViewModelProvider._();

final class TrashViewModelProvider
    extends $NotifierProvider<TrashViewModel, TrashState> {
  TrashViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trashViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trashViewModelHash();

  @$internal
  @override
  TrashViewModel create() => TrashViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TrashState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TrashState>(value),
    );
  }
}

String _$trashViewModelHash() => r'ec6e4921e16bfc459188de6027c47fb98493ea1b';

abstract class _$TrashViewModel extends $Notifier<TrashState> {
  TrashState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<TrashState, TrashState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TrashState, TrashState>,
              TrashState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
