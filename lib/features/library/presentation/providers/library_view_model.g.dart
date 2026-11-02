// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LibraryViewModel)
final libraryViewModelProvider = LibraryViewModelProvider._();

final class LibraryViewModelProvider
    extends $AsyncNotifierProvider<LibraryViewModel, List<MediaItem>> {
  LibraryViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryViewModelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryViewModelHash();

  @$internal
  @override
  LibraryViewModel create() => LibraryViewModel();
}

String _$libraryViewModelHash() => r'51bfb5f8ab636d3752958c3375773bab741d6007';

abstract class _$LibraryViewModel extends $AsyncNotifier<List<MediaItem>> {
  FutureOr<List<MediaItem>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<MediaItem>>, List<MediaItem>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<MediaItem>>, List<MediaItem>>,
              AsyncValue<List<MediaItem>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(ExternalLibraryViewModel)
final externalLibraryViewModelProvider = ExternalLibraryViewModelProvider._();

final class ExternalLibraryViewModelProvider
    extends $AsyncNotifierProvider<ExternalLibraryViewModel, List<MediaItem>> {
  ExternalLibraryViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'externalLibraryViewModelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$externalLibraryViewModelHash();

  @$internal
  @override
  ExternalLibraryViewModel create() => ExternalLibraryViewModel();
}

String _$externalLibraryViewModelHash() =>
    r'dec482f42dcce96d97db050c73ec8f6b5ff4844b';

abstract class _$ExternalLibraryViewModel
    extends $AsyncNotifier<List<MediaItem>> {
  FutureOr<List<MediaItem>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<MediaItem>>, List<MediaItem>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<MediaItem>>, List<MediaItem>>,
              AsyncValue<List<MediaItem>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
