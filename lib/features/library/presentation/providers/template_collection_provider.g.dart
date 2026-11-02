// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'template_collection_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(templateCollectionService)
final templateCollectionServiceProvider = TemplateCollectionServiceProvider._();

final class TemplateCollectionServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<TemplateCollectionService>,
          TemplateCollectionService,
          FutureOr<TemplateCollectionService>
        >
    with
        $FutureModifier<TemplateCollectionService>,
        $FutureProvider<TemplateCollectionService> {
  TemplateCollectionServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'templateCollectionServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$templateCollectionServiceHash();

  @$internal
  @override
  $FutureProviderElement<TemplateCollectionService> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TemplateCollectionService> create(Ref ref) {
    return templateCollectionService(ref);
  }
}

String _$templateCollectionServiceHash() =>
    r'3d830ace49805ca9a88db45664e26a92fb380573';
