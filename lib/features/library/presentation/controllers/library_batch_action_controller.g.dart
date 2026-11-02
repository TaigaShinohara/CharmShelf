// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_batch_action_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LibraryBatchActionController)
final libraryBatchActionControllerProvider =
    LibraryBatchActionControllerProvider._();

final class LibraryBatchActionControllerProvider
    extends $NotifierProvider<LibraryBatchActionController, void> {
  LibraryBatchActionControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryBatchActionControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryBatchActionControllerHash();

  @$internal
  @override
  LibraryBatchActionController create() => LibraryBatchActionController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$libraryBatchActionControllerHash() =>
    r'8d62871d2d0ec2a75b656a4bd814fcabf33ffd79';

abstract class _$LibraryBatchActionController extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
