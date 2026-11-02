// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TagListViewModel)
final tagListViewModelProvider = TagListViewModelProvider._();

final class TagListViewModelProvider
    extends $StreamNotifierProvider<TagListViewModel, List<Tag>> {
  TagListViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tagListViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tagListViewModelHash();

  @$internal
  @override
  TagListViewModel create() => TagListViewModel();
}

String _$tagListViewModelHash() => r'ee81fe6a669551cb7794082b5b7a1a0c03caca24';

abstract class _$TagListViewModel extends $StreamNotifier<List<Tag>> {
  Stream<List<Tag>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Tag>>, List<Tag>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Tag>>, List<Tag>>,
              AsyncValue<List<Tag>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(visibleTagList)
final visibleTagListProvider = VisibleTagListProvider._();

final class VisibleTagListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Tag>>,
          AsyncValue<List<Tag>>,
          AsyncValue<List<Tag>>
        >
    with $Provider<AsyncValue<List<Tag>>> {
  VisibleTagListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'visibleTagListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$visibleTagListHash();

  @$internal
  @override
  $ProviderElement<AsyncValue<List<Tag>>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AsyncValue<List<Tag>> create(Ref ref) {
    return visibleTagList(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<List<Tag>> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<List<Tag>>>(value),
    );
  }
}

String _$visibleTagListHash() => r'5f6fcd66120ce497955535364cb279836cea9c7a';
