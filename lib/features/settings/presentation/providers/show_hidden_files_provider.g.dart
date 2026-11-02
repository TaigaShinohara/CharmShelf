// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'show_hidden_files_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ShowHiddenFilesAsync)
final showHiddenFilesAsyncProvider = ShowHiddenFilesAsyncProvider._();

final class ShowHiddenFilesAsyncProvider
    extends $AsyncNotifierProvider<ShowHiddenFilesAsync, bool> {
  ShowHiddenFilesAsyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'showHiddenFilesAsyncProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$showHiddenFilesAsyncHash();

  @$internal
  @override
  ShowHiddenFilesAsync create() => ShowHiddenFilesAsync();
}

String _$showHiddenFilesAsyncHash() =>
    r'bb75905728335c758ee853cc0230408957a073e7';

abstract class _$ShowHiddenFilesAsync extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(showHiddenFiles)
final showHiddenFilesProvider = ShowHiddenFilesProvider._();

final class ShowHiddenFilesProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  ShowHiddenFilesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'showHiddenFilesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$showHiddenFilesHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return showHiddenFiles(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$showHiddenFilesHash() => r'7a3e0d8d683c8513759b1a8c96021373b8da3289';
