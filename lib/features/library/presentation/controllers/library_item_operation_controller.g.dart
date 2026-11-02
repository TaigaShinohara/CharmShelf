// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_item_operation_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LibraryItemOperationController)
final libraryItemOperationControllerProvider =
    LibraryItemOperationControllerProvider._();

final class LibraryItemOperationControllerProvider
    extends $NotifierProvider<LibraryItemOperationController, void> {
  LibraryItemOperationControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryItemOperationControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryItemOperationControllerHash();

  @$internal
  @override
  LibraryItemOperationController create() => LibraryItemOperationController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$libraryItemOperationControllerHash() =>
    r'e0b04e1efc7bf0c51a6a97be87d9cb85bbc365ba';

abstract class _$LibraryItemOperationController extends $Notifier<void> {
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
