// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_path_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LibraryPath)
final libraryPathProvider = LibraryPathProvider._();

final class LibraryPathProvider
    extends $AsyncNotifierProvider<LibraryPath, String?> {
  LibraryPathProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryPathProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryPathHash();

  @$internal
  @override
  LibraryPath create() => LibraryPath();
}

String _$libraryPathHash() => r'd63f430b4774397ed58a335f288ffc115f15a68c';

abstract class _$LibraryPath extends $AsyncNotifier<String?> {
  FutureOr<String?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<String?>, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<String?>, String?>,
              AsyncValue<String?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
