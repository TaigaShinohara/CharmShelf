// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag_repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(tagRepository)
final tagRepositoryProvider = TagRepositoryProvider._();

final class TagRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<TagRepository>,
          TagRepository,
          FutureOr<TagRepository>
        >
    with $FutureModifier<TagRepository>, $FutureProvider<TagRepository> {
  TagRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tagRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tagRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<TagRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TagRepository> create(Ref ref) {
    return tagRepository(ref);
  }
}

String _$tagRepositoryHash() => r'958ddffaffe8052f7db03d62482ebe88d868f7d8';
