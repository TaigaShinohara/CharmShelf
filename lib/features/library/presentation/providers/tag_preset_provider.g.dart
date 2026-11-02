// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag_preset_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(tagPresetService)
final tagPresetServiceProvider = TagPresetServiceProvider._();

final class TagPresetServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<TagPresetService>,
          TagPresetService,
          FutureOr<TagPresetService>
        >
    with $FutureModifier<TagPresetService>, $FutureProvider<TagPresetService> {
  TagPresetServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tagPresetServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tagPresetServiceHash();

  @$internal
  @override
  $FutureProviderElement<TagPresetService> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TagPresetService> create(Ref ref) {
    return tagPresetService(ref);
  }
}

String _$tagPresetServiceHash() => r'957e3fed9ac28962dfa8d260587c3a981c9b64c7';
