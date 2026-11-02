// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'collection_header_state_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CollectionHeaderExpanded)
final collectionHeaderExpandedProvider = CollectionHeaderExpandedFamily._();

final class CollectionHeaderExpandedProvider
    extends $AsyncNotifierProvider<CollectionHeaderExpanded, bool> {
  CollectionHeaderExpandedProvider._({
    required CollectionHeaderExpandedFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'collectionHeaderExpandedProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$collectionHeaderExpandedHash();

  @override
  String toString() {
    return r'collectionHeaderExpandedProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  CollectionHeaderExpanded create() => CollectionHeaderExpanded();

  @override
  bool operator ==(Object other) {
    return other is CollectionHeaderExpandedProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$collectionHeaderExpandedHash() =>
    r'7c12d3d55e3a396e1523b99f549671f3351a262b';

final class CollectionHeaderExpandedFamily extends $Family
    with
        $ClassFamilyOverride<
          CollectionHeaderExpanded,
          AsyncValue<bool>,
          bool,
          FutureOr<bool>,
          int
        > {
  CollectionHeaderExpandedFamily._()
    : super(
        retry: null,
        name: r'collectionHeaderExpandedProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CollectionHeaderExpandedProvider call(int collectionId) =>
      CollectionHeaderExpandedProvider._(argument: collectionId, from: this);

  @override
  String toString() => r'collectionHeaderExpandedProvider';
}

abstract class _$CollectionHeaderExpanded extends $AsyncNotifier<bool> {
  late final _$args = ref.$arg as int;
  int get collectionId => _$args;

  FutureOr<bool> build(int collectionId);
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
    return element.handleCreate(ref, () => build(_$args));
  }
}
