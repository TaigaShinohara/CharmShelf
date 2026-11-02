// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_selection_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LibrarySelectionNotifier)
final librarySelectionNotifierProvider = LibrarySelectionNotifierProvider._();

final class LibrarySelectionNotifierProvider
    extends $NotifierProvider<LibrarySelectionNotifier, LibrarySelectionState> {
  LibrarySelectionNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'librarySelectionNotifierProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$librarySelectionNotifierHash();

  @$internal
  @override
  LibrarySelectionNotifier create() => LibrarySelectionNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LibrarySelectionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LibrarySelectionState>(value),
    );
  }
}

String _$librarySelectionNotifierHash() =>
    r'c40d1b8df08ad0e3ca1cc4691afe974789e3aba6';

abstract class _$LibrarySelectionNotifier
    extends $Notifier<LibrarySelectionState> {
  LibrarySelectionState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<LibrarySelectionState, LibrarySelectionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LibrarySelectionState, LibrarySelectionState>,
              LibrarySelectionState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
