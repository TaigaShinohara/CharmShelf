// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'collection_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CollectionNotifier)
final collectionNotifierProvider = CollectionNotifierFamily._();

final class CollectionNotifierProvider
    extends $AsyncNotifierProvider<CollectionNotifier, MediaCollection?> {
  CollectionNotifierProvider._({
    required CollectionNotifierFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'collectionNotifierProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$collectionNotifierHash();

  @override
  String toString() {
    return r'collectionNotifierProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  CollectionNotifier create() => CollectionNotifier();

  @override
  bool operator ==(Object other) {
    return other is CollectionNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$collectionNotifierHash() =>
    r'ae586aa625ffb909a9cf7afa2ccfc23ed0339cde';

final class CollectionNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          CollectionNotifier,
          AsyncValue<MediaCollection?>,
          MediaCollection?,
          FutureOr<MediaCollection?>,
          String
        > {
  CollectionNotifierFamily._()
    : super(
        retry: null,
        name: r'collectionNotifierProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CollectionNotifierProvider call(String path) =>
      CollectionNotifierProvider._(argument: path, from: this);

  @override
  String toString() => r'collectionNotifierProvider';
}

abstract class _$CollectionNotifier extends $AsyncNotifier<MediaCollection?> {
  late final _$args = ref.$arg as String;
  String get path => _$args;

  FutureOr<MediaCollection?> build(String path);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<MediaCollection?>, MediaCollection?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<MediaCollection?>, MediaCollection?>,
              AsyncValue<MediaCollection?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

/// 指定した親パスを辿り、所属するカタログ（MediaCollection）を取得するプロバイダー

@ProviderFor(parentCatalog)
final parentCatalogProvider = ParentCatalogFamily._();

/// 指定した親パスを辿り、所属するカタログ（MediaCollection）を取得するプロバイダー

final class ParentCatalogProvider
    extends
        $FunctionalProvider<
          AsyncValue<MediaCollection?>,
          MediaCollection?,
          FutureOr<MediaCollection?>
        >
    with $FutureModifier<MediaCollection?>, $FutureProvider<MediaCollection?> {
  /// 指定した親パスを辿り、所属するカタログ（MediaCollection）を取得するプロバイダー
  ParentCatalogProvider._({
    required ParentCatalogFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'parentCatalogProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$parentCatalogHash();

  @override
  String toString() {
    return r'parentCatalogProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<MediaCollection?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MediaCollection?> create(Ref ref) {
    final argument = this.argument as String?;
    return parentCatalog(ref, parentPath: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ParentCatalogProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$parentCatalogHash() => r'3ad3eb138c1babab8927f1464eb890022bac8611';

/// 指定した親パスを辿り、所属するカタログ（MediaCollection）を取得するプロバイダー

final class ParentCatalogFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<MediaCollection?>, String?> {
  ParentCatalogFamily._()
    : super(
        retry: null,
        name: r'parentCatalogProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 指定した親パスを辿り、所属するカタログ（MediaCollection）を取得するプロバイダー

  ParentCatalogProvider call({required String? parentPath}) =>
      ParentCatalogProvider._(argument: parentPath, from: this);

  @override
  String toString() => r'parentCatalogProvider';
}
