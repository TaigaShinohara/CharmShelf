// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_synchronizer.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LibrarySynchronizer)
final librarySynchronizerProvider = LibrarySynchronizerProvider._();

final class LibrarySynchronizerProvider
    extends $NotifierProvider<LibrarySynchronizer, void> {
  LibrarySynchronizerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'librarySynchronizerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$librarySynchronizerHash();

  @$internal
  @override
  LibrarySynchronizer create() => LibrarySynchronizer();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$librarySynchronizerHash() =>
    r'df427bacf550dd52d08d1ce50d05064b9bb7a1c6';

abstract class _$LibrarySynchronizer extends $Notifier<void> {
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
