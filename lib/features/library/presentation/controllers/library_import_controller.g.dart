// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_import_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LibraryImportController)
final libraryImportControllerProvider = LibraryImportControllerProvider._();

final class LibraryImportControllerProvider
    extends $NotifierProvider<LibraryImportController, void> {
  LibraryImportControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryImportControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryImportControllerHash();

  @$internal
  @override
  LibraryImportController create() => LibraryImportController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$libraryImportControllerHash() =>
    r'3b485c0063fdad2ae51d93ec46d470103a36d98e';

abstract class _$LibraryImportController extends $Notifier<void> {
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
